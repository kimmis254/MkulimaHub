from fastapi import APIRouter, FastAPI, HTTPException, Depends, status, Request
from sqlalchemy.orm import Session
from geoalchemy2.elements import WKTElement
import models
import schemas
import security
import random  
from database import engine, SessionLocal
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta
from pydantic import BaseModel
import requests 
import os
from dotenv import load_dotenv
import numpy as np
from sklearn.cluster import DBSCAN
import csv
import pandas as pd
from prophet import Prophet
import google.generativeai as genai
import glob
from sqlalchemy import select, distinct, text, func
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from sqlalchemy.orm import joinedload
from apscheduler.schedulers.background import BackgroundScheduler
from contextlib import asynccontextmanager
from google.oauth2 import id_token
from google.auth.transport import requests as google_requests
import json
from mpesa import MpesaClient

models.Base.metadata.create_all(bind=engine)

bulk_columns_to_add = [
    "payment_method VARCHAR DEFAULT 'pay_now'",
    "payment_status VARCHAR DEFAULT 'pending'", 
    "checkout_request_id VARCHAR",
    "deadline_time TIMESTAMP" 
]
pledge_columns_to_add = [
    "checkout_request_id VARCHAR" 
]

for col_def in bulk_columns_to_add:
    try:
        with engine.begin() as conn:
            # We extract just the column name for the check
            col_name = col_def.split()[0]
            conn.execute(text(f"ALTER TABLE bulk_requests ADD COLUMN {col_def};"))
    except Exception: pass

for col_def in pledge_columns_to_add:
    try:
        with engine.begin() as conn:
            conn.execute(text(f"ALTER TABLE pledges ADD COLUMN {col_def};"))
    except Exception: pass

class CoordinatorPitch(BaseModel):
    pitch: str

class VotePayload(BaseModel):
    candidate_id: int

class SquadPitch(BaseModel):
    pitch: str

class SquadVoteRequest(BaseModel):
    candidate_id: int

def scheduled_clustering_job():
    print("🤖 [SCHEDULER] Running Automatic DBSCAN Clustering...")
    db: Session = SessionLocal() 
    try:
        run_clustering_algorithm(db, target_crop="All") 
        print("[SCHEDULER] Clustering Complete!")
    except Exception as e:
        print(f"[SCHEDULER ERROR]: {e}")
    finally:
        db.close()

def scheduled_ml_predictions():
    db: Session = SessionLocal()
    try:
        crops = db.query(models.MarketPrice.commodity).distinct().all()
        crop_list = [c[0] for c in crops if c[0]]
        
        for crop in crop_list:
            for market_type in ["Wholesale", "Retail"]:
                cache_key = f"{crop.lower()}_national_{market_type.lower()}"
                
                records = db.query(models.MarketPrice.date, models.MarketPrice.price_kes).filter(
                    models.MarketPrice.commodity.ilike(f"%{crop}%"),
                    models.MarketPrice.market_type.ilike(f"%{market_type}%")
                ).all()
                
                # Ensure we have enough data to form a real trend
                if len(records) < 14:
                    continue 
                
                df = pd.DataFrame([{"ds": r.date, "y": r.price_kes} for r in records])
                df['ds'] = pd.to_datetime(df['ds'])
                
                # Remove KAMIS typos
                q_low = df["y"].quantile(0.01)
                q_hi  = df["y"].quantile(0.99)
                df = df[(df["y"] <= q_hi) & (df["y"] >= q_low)]
                
                df = df.groupby('ds', as_index=False)['y'].mean().sort_values(by='ds')
                
                if len(df) < 14:
                    continue
                    
                print(f"Training model for {cache_key}...")
                
                df['floor'] = max(0.0, df['y'].min() * 0.2) 
                df['cap'] = df['y'].max() * 2.0 
            
                # Initialize Prophet with logistic growth
                m = Prophet(
                    growth='logistic', 
                    daily_seasonality=False, 
                    weekly_seasonality=True,
                    yearly_seasonality=True,
                    changepoint_prior_scale=0.05 # Makes trend lines smoother
                )
                m.fit(df)
                
                # Setup the future dataframe with the same bounds
                future = m.make_future_dataframe(periods=30)
                future['floor'] = df['floor'].iloc[0]
                future['cap'] = df['cap'].iloc[0]
                
                forecast = m.predict(future)
                
                historical_prices = df['y'].round(2).tolist()
                future_forecast = forecast[forecast['ds'] > df['ds'].max()]
                
                # Double check no negative values slip into JSON
                future_prices = [max(0.0, round(x, 2)) for x in future_forecast['yhat']]
                current_p = float(historical_prices[-1])
                predicted_p = future_prices[-1] if future_prices else current_p
                
                payload = {
                    "historical_dates": df['ds'].dt.strftime('%Y-%m-%d').tolist(),
                    "historical_prices": historical_prices,
                    "future_dates": future_forecast['ds'].dt.strftime('%Y-%m-%d').tolist(),
                    "future_prices": future_prices,
                    "current_price": current_p,
                    "predicted_price": predicted_p,
                    "trend": "rising" if predicted_p > current_p else "falling" if predicted_p < current_p else "stable",
                    "fallback_type": "national"
                }
                
                existing = db.query(models.CachedPrediction).filter_by(cache_key=cache_key).first()
                if existing:
                    existing.payload = payload
                    existing.last_updated = datetime.utcnow()
                else:
                    new_cache = models.CachedPrediction(cache_key=cache_key, payload=payload)
                    db.add(new_cache)
                    
                db.commit()
                
        print("All ML Models Trained and Cached!")
    except Exception as e:
        print(f"[SCHEDULER ERROR]: {e}")
        db.rollback()
    finally:
        db.close()

@asynccontextmanager
async def lifespan(app: FastAPI):
    scheduler = BackgroundScheduler()
    scheduler.add_job(scheduled_clustering_job, 'interval', hours=1)
    scheduler.add_job(scheduled_ml_predictions, 'cron', hour=2, minute=0)
    scheduler.start()
    yield
    scheduler.shutdown()

app = FastAPI(title="MkulimaHub API", lifespan=lifespan)


limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


GOOGLE_CLIENT_ID = "654543955611-g18qameesn4daglsc8pup7rkj6c1n541.apps.googleusercontent.com"

class GoogleAuthRequest(BaseModel):
    id_token: str
    phone_number: Optional[str] = None
    role: Optional[str] = "farmer"

@app.post("/api/auth/google")
@limiter.limit("5/minute")
def google_login(request: Request, payload: GoogleAuthRequest, db: Session = Depends(get_db)):
    try:
        idinfo = id_token.verify_oauth2_token(payload.id_token, google_requests.Request(), GOOGLE_CLIENT_ID,clock_skew_in_seconds=30)
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

@app.post("/api/auth/google-register")
@limiter.limit("5/minute")
def google_register(request: Request, payload: GoogleAuthRequest, db: Session = Depends(get_db)):
    if not payload.phone_number:
        raise HTTPException(status_code=400, detail="Phone number is required for registration.")
        
    try:
        idinfo = id_token.verify_oauth2_token(payload.id_token, google_requests.Request(), GOOGLE_CLIENT_ID,clock_skew_in_seconds=10)
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

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        token_data = jwt.decode(token, security.SECRET_KEY, algorithms=[security.ALGORITHM])
        user_id: str = token_data.get("sub") 
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
        
    user = db.query(models.User).filter(models.User.id == int(user_id)).first()
    if user is None:
        raise credentials_exception
        
    return user

@app.get("/")
def read_root():
    return {"message": "MkulimaHub API is active!", "status": "secure"}

@app.post("/api/auth/register", response_model=schemas.UserResponse)
def register_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
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

@app.post("/auth/login", response_model=schemas.Token)
@limiter.limit("5/minute")
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

class PhoneAuthRequest(BaseModel):
    phone_number: str
    uid: str 

@app.post("/auth/phone-login")
@limiter.limit("5/minute")
def phone_login(request: Request, payload: PhoneAuthRequest, db: Session = Depends(get_db)):
    search_phone = payload.phone_number
    if search_phone.startswith("+254"):
        search_phone = "0" + search_phone[4:]

    user = db.query(models.User).filter(models.User.phone_number == search_phone).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Account not found. Please register first.")
    
    access_token = security.create_access_token(data={"sub": str(user.id), "role": user.role})
    return {"access_token": access_token, "token_type": "bearer", "status": "success"}

class PasswordResetRequest(BaseModel):
    phone_number: str
    uid: str
    new_password: str

@app.post("/auth/reset-password")
@limiter.limit("5/minute")
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




