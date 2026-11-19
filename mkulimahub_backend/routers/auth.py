from fastapi import APIRouter, HTTPException, Depends, status, Request
from sqlalchemy.orm import Session
from fastapi.security import OAuth2PasswordRequestForm
from google.oauth2 import id_token
from google.auth.transport import requests as google_requests

import models
import security
from schemas.auth import (
    UserCreate, UserResponse, Token, GoogleAuthRequest,
    PhoneAuthRequest, PasswordResetRequest
)
from dependencies import get_db, get_current_user
from config import GOOGLE_CLIENT_ID

try:
    from slowapi import Limiter
    from slowapi.util import get_remote_address
    limiter = Limiter(key_func=get_remote_address)
except ImportError:
    limiter = None

router = APIRouter()


@router.post("/api/auth/google")
def google_login(request: Request, payload: GoogleAuthRequest, db: Session = Depends(get_db)):
    try:
        idinfo = id_token.verify_oauth2_token(payload.id_token, google_requests.Request(), GOOGLE_CLIENT_ID, clock_skew_in_seconds=30)
        verified_email = idinfo['email']
    except ValueError as e:
        raise HTTPException(status_code=401, detail=f"Token Error: {str(e)}")

    user = db.query(models.User).filter(models.User.email == verified_email).first()
    if user:
        if not user.phone_number:
            return {"status": "needs_phone"}
        access_token = security.create_access_token(data={"sub": str(user.id), "role": user.role})
        needs_profile = False
        if not user.county or not user.village:
            needs_profile = True
        return {"access_token": access_token, "token_type": "bearer", "status": "success", "needs_profile": needs_profile}
    else:
        return {"status": "needs_phone"}


@router.post("/api/auth/google-register")
def google_register(request: Request, payload: GoogleAuthRequest, db: Session = Depends(get_db)):
    if not payload.phone_number:
        raise HTTPException(status_code=400, detail="Phone number is required for registration.")

    try:
        idinfo = id_token.verify_oauth2_token(payload.id_token, google_requests.Request(), GOOGLE_CLIENT_ID, clock_skew_in_seconds=10)
        verified_email = idinfo['email']
        verified_name = idinfo.get('name', 'New User')
        verified_uid = idinfo['sub']
    except ValueError as e:
        raise HTTPException(status_code=401, detail=f"Token Error: {str(e)}")

    existing_phone = db.query(models.User).filter(models.User.phone_number == payload.phone_number).first()
    if existing_phone and existing_phone.email != verified_email:
        raise HTTPException(status_code=400, detail="Phone number already registered to another account.")

    user = db.query(models.User).filter(models.User.email == verified_email).first()

    if user:
        user.phone_number = payload.phone_number
    else:
        user = models.User(
            full_name=verified_name,
            email=verified_email,
            google_uid=verified_uid,
            phone_number=payload.phone_number,
            role=payload.role
        )
        db.add(user)

    db.commit()
    db.refresh(user)

    access_token = security.create_access_token(data={"sub": str(user.id), "role": user.role})
    return {"access_token": access_token, "token_type": "bearer", "status": "needs_profile"}


@router.post("/api/auth/register", response_model=UserResponse)
def register_user(user: UserCreate, db: Session = Depends(get_db)):
    existing_user = db.query(models.User).filter(models.User.phone_number == user.phone_number).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Phone number already registered")

    new_user = models.User(
        full_name=user.full_name,
        phone_number=user.phone_number,
        hashed_password=security.get_password_hash(user.password),
        role=user.role,
        latitude=user.latitude,
        longitude=user.longitude
    )

    try:
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
        return new_user
    except Exception as e:
        db.rollback()
        print(f"Database error during registration: {e}")
        raise HTTPException(status_code=500, detail="Failed to create account. Please try again.")


@router.post("/auth/login", response_model=Token)
def login_user(request: Request, form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    raw_phone = form_data.username.strip()
    phone_zero = raw_phone
    phone_plus = raw_phone

    if raw_phone.startswith("+254"):
        phone_zero = "0" + raw_phone[4:]
    elif raw_phone.startswith("0"):
        phone_plus = "+254" + raw_phone[1:]

    user = db.query(models.User).filter(
        (models.User.phone_number == phone_zero) | (models.User.phone_number == phone_plus)
    ).first()

    if not user or not security.verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

    access_token = security.create_access_token(data={"sub": str(user.id), "role": user.role})
    return {"access_token": access_token, "token_type": "bearer"}


@router.post("/auth/phone-login")
def phone_login(request: Request, payload: PhoneAuthRequest, db: Session = Depends(get_db)):
    search_phone = payload.phone_number
    if search_phone.startswith("+254"):
        search_phone = "0" + search_phone[4:]

    user = db.query(models.User).filter(models.User.phone_number == search_phone).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Account not found. Please register first.")

    access_token = security.create_access_token(data={"sub": str(user.id), "role": user.role})
    return {"access_token": access_token, "token_type": "bearer", "status": "success"}


@router.post("/auth/reset-password")
def reset_password(request: Request, payload: PasswordResetRequest, db: Session = Depends(get_db)):
    search_phone = payload.phone_number
    if search_phone.startswith("+254"):
        search_phone = "0" + search_phone[4:]

    user = db.query(models.User).filter(models.User.phone_number == search_phone).first()
    if not user:
        raise HTTPException(status_code=404, detail="Account not found.")

    user.hashed_password = security.get_password_hash(payload.new_password)
    db.commit()
    return {"message": "Password updated successfully", "status": "success"}