@app.put("/users/profile", response_model=schemas.UserRead)
def update_profile(profile_data: schemas.UserProfileUpdate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    update_data = profile_data.dict(exclude_unset=True)

    provided_lat = update_data.get("latitude")
    provided_lng = update_data.get("longitude")

    if provided_lat is None or provided_lng is None:
        ward = update_data.get("ward") or current_user.ward
        county = update_data.get("county") or current_user.county

        if ward and county:
            print(f"Asking OpenStreetMap for exact Ward: {ward}, {county}...")
            headers = {"User-Agent": "MkulimaHubApp/1.0 (Student Project)"}
            try:
                url_ward = f"https://nominatim.openstreetmap.org/search?q={ward}, {county}, Kenya&format=json&limit=1"
                ward_data = requests.get(url_ward, headers=headers).json()
                
                if ward_data:
                    update_data["latitude"] = float(ward_data[0]["lat"])
                    update_data["longitude"] = float(ward_data[0]["lon"])
                else:
                    url_county = f"https://nominatim.openstreetmap.org/search?q={county} County, Kenya&format=json&limit=1"
                    county_data = requests.get(url_county, headers=headers).json()
                    if county_data:
                        update_data["latitude"] = float(county_data[0]["lat"])
                        update_data["longitude"] = float(county_data[0]["lon"])
            except Exception as e:
                print(f"Geocoding API Error: {e}")

    for key, value in update_data.items():
        setattr(current_user, key, value) 

    try:
        db.add(current_user)
        db.commit()
        db.refresh(current_user)
        return current_user
    except Exception as e:
        db.rollback()
        print(f"DB Error updating profile: {e}")
        raise HTTPException(status_code=500, detail="Could not update profile. Please try again.")

@app.get("/users/me", response_model=schemas.UserRead)
def get_my_profile(current_user: models.User = Depends(get_current_user)):
    return current_user

@app.delete("/users/me")
def delete_my_account(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    db.delete(current_user)
    db.commit()
    return {"message": "Account deleted successfully"}



class BulkRequestCreate(BaseModel):
    crop_name: str
    target_weight_kg: float
    price_per_kg: float
    county: str
    ward: Optional[str] = None
    urgency: Optional[str] = "High"
    deadline_hours: Optional[int] = 24

@app.post("/harvests", status_code=status.HTTP_201_CREATED)
def create_harvest(harvest: schemas.HarvestCreate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if current_user.role != "farmer":
        raise HTTPException(status_code=403, detail="Only farmers can post harvests")

    new_harvest = models.Harvest(
        farmer_id=current_user.id,
        crop_name=harvest.crop_name,
        weight_kg=harvest.weight_kg,
        price_per_kg=harvest.price_per_kg
    )
    
    try:
        db.add(new_harvest)
        db.commit()
        db.refresh(new_harvest)
        return {"message": "Harvest posted successfully", "id": new_harvest.id}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to post harvest to the marketplace.")

class HarvestRead(schemas.HarvestCreate):
    id: int
    farmer_id: Optional[int] = None
    created_at: datetime
    class Config:
        from_attributes = True

@app.get("/harvests", response_model=List[HarvestRead])
def get_harvests(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    harvests = db.query(models.Harvest).filter(models.Harvest.farmer_id.isnot(None)).offset(skip).limit(limit).all()
    return harvests

@app.post("/api/buyer/contracts")
def create_bulk_contract(payload: BulkRequestCreate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Allows a buyer to post a new Bulk Contract to the Marketplace."""
    deadline = datetime.utcnow() + timedelta(hours=payload.deadline_hours)

    new_contract = models.BulkRequest(
        buyer_name=current_user.full_name, 
        crop_name=payload.crop_name,
        target_weight_kg=payload.target_weight_kg,
        price_per_kg=payload.price_per_kg,
        county=payload.county,
        ward=payload.ward,
        urgency=payload.urgency,
        status="Open",
        deadline_time=deadline # 🔥 SAVES DEADLINE
    )
    
    db.add(new_contract)
    db.commit()
    db.refresh(new_contract)
    
    return {"message": "Contract broadcasted to the network!", "contract_id": new_contract.id}

@app.get("/api/contracts")
def get_open_contracts(county: str = None, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    query = db.query(models.BulkRequest).filter(
        models.BulkRequest.status.in_(["Open", "fulfilled"]), 
        ~models.BulkRequest.buyer_name.like("Hub Pool:%") 
    )
    if county: query = query.filter(models.BulkRequest.county == county)
        
    contracts = query.all()
    results = []
    
    for req in contracts:
        has_pledged = any(p.farmer_id == current_user.id for p in req.pledges)
        total_pledged = sum((p.pledged_weight_kg or 0) for p in req.pledges) 
        
        results.append({
            "id": req.id, "crop_name": req.crop_name, "target_weight_kg": req.target_weight_kg,
            "total_pledged": total_pledged, "price_per_kg": req.price_per_kg,
            "buyer_name": req.buyer_name, "county": req.county,
            "ward": req.ward, 
            "urgency": req.urgency, 
            "deadline_time": req.deadline_time.isoformat() + "Z" if getattr(req, 'deadline_time', None) else None, # 🔥 FEEDS FLUTTER TIMER
            "has_pledged": has_pledged 
        })
    return results

@app.get("/api/my-pledges")
def get_my_pledges(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if current_user.role != "farmer":
        raise HTTPException(status_code=403, detail="Only farmers can view delivery squads.")

    pledges = db.query(models.Pledge)\
                .options(joinedload(models.Pledge.bulk_request))\
                .filter(
                    models.Pledge.farmer_id == current_user.id,
                    ~models.Pledge.status.in_(["paid", "completed", "rejected"]) 
                ).all()
    
    result = []
    db_needs_commit = False 
    
    for p in pledges:
        req = p.bulk_request 
        
        if not req:
            db.delete(p) 
            db_needs_commit = True 
            continue 

        if req.squad_status not in ["active", "voting", "fulfilled"]:
            total_pledged = db.query(func.sum(models.Pledge.pledged_weight_kg)).filter(models.Pledge.bulk_request_id == req.id).scalar() or 0.0
            
            if total_pledged >= req.target_weight_kg:
                unique_farmers = db.query(models.Pledge.farmer_id).filter(models.Pledge.bulk_request_id == req.id).distinct().count()
                
                if unique_farmers == 1:
                    req.coordinator_id = p.farmer_id
                    req.squad_status = "active"
                else:
                    req.squad_status = "voting"
                
                db_needs_commit = True

        squad_pledges = db.query(models.Pledge).filter(models.Pledge.bulk_request_id == req.id).all()
        squad_roster = []
        for sp in squad_pledges:
            farmer = db.query(models.User).filter(models.User.id == sp.farmer_id).first()
            if farmer:
                final_kg = sp.actual_weight_kg if sp.actual_weight_kg is not None else sp.pledged_weight_kg
                
                squad_roster.append({
                    "pledge_id": sp.id,              
                    "farmer_id": farmer.id,
                    "name": farmer.full_name,
                    "pledge_kg": sp.pledged_weight_kg,
                    "actual_kg": sp.actual_weight_kg,          
                    "payout_kes": final_kg * req.price_per_kg, 
                    "status": sp.status,             
                    "notes": sp.notes                
                })
                
        candidates_db = db.query(models.SquadCandidate).filter(models.SquadCandidate.bulk_request_id == req.id).all()
        candidates_list = []
        for c in candidates_db:
            candidates_list.append({
                "candidate_id": c.id,
                "farmer_id": c.farmer_id,
                "farmer_name": c.farmer.full_name if c.farmer else "Unknown",
                "pitch": c.pitch,
                "votes": c.votes
            })

        has_voted = db.query(models.SquadVote).filter(
            models.SquadVote.bulk_request_id == req.id,
            models.SquadVote.farmer_id == current_user.id
        ).first() is not None

        buyer_phone = "No phone available"
        if req.buyer_id:
            buyer = db.query(models.User).filter(models.User.id == req.buyer_id).first()
            if buyer and buyer.phone_number:
                buyer_phone = buyer.phone_number

        result.append({
            "id": p.id,
            "pledged_weight_kg": p.pledged_weight_kg,
            "actual_weight_kg": p.actual_weight_kg,
            "status": p.status,
            "bulk_request": {
                "id": req.id, "buyer_name": req.buyer_name, "crop_name": req.crop_name,
                "buyer_phone": buyer_phone, 
                "target_weight_kg": req.target_weight_kg, "price_per_kg": req.price_per_kg,
                "county": req.county, "ward": req.ward, "urgency": req.urgency, 
                "squad_status": req.squad_status, "coordinator_id": req.coordinator_id, 
                "squad_roster": squad_roster, "candidates": candidates_list, "has_voted": has_voted,
                "deadline_time": req.deadline_time.isoformat() if getattr(req, 'deadline_time', None) else None, # 🔥 TIMER
                "payment_status": getattr(req, 'payment_status', 'pending'),
                "payment_method": getattr(req, 'payment_method', 'pay_now')
            }
        })
        
    if db_needs_commit:
        db.commit() 
        
    return result

class PledgeUpdate(BaseModel):
    pledged_weight_kg: float

@app.put("/api/pledges/{pledge_id}", response_model=schemas.PledgeRead)
def update_pledge(pledge_id: int, payload: PledgeUpdate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    pledge = db.query(models.Pledge).filter(models.Pledge.id == pledge_id, models.Pledge.farmer_id == current_user.id).first()
    if not pledge:
        raise HTTPException(status_code=404, detail="Pledge not found.")

    try:
        pledge.pledged_weight_kg = payload.pledged_weight_kg
        db.flush()

        bulk_req = db.query(models.BulkRequest).filter(models.BulkRequest.id == pledge.bulk_request_id).first()
        total_pledged = db.query(func.sum(models.Pledge.pledged_weight_kg)).filter(models.Pledge.bulk_request_id == bulk_req.id).scalar() or 0.0

        if total_pledged < bulk_req.target_weight_kg:
            if getattr(bulk_req, 'payment_status', 'pending') != 'deposit_paid':
                bulk_req.status = "Open"
        else:
            bulk_req.status = "fulfilled"

        db.commit()
        db.refresh(pledge)
        return pledge
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to update pledge.")

@app.put("/api/qa/pledges/{pledge_id}/status")
def update_pledge_qa_status(pledge_id: int, payload: dict, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Handles the Buyer accepting or rejecting individual farmer drop-offs."""
    pledge = db.query(models.Pledge).filter(models.Pledge.id == pledge_id).first()
    if not pledge:
        raise HTTPException(status_code=404, detail="Pledge not found.")
        
    farmer = db.query(models.User).filter(models.User.id == pledge.farmer_id).first()
    pool = db.query(models.BulkRequest).filter(models.BulkRequest.id == pledge.bulk_request_id).first()
    if not pool:
        raise HTTPException(status_code=404, detail="Parent contract not found.")
        
    new_status = payload.get("status")
    
    if new_status == "paid" or new_status == "completed":
        actual_kg = pledge.actual_kg if pledge.actual_kg else pledge.pledged_weight_kg
        payout_amount = actual_kg * pool.price_per_kg
        payment_method = getattr(pool, 'payment_method', 'pay_now')
        
        if payment_method == 'pay_now':
            if farmer and (farmer.escrow_balance or 0.0) >= payout_amount:
                farmer.escrow_balance -= payout_amount
                farmer.available_balance = (farmer.available_balance or 0.0) + payout_amount
        else:
            if farmer:
                farmer.available_balance = (farmer.available_balance or 0.0) + payout_amount
                
    elif new_status == "disputed" or new_status == "rejected":
        pledge.dispute_notes = payload.get("notes", "Rejected during QA inspection.")
        
    pledge.status = new_status
    db.commit()
    return {"message": f"Pledge QA updated to {new_status}"}

@app.delete("/api/pledges/{pledge_id}")
def delete_pledge(pledge_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    pledge = db.query(models.Pledge).filter(models.Pledge.id == pledge_id, models.Pledge.farmer_id == current_user.id).first()
    if not pledge:
        raise HTTPException(status_code=404, detail="Pledge not found.")

    try:
        req_id = pledge.bulk_request_id
        db.delete(pledge)
        db.flush()

        bulk_req = db.query(models.BulkRequest).filter(models.BulkRequest.id == req_id).first()
        
        db.query(models.SquadCandidate).filter(
            models.SquadCandidate.bulk_request_id == req_id, 
            models.SquadCandidate.farmer_id == current_user.id
        ).delete()
        
        db.query(models.SquadVote).filter(
            models.SquadVote.bulk_request_id == req_id, 
            models.SquadVote.farmer_id == current_user.id
        ).delete()

        if bulk_req.coordinator_id == current_user.id:
            bulk_req.coordinator_id = None
            bulk_req.squad_status = "voting"

        total_pledged = db.query(func.sum(models.Pledge.pledged_weight_kg)).filter(models.Pledge.bulk_request_id == req_id).scalar() or 0.0

        if total_pledged < bulk_req.target_weight_kg:
            if getattr(bulk_req, 'payment_status', 'pending') != 'deposit_paid':
                bulk_req.status = "Open"
        else:
            bulk_req.status = "fulfilled"
            
        if total_pledged == 0:
            bulk_req.squad_status = "gathering"
            bulk_req.coordinator_id = None
            db.query(models.SquadCandidate).filter(models.SquadCandidate.bulk_request_id == req_id).delete()
            db.query(models.SquadVote).filter(models.SquadVote.bulk_request_id == req_id).delete()

        db.commit()
        return {"message": "Pledge deleted successfully."}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to delete pledge.")

# ==========================================
# 6. HUBS, CLUSTERS, & CO-OP CHAT
# ==========================================

def run_clustering_algorithm(db: Session, target_crop: str = "All"):
    query = db.query(models.User).filter(
        models.User.role == "farmer",
        models.User.hub_id == None,
        models.User.latitude.isnot(None),
        models.User.longitude.isnot(None)
    )

    if target_crop != "All":
        query = query.filter(models.User.main_crops.ilike(f"%{target_crop}%"))

    independent_farmers = query.all()
    if not independent_farmers:
        return 0

    data = []
    for f in independent_farmers:
        if f.main_crops:
            primary_crop = f.main_crops.split(',')[0].strip().title()
            data.append({
                "id": f.id,
                "lat": float(f.latitude),
                "lon": float(f.longitude),
                "crop": primary_crop,
                "ward": f.ward or "Regional"
            })
            
    if not data:
        return 0

    df = pd.DataFrame(data)
    total_hubs_created = 0
    
    EARTH_RADIUS_KM = 6371.0 
    MAX_DISTANCE_KM = 5.0 
    epsilon = MAX_DISTANCE_KM / EARTH_RADIUS_KM

    unique_crops = df['crop'].unique()
    
    for current_crop in unique_crops:
        crop_df = df[df['crop'] == current_crop].copy()
        
        if len(crop_df) < 2:
            continue

        coords = np.radians(crop_df[['lat', 'lon']].values)
        dbscan = DBSCAN(eps=epsilon, min_samples=2, algorithm='ball_tree', metric='haversine').fit(coords)
        crop_df['cluster'] = dbscan.labels_
        
        for cluster_id in crop_df['cluster'].unique():
            if cluster_id == -1: 
                continue
                
            cluster_farmers = crop_df[crop_df['cluster'] == cluster_id]
            ward_name = cluster_farmers.iloc[0]['ward']
            hub_name = f"{ward_name} {current_crop} Co-op"
            
            new_hub = models.Hub(
                name=hub_name,
                crop=current_crop,
                center_latitude=float(cluster_farmers['lat'].mean()), 
                center_longitude=float(cluster_farmers['lon'].mean())
            )
            db.add(new_hub)
            db.flush() 
            
            for farmer_id in cluster_farmers['id']:
                db.query(models.User).filter(models.User.id == farmer_id).update({"hub_id": new_hub.id})
            
            total_hubs_created += 1

    db.commit()
    return total_hubs_created

@app.post("/api/admin/trigger-clustering")
def admin_trigger_clustering(crop: str = "All", db: Session = Depends(get_db)):
    created = run_clustering_algorithm(db, target_crop=crop)
    return {"message": f"Successfully created {created} new permanent Hubs based on proximity and crop!"}

@app.get("/api/clusters")
def get_frozen_clusters(crop: str = None, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    query = db.query(models.Hub)
    if crop and crop != 'All':
        query = query.filter(models.Hub.crop.ilike(f"%{crop}%"))
    
    hubs = query.all()
    
    hub_ids = [h.id for h in hubs]
    all_hub_members = db.query(models.User).filter(
        models.User.hub_id.in_(hub_ids),
        models.User.role == "farmer"
    ).all()
    
    members_by_hub = {}
    for member in all_hub_members:
        if member.hub_id not in members_by_hub:
            members_by_hub[member.hub_id] = []
        members_by_hub[member.hub_id].append(member)

    indep_query = db.query(models.User).filter(
        models.User.latitude.isnot(None),
        models.User.longitude.isnot(None),
        models.User.hub_id == None,
        models.User.role == "farmer" 
    )
    
    if crop and crop != 'All':
        indep_query = indep_query.filter(models.User.main_crops.ilike(f"%{crop}%"))
    
    independent_farmers = indep_query.all()
    
    final_hubs = []
    total_analyzed = len(independent_farmers)
    
    for h in hubs:
        hub_members = members_by_hub.get(h.id, [])
        if len(hub_members) == 0:
            continue

        total_analyzed += len(hub_members)
        
        final_hubs.append({
            "hub_id": h.id,
            "hub_name": h.name,
            "farmer_count": len(hub_members),
            "coordinator_id": h.coordinator_id,
            "farmers": [
                {
                    "name": f.full_name,
                    "ward": f.ward,
                    "village": f.village,
                    "crops": f.main_crops
                } for f in hub_members
            ]
        })
        
    indep_list = [
        {
            "name": f.full_name,
            "ward": f.ward,
            "village": f.village,
            "crops": f.main_crops
        } for f in independent_farmers
    ]
    
    all_squads = db.query(models.BulkRequest).filter(
        models.BulkRequest.squad_status.in_(["gathering", "voting", "active"]),
        models.BulkRequest.status != "completed" 
    ).all()
    
    squads_db = []
    for req in all_squads:
        if req.squad_status in ["gathering", "voting"] and req.status == "Open":
            squads_db.append(req)
        elif req.squad_status == "active":
            if any(p.farmer_id == current_user.id for p in req.pledges):
                squads_db.append(req)
    
    active_squads_data = []
    
    for req in squads_db:
        has_voted = False
        if current_user:
            vote_check = db.query(models.SquadVote).filter(
                models.SquadVote.bulk_request_id == req.id,
                models.SquadVote.farmer_id == current_user.id
            ).first()
            if vote_check:
                has_voted = True

        candidates_db = db.query(models.SquadCandidate).filter(models.SquadCandidate.bulk_request_id == req.id).all()
        candidates_list = []
        for c in candidates_db:
            candidates_list.append({
                "candidate_id": c.id,
                "farmer_id": c.farmer_id,
                "farmer_name": c.farmer.full_name if c.farmer else "Unknown",
                "pitch": c.pitch,
                "votes": c.votes
            })

        active_squads_data.append({
            "id": req.id,
            "buyer_name": req.buyer_name,
            "crop_name": req.crop_name,
            "target_weight_kg": req.target_weight_kg,
            "price_per_kg": req.price_per_kg,
            "county": req.county,
            "squad_status": req.squad_status,
            "coordinator_id": req.coordinator_id,
            "deadline_time": req.deadline_time.isoformat() if getattr(req, 'deadline_time', None) else None, # 🔥 TIMER
            "pledges": [{"farmer_id": p.farmer_id} for p in req.pledges],
            "candidates": candidates_list,
            "has_voted": has_voted 
        })
    
    return {
        "total_farmers_analyzed": total_analyzed,
        "total_hubs_found": len(final_hubs),
        "hubs": final_hubs,
        "independent_farmers": indep_list,
        "active_squads": active_squads_data 
    }

@app.put("/users/leave-hub")
def leave_hub(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    current_user.hub_id = None
    db.commit()
    return {"message": "Successfully left the Co-op."}

@app.get("/api/hubs/{hub_name}/messages", response_model=List[schemas.HubMessageRead])
def get_hub_messages(hub_name: str, db: Session = Depends(get_db)):
    messages = db.query(models.HubMessage).filter(models.HubMessage.hub_name == hub_name).order_by(models.HubMessage.created_at.asc()).all()
    result = []
    
    for m in messages:
        msg_text = m.message
        if msg_text.startswith("POOL_REQ|"):
            parts = msg_text.split('|')
            if len(parts) >= 2:
                contract_id = int(parts[1])
                contract = db.query(models.BulkRequest).filter(models.BulkRequest.id == contract_id).first()
                if contract:
                    total_pledged = db.query(func.sum(models.Pledge.pledged_weight_kg)).filter(models.Pledge.bulk_request_id == contract_id).scalar() or 0.0
                    msg_text = f"{m.message}|{total_pledged}|{contract.status}"

        result.append({
            "id": m.id,
            "hub_name": m.hub_name,
            "message": msg_text,
            "created_at": m.created_at,
            "sender_name": m.sender.full_name if m.sender else "Unknown Farmer"
        })
        
    return result

@app.post("/api/hubs/{hub_name}/messages", response_model=schemas.HubMessageRead)
def post_hub_message(hub_name: str, msg: schemas.HubMessageCreate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    new_message = models.HubMessage(
        hub_name=hub_name,
        sender_id=current_user.id,
        message=msg.message
    )
    db.add(new_message)
    db.commit()
    db.refresh(new_message)
    
    return {
        "id": new_message.id,
        "hub_name": new_message.hub_name,
        "message": new_message.message,
        "created_at": new_message.created_at,
        "sender_name": current_user.full_name
    }


class PredictionRequest(BaseModel):
    commodity: str
    days: int
    region: str
    price_type: str

KENYA_COUNTIES = [
    "Mombasa", "Kwale", "Kilifi", "Tana River", "Lamu", "Taita Taveta", 
    "Garissa", "Wajir", "Mandera", "Marsabit", "Isiolo", "Meru", 
    "Tharaka Nithi", "Embu", "Kitui", "Machakos", "Makueni", "Nyandarua", 
    "Nyeri", "Kirinyaga", "Murang'a", "Kiambu", "Turkana", "West Pokot", 
    "Samburu", "Trans Nzoia", "Uasin Gishu", "Elgeyo Marakwet", "Nandi", 
    "Baringo", "Laikipia", "Nakuru", "Narok", "Kajiado", "Kericho", 
    "Bomet", "Kakamega", "Vihiga", "Bungoma", "Busia", "Siaya", 
    "Kisumu", "Homa Bay", "Migori", "Kisii", "Nyamira", "Nairobi"
]

@app.post("/api/predict-price")
def predict_prices(request: PredictionRequest, db: Session = Depends(get_db)):
    req_crop = request.commodity.strip().lower()
    req_type = request.price_type.strip().lower()
    
    target_key = f"{req_crop}_national_{req_type}"
    fallback_key = f"{req_crop}_national_retail" if req_type == "wholesale" else f"{req_crop}_national_wholesale"

    cached_data = db.query(models.CachedPrediction).filter_by(cache_key=target_key).first()
    if not cached_data:
        cached_data = db.query(models.CachedPrediction).filter_by(cache_key=fallback_key).first()
        
    if not cached_data:
        raise HTTPException(status_code=404, detail="AI predictions for this crop are still processing. Check back soon!")
        
    return cached_data.payload

def get_market_spot_price(crop: str, county: str) -> str:
    db = SessionLocal() 
    try:
        latest_record = db.query(models.MarketPrice).filter(
            models.MarketPrice.commodity.ilike(f"%{crop}%"),
            models.MarketPrice.county.ilike(f"%{county}%")
        ).order_by(models.MarketPrice.date.desc()).first()
        
        if latest_record:
            return f"Live Spot Price: {crop.capitalize()} is currently trading at KES {latest_record.price_kes} per kg in {county.capitalize()}."
        return f"I couldn't find any recent market data for {crop} in {county}."
    finally:
        db.close() 

def predict_price_trend(crop: str) -> str:
    db = SessionLocal()
    try:
        cached = db.query(models.CachedPrediction).filter(
            models.CachedPrediction.cache_key.ilike(f"%{crop.lower()}_national%")
        ).first()
        
        if cached and cached.payload:
            trend = cached.payload.get("trend", "stable")
            pred_price = cached.payload.get("predicted_price", 0)
            return f"AI Trend Analysis: {crop.capitalize()} prices are trending {trend} and are expected to hit KES {pred_price} in the next 30 days."
        return f"AI Models are currently analyzing the 30-day forecast for {crop}. Check back soon."
    finally:
        db.close()

def get_weather_forecast(location: str) -> str:
    return f"Live Weather Data for {location}: Sunny, 28°C."

def diagnose_crop_disease(symptoms: str) -> str:
    return "Based on your description, there is a high probability of Fungal Blight. Ensure you check the undersides of the leaves."
 
@app.get("/api/market-metadata")
def get_market_metadata(db: Session = Depends(get_db)):
    counties = db.query(models.MarketPrice.county).distinct().all()
    all_crops = db.query(models.MarketPrice.commodity).distinct().all()
    
    regions_list = sorted([c[0] for c in counties if c[0]])
    crops_list = sorted([c[0] for c in all_crops if c[0]])
    
    county_crop_map = {}
    
    for region in regions_list:
        crops_in_county = db.query(models.MarketPrice.commodity)\
                            .filter(models.MarketPrice.county == region)\
                            .distinct().all()
        county_crop_map[region] = sorted([c[0] for c in crops_in_county if c[0]])
        
    return {
        "regions": regions_list if regions_list else sorted(KENYA_COUNTIES), 
        "crops": crops_list, 
        "county_crop_map": county_crop_map 
    }

@app.get("/api/hubs/nearby")
def get_nearby_hubs(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if current_user.latitude is None or current_user.longitude is None:
        raise HTTPException(status_code=400, detail="Please update your profile with your location first.")

    hubs = db.query(models.Hub).all()
    if not hubs:
        return []

    kms_per_radian = 6371.0088
    hub_distances = []
    
    user_lat_rad = np.radians(current_user.latitude)
    user_lon_rad = np.radians(current_user.longitude)

    for hub in hubs:
        hub_lat_rad = np.radians(hub.center_latitude)
        hub_lon_rad = np.radians(hub.center_longitude)
        
        dlat = hub_lat_rad - user_lat_rad
        dlon = hub_lon_rad - user_lon_rad
        a = np.sin(dlat/2)**2 + np.cos(user_lat_rad) * np.cos(hub_lat_rad) * np.sin(dlon/2)**2
        c = 2 * np.arcsin(np.sqrt(a))
        distance_km = kms_per_radian * c
        
        hub_distances.append({
            "hub_id": hub.id,
            "hub_name": hub.name,
            "crop": hub.crop,
            "distance_km": round(distance_km, 1)
        })

    hub_distances.sort(key=lambda x: x["distance_km"])
    return hub_distances[:3]

@app.post("/api/hubs/{hub_id}/join")
def request_to_join_hub(hub_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if current_user.hub_id is not None:
        raise HTTPException(status_code=400, detail="You are already in a hub.")
        
    existing_req = db.query(models.HubRequest).filter(
        models.HubRequest.hub_id == hub_id,
        models.HubRequest.farmer_id == current_user.id
    ).first()
    
    if existing_req:
        return {"message": "You already have a pending request for this hub."}
        
    new_request = models.HubRequest(hub_id=hub_id, farmer_id=current_user.id, status="pending")
    db.add(new_request)
    db.commit()
    
    return {"message": "Request sent successfully! Waiting for coordinator approval."}

@app.get("/api/coordinator/requests")
def get_pending_requests(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    hub = db.query(models.Hub).filter(models.Hub.coordinator_id == current_user.id).first()
    if not hub:
        return [] 
        
    requests = db.query(models.HubRequest).filter(
        models.HubRequest.hub_id == hub.id,
        models.HubRequest.status == "pending"
    ).all()
    
    return [{
        "request_id": r.id,
        "farmer_name": r.farmer.full_name,
        "farmer_phone": r.farmer.phone_number,
        "crops": r.farmer.main_crops,
        "village": r.farmer.village
    } for r in requests]

@app.put("/api/coordinator/requests/{request_id}")
def respond_to_request(request_id: int, action: str, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    req = db.query(models.HubRequest).filter(models.HubRequest.id == request_id).first()
    
    if not req:
        raise HTTPException(status_code=404, detail="Request not found")
        
    hub = db.query(models.Hub).filter(models.Hub.id == req.hub_id).first()
    if hub.coordinator_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to manage this hub.")
        
    if action == "approve":
        req.status = "approved"
        req.farmer.hub_id = hub.id 
    elif action == "reject":
        req.status = "rejected"
    else:
        raise HTTPException(status_code=400, detail="Invalid action. Use 'approve' or 'reject'.")
        
    db.commit()
    return {"message": f"Farmer has been {action}d successfully."}

class HubPitchPayload(BaseModel):
    pitch: str

@app.post("/api/hubs/election/run")
def run_for_hub_coordinator(payload: HubPitchPayload, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if not current_user.hub_id:
        raise HTTPException(status_code=400, detail="You must be in a Hub to run for Coordinator.")
        
    hub = db.query(models.Hub).filter(models.Hub.id == current_user.hub_id).first()
    if hub.coordinator_id is not None:
        raise HTTPException(status_code=400, detail="This hub already has a coordinator.")
        
    existing = db.query(models.HubCandidate).filter(
        models.HubCandidate.hub_id == current_user.hub_id, 
        models.HubCandidate.farmer_id == current_user.id
    ).first()
    
    if existing:
        raise HTTPException(status_code=400, detail="You are already on the ballot!")
        
    new_candidate = models.HubCandidate(
        hub_id=current_user.hub_id,
        farmer_id=current_user.id,
        pitch=payload.pitch
    )
    db.add(new_candidate)
    db.commit()
    return {"message": "Candidacy submitted successfully!"}

@app.get("/api/hubs/election/ballot")
def get_election_ballot(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if not current_user.hub_id:
        return {"status": "no_hub", "candidates": []}

    hub = db.query(models.Hub).filter(models.Hub.id == current_user.hub_id).first()
    if hub.coordinator_id is not None:
        return {"status": "election_over", "coordinator_id": hub.coordinator_id}

    candidates = db.query(models.HubCandidate).filter(models.HubCandidate.hub_id == hub.id).all()
    
    has_voted = db.query(models.HubVote).filter(
        models.HubVote.hub_id == hub.id,
        models.HubVote.voter_id == current_user.id
    ).first() is not None

    results = []
    for c in candidates:
        vote_count = db.query(models.HubVote).filter(models.HubVote.candidate_id == c.id).count()
        farmer = db.query(models.User).filter(models.User.id == c.farmer_id).first()
        
        results.append({
            "candidate_id": c.id,
            "farmer_name": farmer.full_name,
            "pitch": c.pitch,
            "votes": vote_count
        })

    return {
        "status": "voting_active",
        "has_voted": has_voted,
        "candidates": results
    }

@app.post("/api/hubs/election/vote/{candidate_id}")
def cast_vote(candidate_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if not current_user.hub_id:
        raise HTTPException(status_code=400, detail="You must be in a Hub to vote.")

    existing_vote = db.query(models.HubVote).filter(
        models.HubVote.hub_id == current_user.hub_id,
        models.HubVote.voter_id == current_user.id
    ).first()
    
    if existing_vote:
        raise HTTPException(status_code=400, detail="You have already cast your vote.")

    candidate = db.query(models.HubCandidate).filter(models.HubCandidate.id == candidate_id).first()
    if not candidate:
        raise HTTPException(status_code=404, detail="Candidate not found.")
        
    if candidate.farmer_id == current_user.id:
        raise HTTPException(status_code=400, detail="You cannot vote for yourself. A true leader needs the community's backing!")

    vote = models.HubVote(hub_id=current_user.hub_id, voter_id=current_user.id, candidate_id=candidate_id)
    db.add(vote)
    db.commit() 

    total_hub_members = db.query(models.User).filter(models.User.hub_id == current_user.hub_id).count()
    candidate_votes = db.query(models.HubVote).filter(models.HubVote.candidate_id == candidate_id).count()
    majority_threshold = (total_hub_members / 2) if total_hub_members > 2 else 0

    if candidate_votes > majority_threshold:
        hub = db.query(models.Hub).filter(models.Hub.id == current_user.hub_id).first()
        hub.coordinator_id = candidate.farmer_id
        db.commit()
        return {"message": "Vote cast! We have a winner! The election is over."}

    return {"message": "Vote cast successfully!"}

class ProcessDeliveryPayload(BaseModel):
    action: str 
    actual_weight_kg: Optional[float] = None
    notes: Optional[str] = None

class HubPoolCreate(BaseModel):
    crop_name: str
    target_weight_kg: float
    price_per_kg: float

@app.post("/api/hubs/{hub_name}/pools")
def create_hub_pool(hub_name: str, payload: HubPoolCreate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    # Give the hub pool an automatic 1-year deadline, since it's practically open-ended
    deadline = datetime.utcnow() + timedelta(days=365)
    new_pool = models.BulkRequest(
        buyer_name=f"Hub Pool: {hub_name}", 
        crop_name=payload.crop_name,
        target_weight_kg=payload.target_weight_kg,
        price_per_kg=payload.price_per_kg,
        county="Hub Internal",
        status="Open",
        squad_status="gathering",
        deadline_time=deadline, # 🔥 SAVES DEADLINE
        coordinator_id=current_user.id 
    )
    db.add(new_pool)
    db.commit()
    db.refresh(new_pool)

    chat_payload = f"POOL_REQ|{new_pool.id}|{payload.crop_name}|{payload.target_weight_kg}|{payload.price_per_kg}"
    chat_msg = models.HubMessage(
        hub_name=hub_name,
        sender_id=current_user.id,
        message=chat_payload
    )
    db.add(chat_msg)
    db.commit()

    return {"message": "Pool created and broadcasted!", "contract_id": new_pool.id}

@app.get("/api/hubs/deliveries")
def get_hub_deliveries(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    my_hub = db.query(models.Hub).filter(models.Hub.coordinator_id == current_user.id).first()
    
    active_pools = db.query(models.BulkRequest).filter(
        models.BulkRequest.squad_status.in_(["gathering", "voting", "active", "in_transit", "delivered"])
    ).all()
    
    results = []
    for pool in active_pools:
        is_hub_pool = pool.buyer_name and pool.buyer_name.startswith("Hub Pool:")
        is_authorized = False
        
        if is_hub_pool:
            if my_hub and pool.buyer_name == f"Hub Pool: {my_hub.name}":
                is_authorized = True
        else:
            if pool.coordinator_id == current_user.id:
                is_authorized = True
                
        if not is_authorized:
            continue

        if pool.squad_status == "gathering":
            continue

        pledges = db.query(models.Pledge).filter(models.Pledge.bulk_request_id == pool.id).all()
        if not pledges: continue
        
        roster = []
        has_pending_audit = False
        all_received = True

        for p in pledges:
            if p.status == 'pending_audit': has_pending_audit = True
            if p.status not in ['received', 'rejected', 'in_transit', 'delivered', 'completed', 'paid']: all_received = False
            
            farmer = db.query(models.User).filter(models.User.id == p.farmer_id).first()
            roster.append({
                "pledge_id": p.id,
                "farmer_id": farmer.id if farmer else 0,
                "farmer_name": farmer.full_name if farmer else "Unknown",
                "pledged_kg": p.pledged_weight_kg,
                "actual_kg": p.actual_weight_kg,
                "status": p.status,
                "notes": p.notes
            })

        total_pledged = sum(p.pledged_weight_kg for p in pledges if p.status != 'rejected')
        total_actual = sum((p.actual_weight_kg or 0) for p in pledges if p.status != 'rejected')

        ui_status = "delivered" if total_pledged >= pool.target_weight_kg else "in_transit"
        if has_pending_audit: ui_status = "pending_audit"
        elif all_received: ui_status = "received"

        coordinator_name = "Hub Drop-off"
        if pool.coordinator_id:
            coord_user = db.query(models.User).filter(models.User.id == pool.coordinator_id).first()
            if coord_user: coordinator_name = coord_user.full_name

        results.append({
            "squad_id": pool.id,
            "buyer_name": pool.buyer_name,
            "ward": pool.ward,
            "crop_name": pool.crop_name,
            "coordinator_name": coordinator_name, 
            "total_pledged": total_pledged,
            "target_weight": pool.target_weight_kg,
            "total_actual": total_actual,
            "status": ui_status,
            "deadline_time": pool.deadline_time.isoformat() if getattr(pool, 'deadline_time', None) else None, # 🔥 TIMER
            "farmer_count": len([p for p in pledges if p.status != 'rejected']),
            "roster": roster 
        })

    return results

@app.post("/api/hubs/deliveries/{squad_id}/process")
def process_hub_delivery(squad_id: int, payload: ProcessDeliveryPayload, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    squad = db.query(models.BulkRequest).filter(models.BulkRequest.id == squad_id).first()
    if not squad:
        raise HTTPException(status_code=404, detail="Squad not found.")

    pledges = db.query(models.Pledge).filter(models.Pledge.bulk_request_id == squad_id).all()

    if payload.action == "receive":
        actual_total = payload.actual_weight_kg or sum(p.pledged_weight_kg for p in pledges)
        pledged_total = sum(p.pledged_weight_kg for p in pledges)
        
        ratio = actual_total / pledged_total if pledged_total > 0 else 1.0

        for pledge in pledges:
            pledge.status = "received"
            pledge.actual_weight_kg = round(pledge.pledged_weight_kg * ratio, 2)
            pledge.notes = payload.notes or "Verified and stored at Hub."

    elif payload.action == "reject":
        for pledge in pledges:
            pledge.status = "rejected"
            pledge.notes = payload.notes or "Entire squad rejected at Hub Quality Control."

    db.commit()
    return {"message": "Squad Delivery Processed!"}

@app.get("/api/my-deliveries")
def get_my_deliveries(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    unified_deliveries = []
    

    pledges = db.query(models.Pledge).filter(models.Pledge.farmer_id == current_user.id).all()
    
    for p in pledges:
        contract = db.query(models.BulkRequest).filter(models.BulkRequest.id == p.bulk_request_id).first()
        if not contract:
            continue
            
        is_internal_pool = contract.buyer_name.startswith("Hub Pool:")

        display_notes = p.notes
        if display_notes and str(display_notes).startswith("EVIDENCE_LOG|"):
            if is_internal_pool:
                display_notes = "📷 Digital Evidence Submitted. Awaiting Hub Admin Audit."
            else:
                display_notes = "📷 Digital Evidence Submitted. Awaiting Squad Coordinator Verification."
        elif not display_notes:
            if is_internal_pool:
                display_notes = "Deliver to Hub Admin."
            else:
                display_notes = "Deliver to Squad Coordinator."

        all_squad_received = True
        squad_pledges_check = db.query(models.Pledge).filter(models.Pledge.bulk_request_id == contract.id).all()
        for sp in squad_pledges_check:
            if sp.status not in ['received', 'in_transit', 'delivered', 'completed', 'paid']:
                all_squad_received = False

        final_kg = p.actual_weight_kg if p.actual_weight_kg is not None else p.pledged_weight_kg

        unified_deliveries.append({
            "id": f"BLK-{p.id:04d}", 
            "type": "Co-op Pool" if is_internal_pool else "Bulk Contract",
            "pledge_id": p.id, # 🔥 THE FIX: Now Flutter knows the exact Pledge ID!
            "crop": contract.crop_name, 
            "weight_kg": p.pledged_weight_kg,
            "actual_kg": p.actual_weight_kg, 
            "unit": "KG", 
            "expected_payout": final_kg * contract.price_per_kg, 
            "status": p.status, 
            "buyer": "Your Local Co-op" if is_internal_pool else contract.buyer_name, 
            "notes": display_notes,
            "deadline_time": contract.deadline_time.isoformat() + "Z" if getattr(contract, 'deadline_time', None) else None,
            "is_coordinator": contract.coordinator_id == current_user.id, 
            "bulk_request_id": contract.id, 
            "squad_status": contract.squad_status,
            "all_squad_received": all_squad_received 
        })

    
    try:
        direct_orders = db.query(models.MarketOrder).join(models.MarketListing).filter(
            models.MarketListing.farmer_id == current_user.id
        ).all()
        
        for order in direct_orders:
            listing = order.listing
            buyer = db.query(models.User).filter(models.User.id == order.buyer_id).first()
            
            raw_method = str(getattr(order, 'delivery_method', 'Delivery'))
            if "|" in raw_method:
                clean_method, custom_address = raw_method.split("|", 1)
            else:
                clean_method = raw_method
                custom_address = f"{buyer.village}, {buyer.ward}" if buyer else "Address Pending"

            qty = getattr(order, 'quantity_ordered', getattr(order, 'quantity', 0))

            unified_deliveries.append({
                "id": f"ORD-{order.id:04d}",
                "order_id": order.id,
                "type": "Direct Sale",
                "crop": listing.crop_name if listing else "Produce",
                "weight_kg": qty,
                "unit": getattr(order, 'order_type', 'KG'),
                "expected_payout": order.total_price,
                "status": order.status,
                "buyer": buyer.full_name if buyer else "Unknown",
                "buyer_phone": buyer.phone_number if buyer else "No phone",
                "buyer_address": custom_address, 
                "delivery_method": clean_method,
                "payment_method": getattr(order, 'payment_method', 'pay_now'), 
                "dispute_notes": getattr(order, 'dispute_notes', "Direct order from marketplace.")
            })
    except Exception as e:
        print(f"Direct Sales fetch error: {e}")
        
    return unified_deliveries
    
class SquadStatusUpdate(BaseModel):
    status: str

class MessageCreate(BaseModel):
    message: str 

@app.put("/api/deliveries/squad/{bulk_request_id}/status")
def update_squad_delivery_status(bulk_request_id: int, payload: SquadStatusUpdate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    req = db.query(models.BulkRequest).filter(models.BulkRequest.id == bulk_request_id).first()
    if not req:
        raise HTTPException(status_code=404, detail="Contract not found.")
        
    if req.coordinator_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the elected Squad Coordinator can update the transit status!")

    req.squad_status = payload.status

    squad_pledges = db.query(models.Pledge).filter(models.Pledge.bulk_request_id == bulk_request_id).all()
    for pledge in squad_pledges:
        pledge.status = payload.status
        
    db.commit()
    return {"message": f"Squad delivery marked as {payload.status}!"}

class QAUpdate(BaseModel):
    status: str
    notes: Optional[str] = None
    dispute_image: Optional[str] = None

@app.put("/api/buyer/pledges/{pledge_id}/qa")
def update_qa_status(pledge_id: int, payload: QAUpdate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    pledge = db.query(models.Pledge).filter(models.Pledge.id == pledge_id).first()
    if not pledge: raise HTTPException(status_code=404, detail="Pledge not found.")
        
    contract = db.query(models.BulkRequest).filter(models.BulkRequest.id == pledge.bulk_request_id).first()
    if contract.buyer_name != current_user.full_name:
        raise HTTPException(status_code=403, detail="Unauthorized.")

    if payload.status in ["disputed", "rejected", "returning"]:
        farmer = db.query(models.User).filter(models.User.id == pledge.farmer_id).first()
        buyer = db.query(models.User).filter(models.User.id == contract.buyer_id).first()
        
        is_pickup = False
        if contract.buyer_name.startswith("Hub Pool:"): is_pickup = True
        elif contract.ward and "pickup" in contract.ward.lower(): is_pickup = True

        actual_kg = pledge.actual_weight_kg if pledge.actual_weight_kg else pledge.pledged_weight_kg
        total_value = actual_kg * contract.price_per_kg
        refund_amount = total_value * 1.0 if getattr(contract, 'payment_status', '') == 'fully_paid_escrow' else total_value * 0.10

        if farmer and (farmer.escrow_balance or 0.0) >= refund_amount:
            farmer.escrow_balance -= refund_amount
            
            if is_pickup:
                if buyer: buyer.available_balance = (buyer.available_balance or 0.0) + refund_amount
                pledge.status = "rejected"
            else:
                if buyer: buyer.escrow_balance = (buyer.escrow_balance or 0.0) + refund_amount
                pledge.status = "returning"
        else:
            pledge.status = "rejected" if is_pickup else "returning"
            
        if payload.notes: pledge.dispute_notes = payload.notes
        
    else:
        pledge.status = payload.status
        if payload.notes: pledge.notes = payload.notes

    if payload.status == "paid":
        all_pledges = db.query(models.Pledge).filter(models.Pledge.bulk_request_id == contract.id).all()
        if all(p.status in ['paid', 'rejected'] for p in all_pledges):
            contract.status = "completed"
            
    db.commit()
    return {"message": "QA Processed!"}

@app.put("/api/buyer/orders/{order_id}/qa")
def update_direct_order_qa(order_id: int, payload: QAUpdate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    order = db.query(models.MarketOrder).filter(models.MarketOrder.id == order_id).first()
    if not order: raise HTTPException(status_code=404, detail="Order not found.")
    
    # Safe fallback for old orders that might not have a subtotal
    farmer_payout = order.subtotal if (order.subtotal is not None and order.subtotal > 0) else order.total_price

    if payload.status in ["disputed", "rejected", "returning"]:
        listing = db.query(models.MarketListing).filter(models.MarketListing.id == order.listing_id).first()
        farmer = db.query(models.User).filter(models.User.id == listing.farmer_id).first() if listing else None
        buyer = db.query(models.User).filter(models.User.id == order.buyer_id).first()
        
        is_pickup = getattr(order, 'delivery_method', '').lower().find("pickup") != -1
        
        if getattr(order, 'payment_method', 'pay_now') == 'pay_now':
            if farmer and (farmer.escrow_balance or 0.0) > 0:
                # 🔥 BULLETPROOF FLOAT FIX: Force transfer whatever is smaller to avoid float crashes
                transfer_amt = min(farmer.escrow_balance, farmer_payout)
                farmer.escrow_balance -= transfer_amt
                
                if is_pickup:
                    if buyer: buyer.available_balance = (buyer.available_balance or 0.0) + order.total_price
                    order.status = "rejected"
                else:
                    if buyer: buyer.escrow_balance = (buyer.escrow_balance or 0.0) + order.total_price
                    order.status = "returning"
        else:
            order.status = "rejected" if is_pickup else "returning"
            
        if payload.notes: order.dispute_notes = payload.notes

    elif payload.status == "completed" and getattr(order, 'payment_method', 'pay_now') == 'pay_now':
        listing = db.query(models.MarketListing).filter(models.MarketListing.id == order.listing_id).first()
        farmer = db.query(models.User).filter(models.User.id == listing.farmer_id).first() if listing else None
        
        if farmer and (farmer.escrow_balance or 0.0) > 0:
            transfer_amt = min(farmer.escrow_balance, farmer_payout)
            farmer.escrow_balance -= transfer_amt
            farmer.available_balance = (farmer.available_balance or 0.0) + transfer_amt
            
        order.status = payload.status

    db.commit()
    return {"message": "QA Processed!"}

@app.get("/api/buyer/dashboard")
def get_buyer_dashboard(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    contracts = db.query(models.BulkRequest).filter(
        models.BulkRequest.buyer_id == current_user.id
    ).all()
    
    total_capital_committed = 0
    total_tonnage_requested = 0
    active_contracts = []
    
    for contract in contracts:
        pledges = db.query(models.Pledge).filter(models.Pledge.bulk_request_id == contract.id).all()
        
        expected_weight = 0
        actual_weight = 0
        
        roster = []
        for p in pledges:
            if p.status != 'rejected': 
                expected_weight += p.pledged_weight_kg
                final_kg = p.actual_weight_kg if p.actual_weight_kg is not None else p.pledged_weight_kg
                actual_weight += final_kg
                
                farmer = db.query(models.User).filter(models.User.id == p.farmer_id).first()
                if farmer:
                    roster.append({
                        "pledge_id": p.id,
                        "farmer_name": farmer.full_name,
                        "status": p.status,
                        "pledged_kg": p.pledged_weight_kg, 
                        "actual_kg": p.actual_weight_kg    
                    })

        progress_pct = expected_weight / contract.target_weight_kg if contract.target_weight_kg > 0 else 0
        
        c_status = contract.status
        if c_status != "completed":
            c_status = "fulfilled" if expected_weight >= contract.target_weight_kg else "active"

        is_hub_pool = contract.buyer_name and contract.buyer_name.startswith("Hub Pool:")
        if not is_hub_pool and getattr(contract, 'payment_method', 'pay_now') != "pay_on_delivery":
            contract.payment_method = "pay_on_delivery"
            db.commit()

        coord = db.query(models.User).filter(models.User.id == contract.coordinator_id).first()
        coord_phone = coord.phone_number if coord else "Awaiting Election"
        pickup_loc = f"{coord.village}, {coord.ward}" if coord else "Hub Location Pending"
        
        coord_lat, coord_lng = -1.2921, 36.8219 # Default Nairobi
        
        if coord and coord.latitude:
            coord_lat, coord_lng = coord.latitude, coord.longitude
        elif is_hub_pool:
            hub_name = contract.buyer_name.replace("Hub Pool: ", "").strip()
            hub = db.query(models.Hub).filter(models.Hub.name == hub_name).first()
            if hub and hub.center_latitude:
                coord_lat, coord_lng = hub.center_latitude, hub.center_longitude

        original_price = contract.target_weight_kg * contract.price_per_kg
        adjusted_price = actual_weight * contract.price_per_kg

        total_capital_committed += adjusted_price if c_status in ['fulfilled', 'completed'] else original_price
        total_tonnage_requested += contract.target_weight_kg

        active_contracts.append({
            "contract_id": contract.id, 
            "crop_name": contract.crop_name,
            "target_weight_kg": contract.target_weight_kg, 
            "pledged_weight_kg": expected_weight,
            "price_per_kg": contract.price_per_kg, 
            "progress_percentage": min(progress_pct, 1.0),
            "payment_status": getattr(contract, 'payment_status', 'pending'),
            "payment_method": getattr(contract, 'payment_method', 'pay_on_delivery'),
            "status": c_status, 
            "roster": roster,
            "coordinator_phone": coord_phone, 
            "pickup_location": pickup_loc,
            "lat": coord_lat, 
            "lng": coord_lng, 
            "deadline_time": contract.deadline_time.isoformat() + "Z" if getattr(contract, 'deadline_time', None) else None,
            "original_price": original_price,  
            "adjusted_price": adjusted_price   
        })

    market_orders = db.query(models.MarketOrder).filter(models.MarketOrder.buyer_id == current_user.id).all()
    direct_orders = []
    
    for order in market_orders:
        listing = order.listing
        farmer = listing.farmer if listing else None
        
        qty = getattr(order, 'quantity_ordered', getattr(order, 'quantity', 0))
        unit_type = getattr(order, 'order_type', 'KG')
        
        if unit_type == "KG":
            total_tonnage_requested += qty
            
        raw_method = str(getattr(order, 'delivery_method', 'Delivery'))
        if "|" in raw_method:
            clean_method, _ = raw_method.split("|", 1)
        else:
            clean_method = raw_method
            
        direct_orders.append({
            "order_id": order.id,
            "crop_name": listing.crop_name if listing else "Produce",
            "quantity": qty, 
            "unit": unit_type,
            "total_price": order.total_price, 
            "status": order.status,
            "farmer_name": farmer.full_name if farmer else "Local Farmer",
            "farmer_phone": farmer.phone_number if farmer else "N/A",
            "lat": farmer.latitude if farmer and farmer.latitude else -1.2921, 
            "lng": farmer.longitude if farmer and farmer.longitude else 36.8219, 
            "delivery_method": clean_method,
            "payment_method": getattr(order, 'payment_method', 'pay_now'), 
            "dispute_notes": getattr(order, 'dispute_notes', None),            
        })

    return {
        "metrics": {
            "total_capital_kes": total_capital_committed,
            "total_tonnage_kg": total_tonnage_requested,
            "active_contract_count": len([c for c in active_contracts if c['status'] != 'completed']) + len([o for o in direct_orders if o['status'] not in ['paid', 'completed', 'rejected']])
        },
        "contracts": active_contracts,
        "direct_orders": direct_orders 
    }

@app.post("/api/buyer/contracts")
def create_bulk_contract(payload: BulkRequestCreate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    deadline = datetime.utcnow() + timedelta(hours=payload.deadline_hours)

    new_contract = models.BulkRequest(
        buyer_name=current_user.full_name, 
        crop_name=payload.crop_name,
        target_weight_kg=payload.target_weight_kg,
        price_per_kg=payload.price_per_kg,
        county=payload.county,
        ward=payload.ward,
        urgency=payload.urgency,
        status="Open",
        deadline_time=deadline # 🔥 SAVES DEADLINE
    )
    
    db.add(new_contract)
    db.commit()
    db.refresh(new_contract)
    
    return {"message": "Contract broadcasted to the network!", "contract_id": new_contract.id}

@app.put("/pledges/{pledge_id}/complete", response_model=schemas.PledgeRead)
def complete_pledge_delivery(
    pledge_id: int, 
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(get_current_user)
):
    pledge = db.query(models.Pledge).filter(models.Pledge.id == pledge_id).first()
    if not pledge:
        raise HTTPException(status_code=404, detail="Pledge not found")

    if current_user.role != "buyer":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Security Error: Only the Corporate Buyer can verify quality and release Escrow funds."
        )

    if pledge.status != "received_at_hub":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot complete order. Current status is '{pledge.status}', but it must be 'received_at_hub' first."
        )

    pledge.status = "completed"
    db.commit()
    db.refresh(pledge)
    
    return pledge

@app.post("/bulk-requests/", response_model=schemas.BulkRequestRead)
def create_bulk_request(
    request: BulkRequestCreate, 
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(get_current_user)
):
    if current_user.role != "buyer":
        raise HTTPException(status_code=403, detail="Only Corporate Buyers can post bulk requests.")

    deadline = datetime.utcnow() + timedelta(hours=request.deadline_hours)

    new_request = models.BulkRequest(
        buyer_id=current_user.id,
        buyer_name=current_user.full_name, 
        crop_name=request.crop_name,
        target_weight_kg=request.target_weight_kg,
        price_per_kg=request.price_per_kg,
        county=request.county, 
        urgency=request.urgency,
        status="Open",
        squad_status="gathering",
        deadline_time=deadline, 
        payment_method="pay_on_delivery" 
    )
    
    try:
        db.add(new_request)
        db.commit()
        db.refresh(new_request)
        return new_request
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to broadcast contract to the network.")

@app.get("/bulk-requests/")
def get_active_bulk_requests(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    requests = db.query(models.BulkRequest).filter(
        models.BulkRequest.status.in_(["Open", "fulfilled"]),
        ~models.BulkRequest.buyer_name.like("Hub Pool:%") 
    ).all()

    results = []
    for req in requests:
        has_pledged = any(p.farmer_id == current_user.id for p in req.pledges)
        total_pledged = sum((p.pledged_weight_kg or 0) for p in req.pledges) 
        
        results.append({
            "id": req.id, "crop_name": req.crop_name, "target_weight_kg": req.target_weight_kg,
            "total_pledged": total_pledged, "price_per_kg": req.price_per_kg,
            "buyer_name": req.buyer_name, "county": req.county,
            "ward": req.ward, "urgency": req.urgency, 
            "deadline_time": req.deadline_time.isoformat() + "Z" if getattr(req, 'deadline_time', None) else None, 
            "has_pledged": has_pledged 
        })
    return results


@app.get("/harvests/me")
def get_my_market_listings(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    listings = db.query(models.MarketListing).filter(
        models.MarketListing.farmer_id == current_user.id,
        models.MarketListing.status == "active"
    ).order_by(models.MarketListing.created_at.desc()).all()
    
    results = []
    for listing in listings:
        orders_query = db.query(models.MarketOrder).filter(
            models.MarketOrder.listing_id == listing.id, 
            models.MarketOrder.status == "pending"
        ).all()
        
        orders_list = [{
            "id": o.id, "buyer_name": o.buyer.full_name if o.buyer else "Local Buyer",
            "quantity": o.quantity_ordered, "type": o.order_type,
            "total_price": o.total_price, "status": o.status
        } for o in orders_query]

        parsed_units = []
        if listing.unit_pricing:
            if isinstance(listing.unit_pricing, str):
                try: parsed_units = json.loads(listing.unit_pricing)
                except: 
                    try: parsed_units = json.loads(listing.unit_pricing.replace("'", '"'))
                    except: pass
            elif isinstance(listing.unit_pricing, list):
                parsed_units = listing.unit_pricing

        display_price = listing.price_per_kg
        display_unit = "KG"
        if not listing.is_selling_by_weight and parsed_units and len(parsed_units) > 0:
            display_price = parsed_units[0].get("price", 0)
            display_unit = parsed_units[0].get("unit_name", "Unit")

        results.append({
            "id": listing.id, "crop_name": listing.crop_name,
            "available_kg": listing.available_kg, "price_per_kg": display_price, 
            "unit_type": display_unit, "is_selling_by_weight": listing.is_selling_by_weight,
            "unit_pricing": parsed_units, 
            "image_base64": getattr(listing, 'image_base64', None), 
            "orders": orders_list, "orders_count": len(orders_list)
        })
    return results

@app.post("/bulk-requests/{request_id}/pledge", response_model=schemas.PledgeRead)
def create_pledge(
    request_id: int, 
    pledge: schemas.PledgeBase, 
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(get_current_user)
):
    if current_user.role != "farmer":
        raise HTTPException(status_code=403, detail="Only farmers can pledge.")

    bulk_req = db.query(models.BulkRequest).filter(models.BulkRequest.id == request_id).first()
    if not bulk_req:
        raise HTTPException(status_code=404, detail="Bulk request not found.")

    existing_pledge = db.query(models.Pledge).filter(
        models.Pledge.bulk_request_id == request_id,
        models.Pledge.farmer_id == current_user.id
    ).first()
    
    if existing_pledge:
        raise HTTPException(status_code=400, detail="You have already pledged to this request.")

    current_total = db.query(func.sum(models.Pledge.pledged_weight_kg)).filter(models.Pledge.bulk_request_id == request_id).scalar() or 0.0

    if current_total >= bulk_req.target_weight_kg:
        raise HTTPException(status_code=400, detail="This Hub Pool is already 100% full!")

    if current_total + pledge.pledged_weight_kg > bulk_req.target_weight_kg:
        remaining = bulk_req.target_weight_kg - current_total
        raise HTTPException(status_code=400, detail=f"Cannot over-pledge. Only {remaining}kg remaining to fill the pool.")

    new_pledge = models.Pledge(
        bulk_request_id=request_id,
        farmer_id=current_user.id,
        pledged_weight_kg=pledge.pledged_weight_kg,
        status="pledged"
    )
    
    try:
        db.add(new_pledge)
        db.flush() 

        total_pledged = db.query(func.sum(models.Pledge.pledged_weight_kg)).filter(models.Pledge.bulk_request_id == request_id).scalar() or 0.0
        
        if total_pledged >= bulk_req.target_weight_kg:
            bulk_req.status = "fulfilled" 
            
            if bulk_req.buyer_name.startswith("Hub Pool:"):
                bulk_req.squad_status = "active"
            else:
                unique_farmers = db.query(models.Pledge.farmer_id).filter(models.Pledge.bulk_request_id == request_id).distinct().count()
                if unique_farmers == 1:
                    bulk_req.coordinator_id = current_user.id
                    bulk_req.squad_status = "active"
                else:
                    bulk_req.squad_status = "voting"

        db.commit()
        db.refresh(new_pledge)
        return new_pledge
        
    except Exception as e:
        db.rollback()
        print(f"DB Error during pledge creation: {e}")
        raise HTTPException(status_code=500, detail="Failed to process your pledge.")


@app.post("/api/squads/{squad_id}/run")
def run_for_squad_coordinator(squad_id: int, payload: SquadPitch, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    squad = db.query(models.BulkRequest).filter(models.BulkRequest.id == squad_id).first()
    if not squad:
        raise HTTPException(status_code=404, detail="Squad not found")
        
    existing = db.query(models.SquadCandidate).filter(
        models.SquadCandidate.bulk_request_id == squad_id, 
        models.SquadCandidate.farmer_id == current_user.id
    ).first()
    
    if existing:
        raise HTTPException(status_code=400, detail="You are already on the ballot!")
        
    new_candidate = models.SquadCandidate(
        bulk_request_id=squad_id,
        farmer_id=current_user.id,
        pitch=payload.pitch
    )
    db.add(new_candidate)
    db.commit()
    return {"message": "You are officially on the ballot!"}


@app.post("/api/squads/{squad_id}/vote")
def cast_squad_vote(squad_id: int, payload: SquadVoteRequest, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    existing_vote = db.query(models.SquadVote).filter(
        models.SquadVote.bulk_request_id == squad_id, 
        models.SquadVote.farmer_id == current_user.id
    ).first()
    
    if existing_vote:
        raise HTTPException(status_code=400, detail="You have already cast your vote for this squad.")
        
    new_vote = models.SquadVote(
        bulk_request_id=squad_id,
        candidate_id=payload.candidate_id,
        farmer_id=current_user.id
    )
    db.add(new_vote)
    
    candidate = db.query(models.SquadCandidate).filter(models.SquadCandidate.id == payload.candidate_id).first()
    if candidate:
        candidate.votes = (candidate.votes or 0) + 1
        
        total_members = db.query(models.Pledge).filter(models.Pledge.bulk_request_id == squad_id).count()
        majority_threshold = (total_members / 2) if total_members > 2 else 0

        if candidate.votes > majority_threshold:
            squad = db.query(models.BulkRequest).filter(models.BulkRequest.id == squad_id).first()
            squad.coordinator_id = candidate.farmer_id
            squad.squad_status = "active" 
    
    db.commit()
    return {"message": "Vote cast successfully!"}

load_dotenv()
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))

class AIChatRequest(BaseModel):
    message: str
    role: Optional[str] = "farmer"
    user_name: Optional[str] = "Farmer"
    location: Optional[str] = "Kenya"
    business_details: Optional[str] = ""

@app.post("/api/ai-chat")
def ask_ai_chat(request: AIChatRequest):
    try:
        system_instruction = f"""
        You are the MkulimaHub AI Assistant, an expert in Kenyan agriculture and market dynamics.
        You are talking to {request.user_name}, who is a {request.role} located in {request.location}.
        Business Context: {request.business_details}
        
        Always be helpful, encouraging, and concise. If they ask about crop prices, trends, weather, 
        or diseases, YOU MUST USE YOUR TOOLS to fetch live data from the database before answering.
        """

        model = genai.GenerativeModel(
            model_name='gemini-2.5-flash',
            tools=[get_market_spot_price, predict_price_trend, get_weather_forecast, diagnose_crop_disease],
            system_instruction=system_instruction
        )

        chat = model.start_chat(enable_automatic_function_calling=True)
        response = chat.send_message(request.message)

        return {"reply": response.text}

    except Exception as e:
        print(f"AI Chat Error: {e}")
        raise HTTPException(status_code=500, detail="The AI is currently resting. Please try again in a moment!")
    
@app.get("/api/squads/{bulk_request_id}/messages")
def get_squad_messages(bulk_request_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    messages = db.query(models.SquadMessage)\
                 .filter(models.SquadMessage.bulk_request_id == bulk_request_id)\
                 .order_by(models.SquadMessage.created_at.asc())\
                 .all()

    chat_history = []
    for msg in messages:
        chat_history.append({
            "id": msg.id,
            "sender_id": msg.sender_id,
            "sender_name": msg.sender.full_name if msg.sender else "Unknown Farmer",
            "message": msg.message,
            "is_me": msg.sender_id == current_user.id, 
            "created_at": msg.created_at.isoformat()
        })
        
    return chat_history


@app.post("/api/squads/{bulk_request_id}/messages")
def send_squad_message(bulk_request_id: int, payload: MessageCreate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    contract = db.query(models.BulkRequest).filter(models.BulkRequest.id == bulk_request_id).first()
    if not contract:
        raise HTTPException(status_code=404, detail="Contract not found.")

    new_message = models.SquadMessage(
        bulk_request_id=bulk_request_id,
        sender_id=current_user.id,
        message=payload.message
    )
    
    db.add(new_message)
    db.commit()
    
    return {"status": "success", "message": "Message sent!"}

@app.get("/api/buyer/marketplace")
def get_hub_marketplace(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if current_user.role != "buyer":
        raise HTTPException(status_code=403, detail="Only buyers can browse the enterprise marketplace.")

    hub_pools = db.query(models.BulkRequest).filter(
        models.BulkRequest.buyer_name.like("Hub Pool:%")
    ).all()

    available_inventory = []
    
    for pool in hub_pools:
        total_pledged = db.query(func.sum(models.Pledge.pledged_weight_kg)).filter(models.Pledge.bulk_request_id == pool.id).scalar() or 0.0
        
        if total_pledged < pool.target_weight_kg:
            continue
            
        hub_name_clean = pool.buyer_name.replace("Hub Pool: ", "")

        available_inventory.append({
            "pool_id": pool.id,
            "hub_name": hub_name_clean,
            "crop": pool.crop_name,
            "available_weight_kg": total_pledged,
            "asking_price_per_kg": pool.price_per_kg,
            "total_value_kes": total_pledged * pool.price_per_kg,
            "status": "Ready for Pickup" 
        })

    return available_inventory

class UnattendedDropoffPayload(BaseModel):
    scale_photo_url: str
    crop_photo_url: str

@app.post("/api/squads/{squad_id}/unattended-dropoff")
def unattended_dropoff(
    squad_id: int, 
    payload: UnattendedDropoffPayload, 
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(get_current_user)
):
    squad = db.query(models.BulkRequest).filter(models.BulkRequest.id == squad_id).first()
    if not squad:
        raise HTTPException(status_code=404, detail="Squad not found.")

    my_pledge = db.query(models.Pledge).filter(
        models.Pledge.bulk_request_id == squad_id,
        models.Pledge.farmer_id == current_user.id
    ).first()
    
    if not my_pledge:
        raise HTTPException(status_code=404, detail="You do not have a pledge in this squad.")
        
    my_pledge.status = "pending_audit"
    my_pledge.notes = f"EVIDENCE_LOG|{payload.scale_photo_url}|{payload.crop_photo_url}"
    
    db.commit()
    return {"message": "Drop-off submitted for Audit!"}

@app.post("/api/squads/{squad_id}/status")
def update_squad_status(squad_id: int, payload: SquadStatusUpdate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    squad = db.query(models.BulkRequest).filter(models.BulkRequest.id == squad_id).first()
    if not squad or squad.coordinator_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the driver can update the physical status.")
    
    pledges = db.query(models.Pledge).filter(models.Pledge.bulk_request_id == squad_id).all()
    for pledge in pledges:
        pledge.status = payload.status 
        
    db.commit()
    return {"message": f"Squad successfully moved to {payload.status}"}

@app.put("/api/pledges/{pledge_id}/status")
def update_individual_pledge_status(pledge_id: int, payload: SquadStatusUpdate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    pledge = db.query(models.Pledge).filter(models.Pledge.id == pledge_id).first()
    if not pledge:
        raise HTTPException(status_code=404, detail="Pledge not found.")
        
    contract = db.query(models.BulkRequest).filter(models.BulkRequest.id == pledge.bulk_request_id).first()
    
    is_coordinator = (contract.coordinator_id == current_user.id)
    is_hub_admin = False
    
    if contract.buyer_name.startswith("Hub Pool:"):
        hub_name = contract.buyer_name.replace("Hub Pool: ", "").strip()
        hub = db.query(models.Hub).filter(models.Hub.name == hub_name).first()
        if hub and hub.coordinator_id == current_user.id:
            is_hub_admin = True
            
    is_owner_handing_over = (pledge.farmer_id == current_user.id and payload.status == "pending_audit")
    
    if not (is_hub_admin or is_coordinator or is_owner_handing_over):
        raise HTTPException(status_code=403, detail="Not authorized to update this drop-off.")
        
    pledge.status = payload.status
    db.commit()
    return {"message": "Drop-off Verified!"}

class MarketListingCreate(BaseModel):
    crop_name: str
    base_inventory_kg: float
    is_selling_by_weight: bool
    price_per_kg: Optional[float] = None
    unit_pricing: List[Dict[str, Any]] = [] 
    image_base64: Optional[str] = None

@app.post("/api/market/listings")
def create_market_listing(payload: MarketListingCreate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    new_listing = models.MarketListing(
        farmer_id=current_user.id,
        crop_name=payload.crop_name,
        base_inventory_kg=payload.base_inventory_kg,
        available_kg=payload.base_inventory_kg,
        is_selling_by_weight=payload.is_selling_by_weight,
        price_per_kg=payload.price_per_kg,
        unit_pricing=json.dumps(payload.unit_pricing) if payload.unit_pricing else "[]",
        image_base64=payload.image_base64 
    )
    db.add(new_listing)
    db.commit()
    return {"message": "Listing published to marketplace!"}

class MarketOrderCreate(BaseModel):
    order_type: str
    quantity: float
    delivery_method: str = "Delivery"
    payment_method: str = "pay_now"

@app.post("/api/market/listings/{listing_id}/order")
def create_market_order(
    listing_id: int, 
    payload: MarketOrderCreate, 
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(get_current_user)
):
    listing = db.query(models.MarketListing).filter(models.MarketListing.id == listing_id).first()
    
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")
        
    if listing.available_kg is not None and listing.available_kg <= 0:
        raise HTTPException(status_code=400, detail="This listing is sold out")

    parsed_units = []
    if listing.unit_pricing:
        if isinstance(listing.unit_pricing, str):
            try:
                parsed_units = json.loads(listing.unit_pricing)
            except Exception:
                try:
                    parsed_units = json.loads(listing.unit_pricing.replace("'", '"'))
                except Exception:
                    pass
        elif isinstance(listing.unit_pricing, list):
            parsed_units = listing.unit_pricing

    total_kg_ordered = 0
    subtotal = 0.0
    
    if payload.order_type == "KG":
        total_kg_ordered = payload.quantity
        subtotal = payload.quantity * listing.price_per_kg
    else:
        selected_unit = next((u for u in parsed_units if u.get("unit_name") == payload.order_type), None)
        
        if not selected_unit:
            raise HTTPException(status_code=400, detail=f"Unit '{payload.order_type}' not available.")
            
        unit_kg = selected_unit.get("kg", 0)
        unit_price = selected_unit.get("price", 0)
        
        total_kg_ordered = payload.quantity * unit_kg
        subtotal = payload.quantity * unit_price

    if listing.available_kg is not None and total_kg_ordered > listing.available_kg:
        raise HTTPException(status_code=400, detail=f"Only {listing.available_kg} KG available. You ordered {total_kg_ordered} KG.")

    service_fee = subtotal * 0.02
    
    delivery_fee = 0.0
    if "Delivery|" in payload.delivery_method:
        try:
            buyer_county = payload.delivery_method.split("|")[1].split(",")[0].strip().lower()
            farmer_county = listing.farmer.county.lower() if listing.farmer and listing.farmer.county else "nairobi"
            
            far_counties = ['mandera', 'wajir', 'garissa', 'turkana', 'marsabit', 'samburu', 'isiolo', 'lamu', 'tana river']
            
            if farmer_county == buyer_county:
                delivery_fee = 500.0
            elif buyer_county in far_counties or farmer_county in far_counties:
                delivery_fee = 3500.0
            else:
                delivery_fee = 1500.0
        except Exception:
            delivery_fee = 1500.0 # Fallback safety
            
    taxable_amount = service_fee + delivery_fee
    tax_amount = taxable_amount * 0.16
    
    final_total = subtotal + service_fee + delivery_fee + tax_amount

    new_order = models.MarketOrder(
        listing_id=listing.id,
        buyer_id=current_user.id,
        quantity_ordered=payload.quantity,
        order_type=payload.order_type,
        subtotal=subtotal,
        service_fee=service_fee,
        delivery_fee=delivery_fee,
        tax_amount=tax_amount,
        total_price=final_total,
        status="pending",
        delivery_method=payload.delivery_method,
        payment_method=payload.payment_method 
    )
    
    db.add(new_order)
    db.commit()
    return {"message": "Order placed successfully!"}

class PoolPurchasePayload(BaseModel):
    county: str
    ward: str
    payment_method: Optional[str] = "pay_now"

@app.post("/api/market/pools/{pool_id}/purchase")
def purchase_hub_pool(pool_id: int, payload: PoolPurchasePayload, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    pool = db.query(models.BulkRequest).filter(models.BulkRequest.id == pool_id).first()
    
    if not pool:
        raise HTTPException(status_code=404, detail="Hub Pool not found.")
        
    if pool.buyer_id == current_user.id:
        if hasattr(payload, 'payment_method'):
            pool.payment_method = payload.payment_method
        db.commit()
        return {"message": "Hub Pool checkout details refreshed!"}
        
    if pool.buyer_id is not None:
        raise HTTPException(status_code=400, detail="This pool has already been secured by another buyer.")
        
    pool.buyer_id = current_user.id
   
    
    pool.county = payload.county
    pool.ward = payload.ward 
    
    pool.status = "pending"
    pool.payment_method = getattr(payload, 'payment_method', 'pay_now')
    
    db.commit()
    return {"message": "Hub Pool routed successfully! Awaiting payment or POD confirmation."}

@app.get("/api/market/listings")
def get_all_market_listings(db: Session = Depends(get_db)):
    listings = db.query(models.MarketListing).all()
    results = []
    
    for listing in listings:
        if listing.available_kg is not None and listing.available_kg <= 0:
            continue

        parsed_units = []
        if listing.unit_pricing:
            if isinstance(listing.unit_pricing, str):
                try: parsed_units = json.loads(listing.unit_pricing)
                except: 
                    try: parsed_units = json.loads(listing.unit_pricing.replace("'", '"'))
                    except: pass
            elif isinstance(listing.unit_pricing, list):
                parsed_units = listing.unit_pricing

        display_price = listing.price_per_kg
        display_unit = "KG"
        if not listing.is_selling_by_weight and parsed_units and len(parsed_units) > 0:
            display_price = parsed_units[0].get("price", 0)
            display_unit = parsed_units[0].get("unit_name", "Unit")
            
        results.append({
            "id": listing.id, "crop_name": listing.crop_name,
            "available_kg": listing.available_kg if listing.available_kg is not None else getattr(listing, 'weight_kg', 0),
            "price_per_kg": display_price, "unit_type": display_unit,
            "is_selling_by_weight": listing.is_selling_by_weight,
            "unit_pricing": parsed_units,
            "image_base64": getattr(listing, 'image_base64', None),
            "farmer_name": listing.farmer.full_name if listing.farmer else "Local Farmer",
            "county": listing.farmer.county if listing.farmer else "Kenya"
        })
    return results

@app.put("/api/squads/{squad_id}/delegate")
def delegate_coordinator(squad_id: int, new_coordinator_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    squad = db.query(models.BulkRequest).filter(models.BulkRequest.id == squad_id).first()
    if squad.coordinator_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the current coordinator can delegate.")
    
    is_member = db.query(models.Pledge).filter(models.Pledge.bulk_request_id == squad_id, models.Pledge.farmer_id == new_coordinator_id).first()
    if not is_member:
        raise HTTPException(status_code=400, detail="New coordinator must be a member of the squad.")
        
    squad.coordinator_id = new_coordinator_id
    db.commit()
    return {"message": "Leadership successfully delegated!"}

class ReceiveLineItemPayload(BaseModel):
    actual_weight_kg: float
    notes: Optional[str] = None

@app.put("/api/pledges/{pledge_id}/receive-line-item")
def receive_individual_pledge(pledge_id: int, payload: ReceiveLineItemPayload, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    pledge = db.query(models.Pledge).filter(models.Pledge.id == pledge_id).first()
    if not pledge:
        raise HTTPException(status_code=404, detail="Pledge not found.")
        
    contract = db.query(models.BulkRequest).filter(models.BulkRequest.id == pledge.bulk_request_id).first()
    
    is_coordinator = (contract.coordinator_id == current_user.id)
    is_hub_admin = False
    
    if contract.buyer_name.startswith("Hub Pool:"):
        hub_name = contract.buyer_name.replace("Hub Pool: ", "").strip()
        hub = db.query(models.Hub).filter(models.Hub.name == hub_name).first()
        if hub and hub.coordinator_id == current_user.id:
            is_hub_admin = True
            
    if not (is_coordinator or is_hub_admin):
        raise HTTPException(status_code=403, detail="Only the Coordinator or Hub Admin can verify and receive goods.")
    
    original_kg = pledge.pledged_weight_kg
    actual_kg = payload.actual_weight_kg

    if actual_kg < original_kg:
        difference_kg = original_kg - actual_kg
        refund_amount = 0.0
        
        if getattr(contract, 'payment_status', '') == 'deposit_paid':
            refund_amount = (difference_kg * contract.price_per_kg) * 0.10
        elif getattr(contract, 'payment_status', '') == 'fully_paid_escrow':
            refund_amount = (difference_kg * contract.price_per_kg) * 1.0

        if refund_amount > 0:
            farmer = db.query(models.User).filter(models.User.id == pledge.farmer_id).first()
            buyer = db.query(models.User).filter(models.User.id == contract.buyer_id).first()

            if farmer and (farmer.escrow_balance or 0.0) >= refund_amount:
                farmer.escrow_balance -= refund_amount
                if buyer:
                    buyer.available_balance = (buyer.available_balance or 0.0) + refund_amount

    pledge.status = "received"
    pledge.actual_weight_kg = actual_kg
    pledge.notes = payload.notes
    
    db.commit()
    return {"message": "Farmer's produce received & Escrow Rebalanced!"}

class MarketListingUpdate(BaseModel):
    available_kg: float
    price_per_kg: Optional[float] = None
    unit_pricing: List[Dict[str, Any]] = []

@app.put("/api/market/listings/{listing_id}")
def update_market_listing(
    listing_id: int, 
    payload: MarketListingUpdate, 
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(get_current_user)
):
    listing = db.query(models.MarketListing).filter(
        models.MarketListing.id == listing_id, 
        models.MarketListing.farmer_id == current_user.id
    ).first()
    
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found.")
    
    listing.available_kg = payload.available_kg
    if payload.price_per_kg is not None:
        listing.price_per_kg = payload.price_per_kg
        
    listing.unit_pricing = json.dumps(payload.unit_pricing) if payload.unit_pricing else "[]"
    
    db.commit()
    return {"message": "Listing updated successfully!"}

@app.delete("/api/market/listings/{listing_id}")
def delete_market_listing(
    listing_id: int, 
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(get_current_user)
):
    listing = db.query(models.MarketListing).filter(
        models.MarketListing.id == listing_id, 
        models.MarketListing.farmer_id == current_user.id
    ).first()
    
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found.")
        
    db.delete(listing)
    db.commit()
    return {"message": "Listing deleted."}

@app.put("/api/farmer/orders/{order_id}/status")
def update_direct_order_status(order_id: int, payload: dict, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    order = db.query(models.MarketOrder).filter(models.MarketOrder.id == order_id).first()
    if not order: raise HTTPException(status_code=404, detail="Order not found")
    
    new_status = payload.get("status")

    if new_status == "refunded" and getattr(order, 'payment_method', 'pay_now') == "pay_now" and order.status != "refunded":
        buyer = db.query(models.User).filter(models.User.id == order.buyer_id).first()
        if buyer and (buyer.escrow_balance or 0.0) >= order.total_price:
            buyer.escrow_balance -= order.total_price
            buyer.available_balance = (buyer.available_balance or 0.0) + order.total_price
    
    if payload.get("dispute_notes"):
        order.dispute_notes = payload.get("dispute_notes")
        
    order.status = new_status
    db.commit()
    return {"message": f"Order status successfully updated to {order.status}"}

@app.post("/api/admin/fix-orphans")
def fix_orphaned_farmers(db: Session = Depends(get_db)):
    valid_hubs = db.query(models.Hub.id).all()
    valid_hub_ids = [h[0] for h in valid_hubs]
    
    if not valid_hub_ids:
        orphans = db.query(models.User).filter(models.User.hub_id.isnot(None)).all()
    else:
        orphans = db.query(models.User).filter(
            models.User.hub_id.isnot(None), 
            ~models.User.hub_id.in_(valid_hub_ids)
        ).all()
        
    count = 0
    for farmer in orphans:
        farmer.hub_id = None
        count += 1
        
    db.commit()
    return {"message": f"Successfully rescued {count} farmers from ghost hubs! They are now independent."}

@app.get("/api/buyer/insights")
def get_buyer_insights(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if current_user.role != "buyer":
        raise HTTPException(status_code=403, detail="Unauthorized")

    listings = db.query(models.MarketListing).filter(
        models.MarketListing.available_kg > 0,
        models.MarketListing.status == "active"
    ).all()

    total_hubs = db.query(models.Hub).count()
    total_farmers = db.query(models.User).filter(models.User.role == "farmer").count()
    total_tonnage = sum(l.available_kg for l in listings)

    metrics = {
        "active_hubs": total_hubs,
        "network_farmers": total_farmers,
        "total_tonnage": f"{total_tonnage:,.0f} KG"
    }

    crop_stats = {}
    for l in listings:
        if l.crop_name not in crop_stats:
            crop_stats[l.crop_name] = {"total_price": 0, "count": 0, "total_kg": 0}
        crop_stats[l.crop_name]["total_price"] += l.price_per_kg
        crop_stats[l.crop_name]["count"] += 1
        crop_stats[l.crop_name]["total_kg"] += l.available_kg

    trends = []
    for crop, stats in crop_stats.items():
        avg_price = stats["total_price"] / stats["count"]
        trends.append({
            "crop": crop.capitalize(),
            "price": f"KES {avg_price:.0f}/kg",
            "change": f"+{random.uniform(0.5, 3.5):.1f}%", 
            "isUp": True
        })

    county_stats = {}
    for l in listings:
        county = l.farmer.county if l.farmer and l.farmer.county else "Unknown Region"
        if county not in county_stats: county_stats[county] = {}
        if l.crop_name not in county_stats[county]: county_stats[county][l.crop_name] = 0
        county_stats[county][l.crop_name] += l.available_kg

    hotspots = []
    color_map = [0, 1, 2, 3] 
    color_idx = 0
    for county, crops in county_stats.items():
        top_crop = max(crops, key=crops.get)
        total_vol = crops[top_crop]
        hotspots.append({
            "county": county, "crop": top_crop.capitalize(),
            "volume": f"{total_vol:.0f} KG Avail.", "raw_vol": total_vol,
            "color_index": color_map[color_idx % len(color_map)]
        })
        color_idx += 1
    hotspots = sorted(hotspots, key=lambda x: x["raw_vol"], reverse=True)

    alerts = []
    if not hotspots:
        alerts.append({
            "title": "Market is Quiet 📉", 
            "desc": "Supply is low right now. Broadcast a Bulk Contract to wake up the Co-op network and secure your supply early!", 
            "type": "info"
        })
    else:
        top_spot = hotspots[0]
        alerts.append({
            "title": "Supply Surge Detected 🚨", 
            "desc": f"High volume of {top_spot['crop']} is sitting in {top_spot['county']}. Negotiate a bulk discount directly with the Hub now.", 
            "type": "opportunity"
        })

    cached_preds = db.query(models.CachedPrediction).limit(3).all()
    forecasts = []
    for c in cached_preds:
        if c.payload:
            forecasts.append({
                "crop": c.cache_key.split('_')[0].capitalize(),
                "trend": c.payload.get("trend", "stable").capitalize(),
                "predicted_price": f"KES {c.payload.get('predicted_price', 0):.0f}"
            })

    return {
        "metrics": metrics,
        "trends": trends[:6],
        "hotspots": hotspots[:5],
        "alerts": alerts,
        "forecasts": forecasts
    }

@app.get("/api/farmer/dashboard")
def get_farmer_dashboard(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    harvests = db.query(models.Harvest).filter(models.Harvest.farmer_id == current_user.id).all()
    total_yield = sum([h.weight_kg for h in harvests])

    orders = db.query(models.MarketOrder).join(models.MarketListing).filter(
        models.MarketListing.farmer_id == current_user.id,
        models.MarketOrder.status.in_(["pending", "processing", "in_transit", "disputed"])
    ).all()
    
    deliveries_list = []
    for o in orders:
        deliveries_list.append({
            "type": "solo",
            "id": o.id,
            "crop_name": o.listing.crop_name if o.listing else "Produce",
            "weight_kg": o.quantity_ordered,
            "status": o.status
        })
        
    return {
        "total_yield_kg": round(total_yield, 2),
        "deliveries_list": deliveries_list
    }


@app.post("/api/dev/pay-now/{order_id}")
def simulate_mpesa_payment(order_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    order = db.query(models.MarketOrder).filter(models.MarketOrder.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    listing = db.query(models.MarketListing).filter(models.MarketListing.id == order.listing_id).first()
    farmer = db.query(models.User).filter(models.User.id == listing.farmer_id).first()

    if farmer:
        farmer.escrow_balance = (farmer.escrow_balance or 0.0) + order.total_price

    order.status = "in_transit"

    db.commit()
    return {"message": "M-Pesa payment successful. Funds secured in Escrow."}

@app.post("/api/market/pools/{contract_id}/pay/mpesa")
def trigger_bulk_mpesa_payment(contract_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    contract = db.query(models.BulkContract).filter(models.BulkContract.id == contract_id).first()
    
    if not contract:
        raise HTTPException(status_code=404, detail="Contract not found")
        
    if not current_user.phone_number:
        raise HTTPException(status_code=400, detail="Please add an M-Pesa phone number in your profile settings.")

    is_sandbox = os.getenv("MPESA_ENVIRONMENT", "sandbox").lower() == "sandbox"
    actual_amount_to_charge = 1 if is_sandbox else contract.original_price

    try:
        mpesa = MpesaClient()
        response = mpesa.trigger_stk_push(
            phone_number=current_user.phone_number,
            amount=actual_amount_to_charge, 
            order_id=f"BULK-{contract.id}"
        )
        
        if response and "CheckoutRequestID" in response:
            contract.checkout_request_id = response["CheckoutRequestID"]
            db.commit()
            return {"message": "STK Push sent successfully!"}
        else:
            raise HTTPException(status_code=400, detail="M-Pesa push failed. Check Daraja credentials.")
            
    except Exception as e:
        print(f"M-Pesa Trigger Error: {e}")
        raise HTTPException(status_code=500, detail="Failed to communicate with Safaricom.")

@app.get("/api/farmer/wallet")
def get_farmer_wallet(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    available = current_user.available_balance or 0.0
    escrow = current_user.escrow_balance or 0.0
    
    return {
        "available_balance": available,
        "escrow_balance": escrow,
        "total_balance": available + escrow
    }

@app.post("/api/buyer/orders/{order_id}/pay/mpesa")
def initiate_mpesa_payment(order_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    order = db.query(models.MarketOrder).filter(models.MarketOrder.id == order_id, models.MarketOrder.buyer_id == current_user.id).first()
    
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
        
    if not current_user.phone_number:
        raise HTTPException(status_code=400, detail="Please add a phone number to your profile first.")

    is_sandbox = os.getenv("MPESA_ENVIRONMENT") == "sandbox"
    
    actual_amount_to_charge = 1 if is_sandbox else order.total_price

    mpesa = MpesaClient()
    response = mpesa.trigger_stk_push(
        phone_number=current_user.phone_number,
        amount=actual_amount_to_charge, 
        order_id=str(order.id)
    )

    if response.get("success"):
        order.checkout_request_id = response["checkout_id"]
        db.commit()
        return {"message": "STK Push sent! Please check your phone to enter your PIN.", "checkout_id": response["checkout_id"]}
    else:
        raise HTTPException(status_code=400, detail=response.get("error", "Payment failed to initiate."))
    
@app.post("/api/payments/webhook/stk")
async def mpesa_stk_webhook(request: Request):
    payload = await request.json()
    print(f"💰 M-PESA DARAJA WEBHOOK PING: {payload}")

    callback = payload.get("Body", {}).get("stkCallback", {})
    result_code = callback.get("ResultCode")
    checkout_id = callback.get("CheckoutRequestID")

    db = SessionLocal()
    try:
       
        order = db.query(models.MarketOrder).filter(models.MarketOrder.checkout_request_id == checkout_id).first()
        if order:
            if result_code == 0:
                print(f"✅ Payment successful for Solo Order {order.id}!")
                listing = db.query(models.MarketListing).filter(models.MarketListing.id == order.listing_id).first()
                farmer = db.query(models.User).filter(models.User.id == listing.farmer_id).first() if listing else None

                if farmer:
                    payment_method = getattr(order, 'payment_method', 'pay_now')
                    
                    
                    farmer_payout = order.subtotal

                    if payment_method == 'pay_on_delivery':
                        farmer.available_balance = (farmer.available_balance or 0.0) + farmer_payout
                        order.status = "completed"
                    else:
                        farmer.escrow_balance = (farmer.escrow_balance or 0.0) + farmer_payout
                        order.status = "processing"
                
                order.checkout_request_id = None 
                db.commit()
            else:
                print(f"❌ Payment failed for Solo Order {order.id}")
            return {"ResultCode": 0, "ResultDesc": "Accepted"}

      
        pool = db.query(models.BulkRequest).filter(models.BulkRequest.checkout_request_id == checkout_id).first()
        if pool:
            if result_code == 0:
                if pool.payment_status == 'pending':
                    # Auto-heal: Ensure Standard Contracts are always Pay On Delivery (10% upfront)
                    is_hub_pool = pool.buyer_name and pool.buyer_name.startswith("Hub Pool:")
                    if not is_hub_pool and getattr(pool, 'payment_method', 'pay_now') != "pay_on_delivery":
                        pool.payment_method = "pay_on_delivery"

                    payment_method = getattr(pool, 'payment_method', 'pay_now')
                    
                    if payment_method == 'pay_now':
                        print(f"100% Upfront Paid for Hub Pool {pool.id}!")
                        pool.payment_status = "fully_paid_escrow"
                        lock_percentage = 1.0 
                    else:
                        print(f"10% Deposit Paid for Contract {pool.id}!")
                        pool.payment_status = "deposit_paid"
                        lock_percentage = 0.10 
                    
                    pledges = db.query(models.Pledge).filter(models.Pledge.bulk_request_id == pool.id).all()
                    for p in pledges:
                        f = db.query(models.User).filter(models.User.id == p.farmer_id).first()
                        if f:
                            deposit_cut = (p.pledged_weight_kg * pool.price_per_kg) * lock_percentage
                            f.escrow_balance = (f.escrow_balance or 0.0) + deposit_cut
                            
                    pool.status = "active" 
                    pool.checkout_request_id = None
                    
                elif pool.payment_status == 'deposit_paid':
                    print(f"90% Balance Paid for Contract {pool.id}!")
                    pool.payment_status = "fully_paid"
                    pool.status = "completed"

                    pledges = db.query(models.Pledge).filter(
                        models.Pledge.bulk_request_id == pool.id, 
                        models.Pledge.status.in_(['received', 'pending_audit', 'delivered'])
                    ).all()

                    for p in pledges:
                        f = db.query(models.User).filter(models.User.id == p.farmer_id).first()
                        actual_kg = p.actual_weight_kg if p.actual_weight_kg else p.pledged_weight_kg
                        total_value = actual_kg * pool.price_per_kg
                        
                        deposit_held = total_value * 0.10
                        pod_paid = total_value * 0.90
                        
                        coordinator_commission = total_value * 0.01
                        farmer_net_pod = pod_paid - coordinator_commission

                        if f:
                            if (f.escrow_balance or 0.0) >= deposit_held:
                                f.escrow_balance -= deposit_held
                            f.available_balance = (f.available_balance or 0.0) + deposit_held + farmer_net_pod
                            
                            if pool.coordinator_id:
                                coord = db.query(models.User).filter(models.User.id == pool.coordinator_id).first()
                                if coord:
                                    coord.available_balance = (coord.available_balance or 0.0) + coordinator_commission

                        p.status = "paid"
                    pool.checkout_request_id = None 
                    
                db.commit()
            else:
                print(f"❌ Payment failed for Contract {pool.id}")
            return {"ResultCode": 0, "ResultDesc": "Accepted"}

        pledge = db.query(models.Pledge).filter(models.Pledge.checkout_request_id == checkout_id).first()
        if pledge:
            if result_code == 0:
                print(f"✅ 90% POD Paid for Pledge {pledge.id}!")
                contract = db.query(models.BulkRequest).filter(models.BulkRequest.id == pledge.bulk_request_id).first()
                f = db.query(models.User).filter(models.User.id == pledge.farmer_id).first()
                
                actual_kg = pledge.actual_weight_kg if pledge.actual_weight_kg else pledge.pledged_weight_kg
                total_value = actual_kg * contract.price_per_kg
                
                deposit_held = total_value * 0.10
                pod_paid = total_value * 0.90
                
                coordinator_commission = total_value * 0.01
                farmer_net_pod = pod_paid - coordinator_commission
                
                if f:
                    if (f.escrow_balance or 0.0) >= deposit_held:
                        f.escrow_balance -= deposit_held
                    f.available_balance = (f.available_balance or 0.0) + deposit_held + farmer_net_pod
                    
                    if contract.coordinator_id:
                        coord = db.query(models.User).filter(models.User.id == contract.coordinator_id).first()
                        if coord:
                            coord.available_balance = (coord.available_balance or 0.0) + coordinator_commission
                    
                pledge.status = "paid"
                pledge.checkout_request_id = None 
                db.commit()
            else:
                print(f"Payment failed for Pledge {pledge.id}")
            return {"ResultCode": 0, "ResultDesc": "Accepted"}

    except Exception as e:
        print(f"🚨 Webhook Database Error: {e}")
        db.rollback()
    finally:
        db.close()

    return {"ResultCode": 0, "ResultDesc": "Accepted"}

@app.post("/api/contracts/{contract_id}/pay-deposit")
def pay_contract_deposit(contract_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    contract = db.query(models.BulkRequest).filter(models.BulkRequest.id == contract_id).first()
    if not contract: raise HTTPException(status_code=404, detail="Contract not found")
        
    is_hub_pool = contract.buyer_name and contract.buyer_name.startswith("Hub Pool:")
    if not is_hub_pool and getattr(contract, 'payment_method', 'pay_now') != "pay_on_delivery":
        contract.payment_method = "pay_on_delivery"
        db.commit()

    total_price = contract.target_weight_kg * contract.price_per_kg
    
    payment_method = getattr(contract, 'payment_method', 'pay_now')
    deposit_amount = total_price if payment_method == 'pay_now' else (total_price * 0.10)
    
    is_sandbox = os.getenv("MPESA_ENVIRONMENT", "sandbox").lower() == "sandbox"
    charge = 1 if is_sandbox else deposit_amount

    mpesa = MpesaClient()
    response = mpesa.trigger_stk_push(phone_number=current_user.phone_number, amount=charge, order_id=f"DEP-{contract.id}")
    
    if response and response.get("success"):
        contract.checkout_request_id = response["checkout_id"]
        db.commit()
        return {"message": "STK Push sent!", "checkout_id": response["checkout_id"]}
    raise HTTPException(status_code=400, detail="M-Pesa push failed.")

@app.post("/api/pledges/{pledge_id}/pay-pod")
def pay_pledge_pod(pledge_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Triggers the 90% Pay-On-Delivery for an individual farmer's drop-off"""
    pledge = db.query(models.Pledge).filter(models.Pledge.id == pledge_id).first()
    contract = db.query(models.BulkRequest).filter(models.BulkRequest.id == pledge.bulk_request_id).first()
    
    actual_kg = pledge.actual_weight_kg if pledge.actual_weight_kg else pledge.pledged_weight_kg
    total_value = actual_kg * contract.price_per_kg
    pod_amount = total_value * 0.90
    
    is_sandbox = os.getenv("MPESA_ENVIRONMENT", "sandbox").lower() == "sandbox"
    charge = 1 if is_sandbox else pod_amount

    mpesa = MpesaClient()
    response = mpesa.trigger_stk_push(phone_number=current_user.phone_number, amount=charge, order_id=f"POD-{pledge.id}")
    
    if response and response.get("success"):
        pledge.checkout_request_id = response["checkout_id"]
        db.commit()
        return {"message": "STK Push sent!", "checkout_id": response["checkout_id"]}
    raise HTTPException(status_code=400, detail="M-Pesa push failed.")

@app.put("/api/qa/pledges/{pledge_id}/refund")
def refund_rejected_pledge(pledge_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Called when a Farmer accepts a return. Moves funds from Buyer Escrow -> Buyer Available."""
    pledge = db.query(models.Pledge).filter(models.Pledge.id == pledge_id).first()
    
    if not pledge:
        raise HTTPException(status_code=404, detail="Pledge not found in database.")
        
    contract = db.query(models.BulkRequest).filter(models.BulkRequest.id == pledge.bulk_request_id).first()
    buyer = db.query(models.User).filter(models.User.id == contract.buyer_id).first()
    
    actual_kg = pledge.actual_weight_kg if pledge.actual_weight_kg else pledge.pledged_weight_kg
    total_value = actual_kg * contract.price_per_kg
    deposit_held = total_value * 1.0 if getattr(contract, 'payment_status', '') == 'fully_paid_escrow' else total_value * 0.10
    
    if buyer and (buyer.escrow_balance or 0.0) >= deposit_held:
        buyer.escrow_balance -= deposit_held
        buyer.available_balance = (buyer.available_balance or 0.0) + deposit_held
            
    pledge.status = "refunded"
    db.commit()
    return {"message": "Return Accepted. Escrow refunded to Buyer."}

@app.post("/api/contracts/{contract_id}/pay-balance")
def pay_contract_balance(contract_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Triggers ONE M-Pesa prompt for the remaining 90% of the ENTIRE contract."""
    contract = db.query(models.BulkRequest).filter(models.BulkRequest.id == contract_id).first()
    
    pledges = db.query(models.Pledge).filter(
        models.Pledge.bulk_request_id == contract_id,
        models.Pledge.status.in_(['received', 'pending_audit', 'delivered'])
    ).all()

    total_balance_to_pay = 0
    for p in pledges:
        actual_kg = p.actual_weight_kg if p.actual_weight_kg else p.pledged_weight_kg
        total_balance_to_pay += (actual_kg * contract.price_per_kg) * 0.90

    if total_balance_to_pay <= 0:
        raise HTTPException(status_code=400, detail="No balance to pay. All goods were rejected.")

    is_sandbox = os.getenv("MPESA_ENVIRONMENT", "sandbox").lower() == "sandbox"
    charge = 1 if is_sandbox else total_balance_to_pay

    mpesa = MpesaClient()
    response = mpesa.trigger_stk_push(phone_number=current_user.phone_number, amount=charge, order_id=f"BAL-{contract.id}")

    if response and response.get("success"):
        contract.checkout_request_id = response["checkout_id"]
        db.commit()
        return {"message": "STK Push sent!", "checkout_id": response["checkout_id"]}
    raise HTTPException(status_code=400, detail="M-Pesa push failed.")

@app.post("/api/dev/reset-wallets")
def reset_all_wallets(db: Session = Depends(get_db)):
    users = db.query(models.User).all()
    
    count = 0
    for user in users:
        user.available_balance = 0.0
        user.escrow_balance = 0.0
        count += 1
        
    db.commit()
    return {"message": f"Successfully reset wallets for {count} users to KES 0.0"}

@app.post("/api/contracts/{contract_id}/release-escrow")
def release_contract_escrow(contract_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    contract = db.query(models.BulkRequest).filter(models.BulkRequest.id == contract_id).first()
    if contract.payment_status != 'fully_paid_escrow':
        raise HTTPException(status_code=400, detail="Contract is not fully funded in Escrow.")

    pledges = db.query(models.Pledge).filter(
        models.Pledge.bulk_request_id == contract_id,
        models.Pledge.status.in_(['received', 'pending_audit', 'delivered'])
    ).all()

    for p in pledges:
        f = db.query(models.User).filter(models.User.id == p.farmer_id).first()
        
        locked_escrow_amount = p.pledged_weight_kg * contract.price_per_kg
        
        actual_kg = p.actual_weight_kg if p.actual_weight_kg else p.pledged_weight_kg
        total_earned = actual_kg * contract.price_per_kg

        coordinator_commission = total_earned * 0.01
        farmer_net_payout = total_earned - coordinator_commission

        if f:
            if (f.escrow_balance or 0.0) >= locked_escrow_amount:
                f.escrow_balance -= locked_escrow_amount
            else:
                f.escrow_balance = 0.0 
            
            f.available_balance = (f.available_balance or 0.0) + farmer_net_payout
            
            # Route the 1% aggregation fee to the elected Coordinator
            if contract.coordinator_id:
                coord = db.query(models.User).filter(models.User.id == contract.coordinator_id).first()
                if coord:
                    coord.available_balance = (coord.available_balance or 0.0) + coordinator_commission

        p.status = "paid"

    contract.payment_status = "fully_paid"
    contract.status = "completed"
    db.commit()
    return {"message": "Escrow released and Commission Paid successfully!"}

@app.get("/api/buyer/wallet")
def get_buyer_wallet(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    available = current_user.available_balance or 0.0
    escrow = current_user.escrow_balance or 0.0
    return {
        "available_balance": available,
        "escrow_balance": escrow,
        "total_balance": available + escrow
    }

class WithdrawPayload(BaseModel):
    amount: float

@app.post("/api/wallet/withdraw")
def withdraw_funds(payload: WithdrawPayload, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if payload.amount <= 0:
        raise HTTPException(status_code=400, detail="Invalid amount.")
        
    if (current_user.available_balance or 0.0) < payload.amount:
        raise HTTPException(status_code=400, detail="Insufficient available balance.")
        
    current_user.available_balance -= payload.amount
    
    db.commit()
    return {"message": f"Successfully withdrew KES {payload.amount}. Funds are on the way to your M-Pesa!"}

@app.get("/api/payments/status/{checkout_id}")
def check_payment_status(checkout_id: str, db: Session = Depends(get_db)):
    order = db.query(models.MarketOrder).filter(models.MarketOrder.checkout_request_id == checkout_id).first()
    if order:
        return {"status": "pending"} # Still waiting on Daraja
        
    contract = db.query(models.BulkRequest).filter(models.BulkRequest.checkout_request_id == checkout_id).first()
    if contract:
        return {"status": "pending"}

    pledge = db.query(models.Pledge).filter(models.Pledge.checkout_request_id == checkout_id).first()
    if pledge:
        return {"status": "pending"}

    return {"status": "completed"}

@app.post("/api/admin/force-train-models")
def force_train_models(db: Session = Depends(get_db)):
    """DEV ONLY: Forces Prophet to train on all scraped data immediately."""
    import threading
    thread = threading.Thread(target=scheduled_ml_predictions)
    thread.start()
    return {"message": "Prophet Training sequence initiated in the background. Check terminal logs!"}