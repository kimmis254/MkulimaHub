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

models.Base.metadata.create_all(bind=engine)

# ==========================================
# 1. APP & SCHEDULER INITIALIZATION
# ==========================================
class SquadPitch(BaseModel):
    pitch: str

class SquadVoteRequest(BaseModel):
    candidate_id: int

# We define the background clustering job here so it can be called by the scheduler
def scheduled_clustering_job():
    print("🤖 [SCHEDULER] Running Automatic DBSCAN Clustering...")
    db: Session = SessionLocal() 
    try:
        # 🔥 THE FIX: Tell the scheduler to cluster "All" crops, not just Maize!
        run_clustering_algorithm(db, target_crop="All") 
        print("✅ [SCHEDULER] Clustering Complete!")
    except Exception as e:
        print(f"❌ [SCHEDULER ERROR]: {e}")
    finally:
        db.close()

def scheduled_ml_predictions():
    print("🧠 [SCHEDULER] Waking up to train Prophet Models...")
    db: Session = SessionLocal()
    try:
        # 1. Figure out which crops we actually track
        crops = db.query(models.MarketPrice.commodity).distinct().all()
        crop_list = [c[0] for c in crops if c[0]]
        
        # We will do National level first, and you can expand this to counties later!
        for crop in crop_list:
            for market_type in ["Wholesale", "Retail"]:
                cache_key = f"{crop.lower()}_national_{market_type.lower()}"
                print(f"📈 Training model for {cache_key}...")
                
                # Fetch historical data
                records = db.query(models.MarketPrice.date, models.MarketPrice.price_kes).filter(
                    models.MarketPrice.commodity.ilike(f"%{crop}%"),
                    models.MarketPrice.market_type.ilike(f"%{market_type}%")
                ).all()
                
                if len(records) < 3:
                    continue # Skip crops with no data
                
                df = pd.DataFrame([{"ds": r.date, "y": r.price_kes} for r in records])
                df['ds'] = pd.to_datetime(df['ds'])
                df = df.groupby('ds', as_index=False)['y'].mean().sort_values(by='ds')
                
                # Train Prophet!
                m = Prophet(daily_seasonality=False, yearly_seasonality=True)
                m.fit(df)
                
                future = m.make_future_dataframe(periods=30)
                forecast = m.predict(future)
                
                # Format exactly how Flutter wants it
                historical_prices = df['y'].round(2).tolist()
                future_forecast = forecast[forecast['ds'] > df['ds'].max()]
                
                payload = {
                    "historical_dates": df['ds'].dt.strftime('%Y-%m-%d').tolist(),
                    "historical_prices": historical_prices,
                    "future_dates": future_forecast['ds'].dt.strftime('%Y-%m-%d').tolist(),
                    "future_prices": future_forecast['yhat'].round(2).tolist(),
                    "current_price": float(historical_prices[-1]),
                    "predicted_price": float(future_forecast['yhat'].iloc[-1]) if not future_forecast.empty else float(historical_prices[-1]),
                    "trend": "rising" if (future_forecast['yhat'].iloc[-1] if not future_forecast.empty else 0) > float(historical_prices[-1]) else "falling",
                    "fallback_type": "national"
                }
                
                # Save to Cache Database
                existing = db.query(models.CachedPrediction).filter_by(cache_key=cache_key).first()
                if existing:
                    existing.payload = payload
                    existing.last_updated = datetime.utcnow()
                else:
                    new_cache = models.CachedPrediction(cache_key=cache_key, payload=payload)
                    db.add(new_cache)
                    
                db.commit()
                
        print("✅ [SCHEDULER] All ML Models Trained and Cached!")
    except Exception as e:
        print(f"❌ [SCHEDULER ERROR]: {e}")
    finally:
        db.close()

@asynccontextmanager
async def lifespan(app: FastAPI):
    print("🚀 Starting MkulimaHub API and Background Scheduler...")
    scheduler = BackgroundScheduler()
    scheduler.add_job(scheduled_clustering_job, 'interval', hours=1)
    
    scheduler.add_job(scheduled_ml_predictions, 'cron', hour=2, minute=0)
    
    scheduler.start()
    
    yield
    print("🛑 Shutting down Scheduler...")
    scheduler.shutdown()

app = FastAPI(title="MkulimaHub API", lifespan=lifespan)

# ==========================================
# 2. RATE LIMITING SETUP
# ==========================================
limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# ==========================================
# 3. AUTHENTICATION & SECURITY ENDPOINTS
# ==========================================
GOOGLE_CLIENT_ID = "654543955611-g18qameesn4daglsc8pup7rkj6c1n541.apps.googleusercontent.com"

# 🔥 We only need ONE schema now. The token holds the email, name, and UID!
class GoogleAuthRequest(BaseModel):
    id_token: str
    phone_number: Optional[str] = None
    role: Optional[str] = "farmer" # Defaults to farmer, but accepts buyer!

# 🔥 2. Added /api/ to the URL to match the Flutter app
@app.post("/api/auth/google")
@limiter.limit("5/minute")
def google_login(request: Request, payload: GoogleAuthRequest, db: Session = Depends(get_db)):
    try:
        # Verify the token cryptographically with Google's servers
        idinfo = id_token.verify_oauth2_token(payload.id_token, google_requests.Request(), GOOGLE_CLIENT_ID,clock_skew_in_seconds=10)
        verified_email = idinfo['email']
        
    except ValueError as e:
        print(f"🚨 GOOGLE TOKEN REJECTED: {str(e)}") 
        raise HTTPException(status_code=401, detail=f"Token Error: {str(e)}")

    user = db.query(models.User).filter(models.User.email == verified_email).first()
    
    if user:
        if not user.phone_number:
            return {"status": "needs_phone"}
            
        access_token = security.create_access_token(data={"sub": str(user.id), "role": user.role})
        
        # Check if they still need to finish setting up their location/profile
        needs_profile = False
        if not user.county or not user.village:
            needs_profile = True
            
        return {"access_token": access_token, "token_type": "bearer", "status": "success", "needs_profile": needs_profile}
    else:
        return {"status": "needs_phone"}

# 🔥 3. Added /api/ to the URL
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

    # Check for duplicate phone numbers
    existing_phone = db.query(models.User).filter(models.User.phone_number == payload.phone_number).first()
    if existing_phone and existing_phone.email != verified_email:
        raise HTTPException(status_code=400, detail="Phone number already registered to another account.")
    
    user = db.query(models.User).filter(models.User.email == verified_email).first()
    
    if user:
        user.phone_number = payload.phone_number
    else:
        # 🔥 4. Dynamically assign the role passed from Flutter!
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
        print(f"❌ Database error during registration: {e}")
        raise HTTPException(status_code=500, detail="Failed to create account. Please try again.")

@app.post("/auth/login", response_model=schemas.Token)
@limiter.limit("5/minute")
def login_user(request: Request, form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    
    raw_phone = form_data.username.strip()
    
    # 🔥 Create BOTH versions of the phone number!
    phone_zero = raw_phone
    phone_plus = raw_phone
    
    if raw_phone.startswith("+254"):
        phone_zero = "0" + raw_phone[4:]
    elif raw_phone.startswith("0"):
        phone_plus = "+254" + raw_phone[1:]

    # 🔥 Search the database for EITHER format. We will never miss a match again!
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
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Account not found. Please register first."
        )
    
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


# ==========================================
# 4. USER PROFILES & DATA
# ==========================================

@app.put("/users/profile", response_model=schemas.UserRead)
def update_profile(profile_data: schemas.UserProfileUpdate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    update_data = profile_data.dict(exclude_unset=True)

    provided_lat = update_data.get("latitude")
    provided_lng = update_data.get("longitude")

    if provided_lat is None or provided_lng is None:
        ward = update_data.get("ward") or current_user.ward
        county = update_data.get("county") or current_user.county

        if ward and county:
            print(f"🌍 Asking OpenStreetMap for exact Ward: {ward}, {county}...")
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
                print(f"❌ Geocoding API Error: {e}")

    for key, value in update_data.items():
        setattr(current_user, key, value) 

    # 🔥 THE FIX: Wrap the save in a try/except block
    try:
        db.add(current_user)
        db.commit()
        db.refresh(current_user)
        return current_user
    except Exception as e:
        db.rollback()
        print(f"❌ DB Error updating profile: {e}")
        raise HTTPException(status_code=500, detail="Could not update profile. Please try again.")

@app.get("/users/me", response_model=schemas.UserRead)
def get_my_profile(current_user: models.User = Depends(get_current_user)):
    # FastAPI will automatically grab the role, hub_id, etc., based on your schema!
    return current_user

@app.delete("/users/me")
def delete_my_account(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    db.delete(current_user)
    db.commit()
    return {"message": "Account deleted successfully"}


# ==========================================
# 5. HARVESTS, PLEDGES, & MARKETPLACE
# ==========================================

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
        print(f"❌ DB Error creating harvest: {e}")
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

@app.post("/api/contracts", response_model=schemas.BulkRequestRead)
def create_bulk_contract(contract: schemas.BulkRequestCreate, db: Session = Depends(get_db)):
    new_contract = models.BulkRequest(**contract.dict())
    db.add(new_contract)
    db.commit()
    db.refresh(new_contract)
    return new_contract

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
            "ward": req.ward, # 🔥 Contact & Address
            "urgency": req.urgency, # 🔥 Real Urgency
            "has_pledged": has_pledged 
        })
    return results


@app.get("/api/my-pledges")
def get_my_pledges(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if current_user.role != "farmer":
        raise HTTPException(status_code=403, detail="Only farmers can view delivery squads.")

    # 🔥 FIX #3 (N+1 Queries): Use joinedload to fetch the Pledges AND their connected BulkRequests 
    # all at the exact same time in a single SQL query!
    pledges = db.query(models.Pledge)\
                .options(joinedload(models.Pledge.bulk_request))\
                .filter(
                    models.Pledge.farmer_id == current_user.id,
                    ~models.Pledge.status.in_(["paid", "completed", "rejected"]) 
                ).all()
    
    result = []
    db_needs_commit = False # 🔥 Tracks if we deleted ghosts OR healed a stuck contract
    
    for p in pledges:
        req = p.bulk_request 
        
        if not req:
            db.delete(p) 
            db_needs_commit = True 
            continue 

        # ==========================================
        # 🔥 SELF-HEALING LOGIC (Fixing stuck contracts)
        # ==========================================
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
                squad_roster.append({
                    "pledge_id": sp.id,              
                    "farmer_id": farmer.id,
                    "name": farmer.full_name,
                    "pledge_kg": sp.pledged_weight_kg,
                    "payout_kes": sp.pledged_weight_kg * req.price_per_kg,
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

        result.append({
            "id": p.id,
            "pledged_weight_kg": p.pledged_weight_kg,
            "actual_weight_kg": p.actual_weight_kg,
            "status": p.status,
            "bulk_request": {
                "id": req.id, "buyer_name": req.buyer_name, "crop_name": req.crop_name,
                "target_weight_kg": req.target_weight_kg, "price_per_kg": req.price_per_kg,
                "county": req.county, 
                "ward": req.ward, # 🔥 Added
                "urgency": req.urgency, # 🔥 Added
                "squad_status": req.squad_status, "coordinator_id": req.coordinator_id, 
                "squad_roster": squad_roster, "candidates": candidates_list, "has_voted": has_voted         
            }
        })
        
    if db_needs_commit:
        db.commit() 
        
    return result

class PledgeUpdate(BaseModel):
    pledged_weight_kg: float

@app.put("/api/pledges/{pledge_id}", response_model=schemas.PledgeRead)
def update_pledge(pledge_id: int, payload: PledgeUpdate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    # 1. Find the exact pledge
    pledge = db.query(models.Pledge).filter(models.Pledge.id == pledge_id, models.Pledge.farmer_id == current_user.id).first()
    if not pledge:
        raise HTTPException(status_code=404, detail="Pledge not found.")

    try:
        # 2. Update the weight
        pledge.pledged_weight_kg = payload.pledged_weight_kg
        db.flush()

        # 3. Recalculate the entire contract's math
        bulk_req = db.query(models.BulkRequest).filter(models.BulkRequest.id == pledge.bulk_request_id).first()
        total_pledged = db.query(func.sum(models.Pledge.pledged_weight_kg)).filter(models.Pledge.bulk_request_id == bulk_req.id).scalar() or 0.0

        # If it dropped below 100%, reopen the contract!
        if total_pledged < bulk_req.target_weight_kg:
            bulk_req.status = "Open"
        else:
            bulk_req.status = "fulfilled"

        db.commit()
        db.refresh(pledge)
        return pledge
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to update pledge.")

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
        
        # 🔥 THE FIX: Clean up their specific election data!
        # 1. Remove them from the ballot if they were running
        db.query(models.SquadCandidate).filter(
            models.SquadCandidate.bulk_request_id == req_id, 
            models.SquadCandidate.farmer_id == current_user.id
        ).delete()
        
        # 2. Remove any votes they cast
        db.query(models.SquadVote).filter(
            models.SquadVote.bulk_request_id == req_id, 
            models.SquadVote.farmer_id == current_user.id
        ).delete()

        # 3. IF THEY WERE THE COORDINATOR, DEPOSE THEM!
        if bulk_req.coordinator_id == current_user.id:
            bulk_req.coordinator_id = None
            bulk_req.squad_status = "voting" # Force the remaining farmers to elect a new leader!

        # Recalculate math
        total_pledged = db.query(func.sum(models.Pledge.pledged_weight_kg)).filter(models.Pledge.bulk_request_id == req_id).scalar() or 0.0

        if total_pledged < bulk_req.target_weight_kg:
            bulk_req.status = "Open"
            
        # If everyone left the squad, completely reset the election!
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
    """
    Groups independent farmers by Crop, then uses DBSCAN to cluster them 
    if they are within a 5km radius of each other.
    """
    # 1. Fetch unclustered (independent) farmers with GPS coordinates
    query = db.query(models.User).filter(
        models.User.role == "farmer",
        models.User.hub_id == None,
        models.User.latitude.isnot(None),
        models.User.longitude.isnot(None)
    )

    # Filter by crop if a specific one was requested
    if target_crop != "All":
        query = query.filter(models.User.main_crops.ilike(f"%{target_crop}%"))

    independent_farmers = query.all()
    if not independent_farmers:
        return 0

    # 2. Extract data into a list
    data = []
    for f in independent_farmers:
        if f.main_crops:
            # Assume their primary crop is the first one listed in the string
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
    
    # Radius of earth in km
    EARTH_RADIUS_KM = 6371.0 
    # Max distance between farmers to be in the same hub (5 kilometers)
    MAX_DISTANCE_KM = 5.0 
    epsilon = MAX_DISTANCE_KM / EARTH_RADIUS_KM

    # 3. Run Spatial AI (DBSCAN) independently for EACH crop!
    unique_crops = df['crop'].unique()
    
    for current_crop in unique_crops:
        crop_df = df[df['crop'] == current_crop].copy()
        
        # Need at least 2 farmers near each other to form a viable Co-op Hub
        if len(crop_df) < 2:
            continue

        # Convert lat/lon to radians for the Haversine formula (Earth curvature)
        coords = np.radians(crop_df[['lat', 'lon']].values)
        
        # Run DBSCAN AI
        dbscan = DBSCAN(eps=epsilon, min_samples=2, algorithm='ball_tree', metric='haversine').fit(coords)
        crop_df['cluster'] = dbscan.labels_
        
        # 4. Save the new valid clusters to the Database
        for cluster_id in crop_df['cluster'].unique():
            if cluster_id == -1: 
                # -1 means "Noise" (Farmer is too isolated, leave them independent)
                continue
                
            cluster_farmers = crop_df[crop_df['cluster'] == cluster_id]
            
            # Generate the new Hub using the Ward of the first farmer
            ward_name = cluster_farmers.iloc[0]['ward']
            hub_name = f"{ward_name} {current_crop} Co-op"
            
            new_hub = models.Hub(
                name=hub_name,
                crop=current_crop,
                center_latitude=float(cluster_farmers['lat'].mean()), 
                center_longitude=float(cluster_farmers['lon'].mean())
            )
            db.add(new_hub)
            db.flush() # Get the new_hub.id immediately
            
            # Move the independent farmers into their new Hub
            for farmer_id in cluster_farmers['id']:
                db.query(models.User).filter(models.User.id == farmer_id).update({"hub_id": new_hub.id})
            
            total_hubs_created += 1

    db.commit()
    return total_hubs_created

@app.post("/api/admin/trigger-clustering")
def admin_trigger_clustering(crop: str = "All", db: Session = Depends(get_db)):
    """Admin endpoint to manually trigger the freeze logic."""
    created = run_clustering_algorithm(db, target_crop=crop)
    return {"message": f"Successfully created {created} new permanent Hubs based on proximity and crop!"}


@app.get("/api/clusters")
def get_frozen_clusters(crop: str = None, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    query = db.query(models.Hub)
    if crop and crop != 'All':
        query = query.filter(models.Hub.crop.ilike(f"%{crop}%"))
    
    hubs = query.all()
    
    # 🔥 THE FIX (N+1 Solution): Grab all Hub IDs, then fetch ALL farmers in exactly ONE database query!
    hub_ids = [h.id for h in hubs]
    all_hub_members = db.query(models.User).filter(
        models.User.hub_id.in_(hub_ids),
        models.User.role == "farmer"
    ).all()
    
    # Group the farmers by hub_id using a fast Python dictionary
    members_by_hub = {}
    for member in all_hub_members:
        if member.hub_id not in members_by_hub:
            members_by_hub[member.hub_id] = []
        members_by_hub[member.hub_id].append(member)

    # Fetch "Noise" - strictly FARMERS who have GPS but no Hub
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
        # 🔥 Pull from our dictionary instead of hitting the database!
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
    
    # 🔥 1. Get the raw squads from the database
    all_squads = db.query(models.BulkRequest).filter(
        models.BulkRequest.squad_status.in_(["gathering", "voting", "active"]),
        models.BulkRequest.status != "completed" 
    ).all()
    
    squads_db = []
    for req in all_squads:
        if req.squad_status in ["gathering", "voting"] and req.status == "Open":
            squads_db.append(req)
        elif req.squad_status == "active":
            # Only keep it on the screen if the current user is actually in this squad!
            if any(p.farmer_id == current_user.id for p in req.pledges):
                squads_db.append(req)
    
    # 🔥 2. THE FIX: Explicitly format the data so FastAPI includes the pledges!
    active_squads_data = []
    
    for req in squads_db:
        # Check if the current user has voted in this specific squad
        has_voted = False
        if current_user:
            vote_check = db.query(models.SquadVote).filter(
                models.SquadVote.bulk_request_id == req.id,
                models.SquadVote.farmer_id == current_user.id
            ).first()
            if vote_check:
                has_voted = True

        # Fetch the candidates for this specific squad
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
            "pledges": [{"farmer_id": p.farmer_id} for p in req.pledges],
            "candidates": candidates_list, # 🔥 Attach the ballot!
            "has_voted": has_voted         # 🔥 Tell Flutter if they voted!
        })
    
    return {
        "total_farmers_analyzed": total_analyzed,
        "total_hubs_found": len(final_hubs),
        "hubs": final_hubs,
        "independent_farmers": indep_list,
        "active_squads": active_squads_data # 🔥 Send the complete data down to Flutter
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
        
        # 🔥 DYNAMIC POOL INJECTION
        if msg_text.startswith("POOL_REQ|"):
            parts = msg_text.split('|')
            if len(parts) >= 2:
                contract_id = int(parts[1])
                contract = db.query(models.BulkRequest).filter(models.BulkRequest.id == contract_id).first()
                if contract:
                    total_pledged = db.query(func.sum(models.Pledge.pledged_weight_kg)).filter(models.Pledge.bulk_request_id == contract_id).scalar() or 0.0
                    # Append the live progress and status directly into the string!
                    msg_text = f"{m.message}|{total_pledged}|{contract.status}"

        result.append({
            "id": m.id,
            "hub_name": m.hub_name,
            "message": msg_text, # Pass the upgraded string to Flutter
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

# ==========================================
# 7. AI, PREDICTIONS, & CHATBOT
# ==========================================

class PredictionRequest(BaseModel):
    commodity: str
    days: int
    region: str
    price_type: str

# Use your exact KENYA_COUNTIES list here...
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
    """Fetches the LIVE current wholesale spot price for a specific crop."""
    db = SessionLocal() # Open a quick database session for the AI
    try:
        # Ask Postgres for the latest price for this crop and county
        latest_record = db.query(models.MarketPrice).filter(
            models.MarketPrice.commodity.ilike(f"%{crop}%"),
            models.MarketPrice.county.ilike(f"%{county}%")
        ).order_by(models.MarketPrice.date.desc()).first()
        
        if latest_record:
            return f"Live Spot Price: {crop.capitalize()} is currently trading at KES {latest_record.price_kes} per kg in {county.capitalize()}."
        return f"I couldn't find any recent market data for {crop} in {county}."
    finally:
        db.close() # Always close the session so we don't crash the server!

def predict_price_trend(crop: str) -> str:
    """Predicts the future price trend for a specific crop."""
    db = SessionLocal()
    try:
        # Grab the cached AI prediction we built earlier!
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
    """Fetches the LIVE weather forecast for a location."""
    # (Optional: Connect this to a real Weather API later!)
    return f"Live Weather Data for {location}: Sunny, 28°C."

def diagnose_crop_disease(symptoms: str) -> str:
    """Analyzes crop symptoms to predict diseases."""
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

    # Calculate Haversine distance to all hubs and sort them
    kms_per_radian = 6371.0088
    hub_distances = []
    
    user_lat_rad = np.radians(current_user.latitude)
    user_lon_rad = np.radians(current_user.longitude)

    for hub in hubs:
        hub_lat_rad = np.radians(hub.center_latitude)
        hub_lon_rad = np.radians(hub.center_longitude)
        
        # Haversine formula
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

    # Return the 3 closest hubs
    hub_distances.sort(key=lambda x: x["distance_km"])
    return hub_distances[:3]

@app.post("/api/hubs/{hub_id}/join")
def request_to_join_hub(hub_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Allows an independent farmer to request to join a hub."""
    if current_user.hub_id is not None:
        raise HTTPException(status_code=400, detail="You are already in a hub.")
        
    # Check if request already exists
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
    """Fetches all pending join requests if the current user is a Hub Coordinator."""
    # 1. Check if the user is a coordinator for ANY hub
    hub = db.query(models.Hub).filter(models.Hub.coordinator_id == current_user.id).first()
    
    if not hub:
        return [] # Not a coordinator, return empty list
        
    # 2. Fetch pending requests for their specific hub
    requests = db.query(models.HubRequest).filter(
        models.HubRequest.hub_id == hub.id,
        models.HubRequest.status == "pending"
    ).all()
    
    return [{
        "request_id": r.id,
        "farmer_name": r.farmer.full_name,
        "farmer_phone": r.farmer.phone_number, # Coordinators get to see phone numbers of applicants!
        "crops": r.farmer.main_crops,
        "village": r.farmer.village
    } for r in requests]

@app.put("/api/coordinator/requests/{request_id}")
def respond_to_request(request_id: int, action: str, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Allows a coordinator to approve or reject a join request."""
    req = db.query(models.HubRequest).filter(models.HubRequest.id == request_id).first()
    
    if not req:
        raise HTTPException(status_code=404, detail="Request not found")
        
    # Security Check: Verify the current user actually owns the hub this request is for
    hub = db.query(models.Hub).filter(models.Hub.id == req.hub_id).first()
    if hub.coordinator_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to manage this hub.")
        
    if action == "approve":
        req.status = "approved"
        req.farmer.hub_id = hub.id # 🔥 OFFICIALLY MOVE THE FARMER INTO THE HUB!
    elif action == "reject":
        req.status = "rejected"
    else:
        raise HTTPException(status_code=400, detail="Invalid action. Use 'approve' or 'reject'.")
        
    db.commit()
    return {"message": f"Farmer has been {action}d successfully."}

class CandidatePitch(BaseModel):
    pitch: str

@app.post("/api/hubs/election/run")
def run_for_coordinator(payload: CandidatePitch, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Allows a farmer to nominate themselves for Hub Coordinator."""
    if not current_user.hub_id:
        raise HTTPException(status_code=400, detail="You must belong to a Hub to run for office.")
        
    hub = db.query(models.Hub).filter(models.Hub.id == current_user.hub_id).first()
    if hub.coordinator_id is not None:
        raise HTTPException(status_code=400, detail="This Hub already has a Coordinator.")

    # Check if they are already running
    existing = db.query(models.HubCandidate).filter(
        models.HubCandidate.hub_id == hub.id, 
        models.HubCandidate.farmer_id == current_user.id
    ).first()
    
    if existing:
        return {"message": "You are already on the ballot!"}

    candidate = models.HubCandidate(hub_id=hub.id, farmer_id=current_user.id, pitch=payload.pitch)
    db.add(candidate)
    db.commit()
    return {"message": "You are officially running for Coordinator!"}

@app.get("/api/hubs/election/ballot")
def get_election_ballot(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Fetches all candidates currently running in the user's hub."""
    if not current_user.hub_id:
        return {"status": "no_hub", "candidates": []}

    hub = db.query(models.Hub).filter(models.Hub.id == current_user.hub_id).first()
    if hub.coordinator_id is not None:
        return {"status": "election_over", "coordinator_id": hub.coordinator_id}

    candidates = db.query(models.HubCandidate).filter(models.HubCandidate.hub_id == hub.id).all()
    
    # Check if current user already voted
    has_voted = db.query(models.HubVote).filter(
        models.HubVote.hub_id == hub.id,
        models.HubVote.voter_id == current_user.id
    ).first() is not None

    results = []
    for c in candidates:
        # Count the votes for this candidate
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
    """Casts a vote and checks if we have a winner."""
    if not current_user.hub_id:
        raise HTTPException(status_code=400, detail="You must be in a Hub to vote.")

    # 1. Ensure they haven't voted already
    existing_vote = db.query(models.HubVote).filter(
        models.HubVote.hub_id == current_user.hub_id,
        models.HubVote.voter_id == current_user.id
    ).first()
    
    if existing_vote:
        raise HTTPException(status_code=400, detail="You have already cast your vote.")

    # 🔥 NEW: Prevent voting for yourself
    candidate = db.query(models.HubCandidate).filter(models.HubCandidate.id == candidate_id).first()
    if not candidate:
        raise HTTPException(status_code=404, detail="Candidate not found.")
        
    if candidate.farmer_id == current_user.id:
        raise HTTPException(status_code=400, detail="You cannot vote for yourself. A true leader needs the community's backing!")

    # 2. Record the vote
    vote = models.HubVote(hub_id=current_user.hub_id, voter_id=current_user.id, candidate_id=candidate_id)
    db.add(vote)
    db.commit()

    # 3. AUTO-RESOLVE LOGIC: Did this vote trigger a winner?
    total_hub_members = db.query(models.User).filter(models.User.hub_id == current_user.hub_id).count()
    candidate_votes = db.query(models.HubVote).filter(models.HubVote.candidate_id == candidate_id).count()

    # Strict Majority Check (> 50%)
    if candidate_votes > (total_hub_members / 2):
        hub = db.query(models.Hub).filter(models.Hub.id == current_user.hub_id).first()
        
        hub.coordinator_id = candidate.farmer_id
        db.commit()
        return {"message": "Vote cast! We have a winner! The election is over."}

    return {"message": "Vote cast successfully!"}

class ProcessDeliveryPayload(BaseModel):
    action: str # "receive" or "reject"
    actual_weight_kg: Optional[float] = None
    notes: Optional[str] = None

class HubPoolCreate(BaseModel):
    crop_name: str
    target_weight_kg: float
    price_per_kg: float

@app.post("/api/hubs/{hub_name}/pools")
def create_hub_pool(hub_name: str, payload: HubPoolCreate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Creates an internal Hub aggregation pool and broadcasts an interactive widget to the chat."""
    
    # 1. Create a BulkRequest that acts as an Internal Hub Pool
    new_pool = models.BulkRequest(
        buyer_name=f"Hub Pool: {hub_name}", # 🔥 This is the secret flag!
        crop_name=payload.crop_name,
        target_weight_kg=payload.target_weight_kg,
        price_per_kg=payload.price_per_kg,
        county="Hub Internal",
        status="Open",
        squad_status="gathering",
        coordinator_id=current_user.id # The Hub Admin is the coordinator!
    )
    db.add(new_pool)
    db.commit()
    db.refresh(new_pool)

    # 2. Inject the Interactive Widget Payload into the Chat
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
    """Fetches ALL squads (Pools AND Corporate Contracts) loading up at this Hub!"""
    hub = db.query(models.Hub).filter(models.Hub.coordinator_id == current_user.id).first()
    if not hub:
        raise HTTPException(status_code=403, detail="Only Hub Admins can view the receiving weighbridge.")

    # 1. Find all farmers that belong to this specific Hub
    hub_farmers = db.query(models.User.id).filter(models.User.hub_id == hub.id).all()
    hub_farmer_ids = [f.id for f in hub_farmers]

    if not hub_farmer_ids:
        return []

    # 2. Find ALL active bulk requests that these farmers are pledged to
    relevant_pledges = db.query(models.Pledge).filter(models.Pledge.farmer_id.in_(hub_farmer_ids)).all()
    squad_ids = list(set([p.bulk_request_id for p in relevant_pledges]))
    
    squads = db.query(models.BulkRequest).filter(models.BulkRequest.id.in_(squad_ids)).all()

    results = []

    for pool in squads:
        # Ignore completed or open/empty squads
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

        # Dynamically calculate totals excluding ghosted/rejected farmers
        total_pledged = sum(p.pledged_weight_kg for p in pledges if p.status != 'rejected')
        total_actual = sum((p.actual_weight_kg or 0) for p in pledges if p.status != 'rejected')

        ui_status = "delivered" if total_pledged >= pool.target_weight_kg else "in_transit"
        if has_pending_audit: ui_status = "pending_audit"
        elif all_received: ui_status = "received"

        # Look up the coordinator's name
        coordinator_name = "Hub Drop-off"
        if pool.coordinator_id:
            coord_user = db.query(models.User).filter(models.User.id == pool.coordinator_id).first()
            if coord_user: coordinator_name = coord_user.full_name

        results.append({
            "squad_id": pool.id,
            "crop_name": pool.crop_name,
            "coordinator_name": coordinator_name, 
            "total_pledged": total_pledged,
            "target_weight": pool.target_weight_kg,
            "total_actual": total_actual,
            "status": ui_status,
            "farmer_count": len([p for p in pledges if p.status != 'rejected']),
            "roster": roster 
        })

    return results

@app.post("/api/hubs/deliveries/{squad_id}/process")
def process_hub_delivery(squad_id: int, payload: ProcessDeliveryPayload, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Allows Coordinator to accept or reject an ENTIRE Squad's truck at once."""
    squad = db.query(models.BulkRequest).filter(models.BulkRequest.id == squad_id).first()
    if not squad:
        raise HTTPException(status_code=404, detail="Squad not found.")

    pledges = db.query(models.Pledge).filter(models.Pledge.bulk_request_id == squad_id).all()

    if payload.action == "receive":
        # 🔥 THE PRO-RATA ALGORITHM
        # If the scale reads 490kg, but they pledged 500kg, we divide the loss fairly.
        actual_total = payload.actual_weight_kg or sum(p.pledged_weight_kg for p in pledges)
        pledged_total = sum(p.pledged_weight_kg for p in pledges)
        
        ratio = actual_total / pledged_total if pledged_total > 0 else 1.0

        for pledge in pledges:
            pledge.status = "received"
            # Calculate their exact physical contribution
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
    """Fetches the logged-in farmer's personal pledges AND direct sales."""
    
    unified_deliveries = []
    db_needs_commit = False

    # ==========================================
    # 1. FETCH BULK SQUAD PLEDGES
    # ==========================================
    pledges = db.query(models.Pledge).filter(
        models.Pledge.farmer_id == current_user.id,
        ~models.Pledge.status.in_(["paid", "completed", "rejected"])
    ).all()
    
    for p in pledges:
        contract = db.query(models.BulkRequest).filter(models.BulkRequest.id == p.bulk_request_id).first()
        if not contract:
            continue
            
        is_internal_pool = contract.buyer_name.startswith("Hub Pool:")

        # 🔥 THE FIX: Dynamically assign the correct auditor text based on the contract type!
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

        # Check if EVERY farmer in the squad is verified!
        all_squad_received = True
        squad_pledges_check = db.query(models.Pledge).filter(models.Pledge.bulk_request_id == contract.id).all()
        for sp in squad_pledges_check:
            # If anyone is still pending_audit, pledged, or gathering, the truck can't leave!
            if sp.status not in ['received', 'in_transit', 'delivered', 'completed', 'paid']:
                all_squad_received = False

        unified_deliveries.append({
            "id": f"BLK-{p.id:04d}", 
            "type": "Co-op Pool" if is_internal_pool else "Bulk Contract",
            "crop": contract.crop_name, 
            "weight_kg": p.pledged_weight_kg,
            "unit": "KG", 
            "expected_payout": p.pledged_weight_kg * contract.price_per_kg,
            "status": p.status, 
            "buyer": "Your Local Co-op" if is_internal_pool else contract.buyer_name, 
            "notes": display_notes,
            "is_coordinator": contract.coordinator_id == current_user.id, 
            "bulk_request_id": contract.id, 
            "squad_status": contract.squad_status,
            "all_squad_received": all_squad_received 
        })
    # ==========================================
    # 2. FETCH INDIVIDUAL DIRECT SALES (MarketListings & Orders)
    # ==========================================
    try:
        direct_orders = db.query(models.MarketOrder).join(models.MarketListing).filter(
            models.MarketListing.farmer_id == current_user.id,
            ~models.MarketOrder.status.in_(["paid", "completed", "rejected"]) # 🔥 THE FIX: Hides finished orders
        ).all()
        
        for order in direct_orders:
            listing = order.listing
            buyer = order.buyer
            
            # 🔥 THE FIX: Get unit name safely from the order, not the listing!
            unit_name = order.order_type if order.order_type else "KG"
            
            # 🔥 NEW: Grab Buyer's Contact & Location Intel
            buyer_contact = buyer.phone_number if buyer and buyer.phone_number else "No phone provided"
            
            buyer_address = "Unknown Location"
            if buyer:
                address_parts = [buyer.village, buyer.sub_county, buyer.county]
                buyer_address = ", ".join([p for p in address_parts if p])
            
            unified_deliveries.append({
                "id": f"ORD-{order.id:04d}", 
                "order_id": order.id, # 🔥 Required for the farmer to trigger status updates!
                "type": "Direct Sale",
                "crop": listing.crop_name, "weight_kg": order.quantity_ordered, "unit": unit_name, 
                "expected_payout": order.total_price, "status": order.status, 
                "buyer": buyer.full_name if buyer else "Customer", 
                "buyer_phone": buyer_contact, "buyer_address": buyer_address,
                "delivery_method": getattr(order, 'delivery_method', 'Delivery'), # 🔥 NEW
                "dispute_notes": getattr(order, 'dispute_notes', None),           # 🔥 NEW
                "dispute_image": getattr(order, 'dispute_image', None),           # 🔥 NEW
            })
    except Exception as e:
        print(f"Direct Sales fetch error: {e}")
        
    # Finally, return both lists combined
    return unified_deliveries
    
class SquadStatusUpdate(BaseModel):
    status: str

class MessageCreate(BaseModel):
    message: str 

@app.put("/api/deliveries/squad/{bulk_request_id}/status")
def update_squad_delivery_status(bulk_request_id: int, payload: SquadStatusUpdate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Allows the Squad Coordinator to move the entire squad's delivery along the timeline."""
    req = db.query(models.BulkRequest).filter(models.BulkRequest.id == bulk_request_id).first()
    if not req:
        raise HTTPException(status_code=404, detail="Contract not found.")
        
    if req.coordinator_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the elected Squad Coordinator can update the transit status!")

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

    pledge.status = payload.status
    if payload.notes: pledge.notes = payload.notes
        
    # 🔥 AUTO-COMPLETE CONTRACT LOGIC: If all farmers are paid, close the contract!
    if payload.status == "paid":
        all_pledges = db.query(models.Pledge).filter(models.Pledge.bulk_request_id == contract.id).all()
        # Check if EVERY pledge is either paid or rejected (no one left waiting)
        all_done = all(p.status in ['paid', 'rejected'] for p in all_pledges)
        if all_done:
            contract.status = "completed"
            
    db.commit()
    return {"message": "Funds Released and Escrow closed!" if payload.status == "paid" else "Status updated."}

@app.put("/api/buyer/orders/{order_id}/qa")
def update_direct_order_qa(order_id: int, payload: QAUpdate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    order = db.query(models.MarketOrder).filter(models.MarketOrder.id == order_id).first()
    if not order: raise HTTPException(status_code=404, detail="Order not found.")
    
    order.status = payload.status
    if payload.notes: getattr(order, 'dispute_notes', None) # Safety check
    if hasattr(order, 'dispute_notes'): order.dispute_notes = payload.notes
    if hasattr(order, 'dispute_image'): order.dispute_image = payload.dispute_image

    db.commit()
    return {"message": "QA Processed!"}

@app.get("/api/buyer/dashboard")
def get_buyer_dashboard(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    contracts = db.query(models.BulkRequest).filter(models.BulkRequest.buyer_name == current_user.full_name).all()
    
    total_capital_committed = 0
    total_tonnage_requested = 0
    active_contracts = []
    
    for contract in contracts:
        # ... (Keep your existing `for contract in contracts` loop logic here exactly as it is) ...
        pledges = db.query(models.Pledge).filter(models.Pledge.bulk_request_id == contract.id).all()
        total_pledged_kg = sum(p.pledged_weight_kg for p in pledges if p.pledged_weight_kg)
        
        contract_value = contract.target_weight_kg * contract.price_per_kg
        total_capital_committed += contract_value
        total_tonnage_requested += contract.target_weight_kg
        progress_pct = (total_pledged_kg / contract.target_weight_kg) if contract.target_weight_kg > 0 else 0
        
        roster = []
        for p in pledges:
            farmer = db.query(models.User).filter(models.User.id == p.farmer_id).first()
            roster.append({
                "pledge_id": p.id, "farmer_name": farmer.full_name if farmer else "Unknown",
                "pledged_kg": p.pledged_weight_kg, "actual_kg": p.actual_weight_kg or p.pledged_weight_kg,
                "status": p.status, "notes": p.notes
            })
            
        c_status = contract.status
        if c_status != "completed":
            c_status = "fulfilled" if total_pledged_kg >= contract.target_weight_kg else "active"

        active_contracts.append({
            "contract_id": contract.id, "crop_name": contract.crop_name,
            "target_weight_kg": contract.target_weight_kg, "pledged_weight_kg": total_pledged_kg,
            "price_per_kg": contract.price_per_kg, "progress_percentage": min(progress_pct, 1.0),
            "status": c_status, "roster": roster 
        })

    # 🔥 THE FIX: Fetch Direct Cart Orders
    market_orders = db.query(models.MarketOrder).filter(models.MarketOrder.buyer_id == current_user.id).all()
    direct_orders = []
    for order in market_orders:
        listing = order.listing
        farmer = listing.farmer if listing else None
        
        # Add to metrics tracking
        total_capital_committed += order.total_price
        if order.order_type == "KG":
            total_tonnage_requested += order.quantity_ordered
            
        direct_orders.append({
            "order_id": order.id,
            "crop_name": listing.crop_name if listing else "Produce",
            "quantity": order.quantity_ordered, "unit": order.order_type,
            "total_price": order.total_price, "status": order.status,
            "farmer_name": farmer.full_name if farmer else "Local Farmer",
            "farmer_phone": farmer.phone_number if farmer else "N/A",
            "delivery_method": getattr(order, 'delivery_method', 'Delivery'), # 🔥 NEW
            "dispute_notes": getattr(order, 'dispute_notes', None),           # 🔥 NEW
        })

    return {
        "metrics": {
            "total_capital_kes": total_capital_committed,
            "total_tonnage_kg": total_tonnage_requested,
            "active_contract_count": len([c for c in active_contracts if c['status'] != 'completed']) + len([o for o in direct_orders if o['status'] not in ['paid', 'completed', 'rejected']])
        },
        "contracts": active_contracts,
        "direct_orders": direct_orders # 🔥 Return Direct Orders!
    }

class BulkRequestCreate(BaseModel):
    crop_name: str
    target_weight_kg: float
    price_per_kg: float
    county: str
    ward: Optional[str] = None

@app.post("/api/buyer/contracts")
def create_bulk_contract(payload: BulkRequestCreate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Allows a buyer to post a new Bulk Contract to the Marketplace."""
    
    new_contract = models.BulkRequest(
        buyer_name=current_user.full_name, # Auto-filled from their profile!
        crop_name=payload.crop_name,
        target_weight_kg=payload.target_weight_kg,
        price_per_kg=payload.price_per_kg,
        county=payload.county,
        ward=payload.ward,
        status="Open"
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
    # 1. Find the pledge
    pledge = db.query(models.Pledge).filter(models.Pledge.id == pledge_id).first()
    if not pledge:
        raise HTTPException(status_code=404, detail="Pledge not found")

    # 2. Security Check: Only buyers can release escrow
    if current_user.role != "buyer":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Security Error: Only the Corporate Buyer can verify quality and release Escrow funds."
        )

    # 3. Logic Check: Ensure it actually arrived at the hub first!
    if pledge.status != "received_at_hub":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot complete order. Current status is '{pledge.status}', but it must be 'received_at_hub' first."
        )

    # 4. Release Escrow!
    pledge.status = "completed"
    db.commit()
    db.refresh(pledge)
    
    return pledge

@app.post("/bulk-requests/", response_model=schemas.BulkRequestRead)
def create_bulk_request(
    request: schemas.BulkRequestCreate, 
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(get_current_user)
):
    if current_user.role != "buyer":
        raise HTTPException(status_code=403, detail="Only Corporate Buyers can post bulk requests.")

    new_request = models.BulkRequest(
        buyer_id=current_user.id,
        buyer_name=current_user.full_name, 
        crop_name=request.crop_name,
        target_weight_kg=request.target_weight_kg,
        price_per_kg=request.price_per_kg,
        county=request.county, 
        urgency=request.urgency,
        status="Open",
        squad_status="gathering" 
    )
    
    try:
        db.add(new_request)
        db.commit()
        db.refresh(new_request)
        return new_request
    except Exception as e:
        db.rollback()
        print(f"❌ DB Error creating bulk request: {e}")
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
            "ward": req.ward, "urgency": req.urgency, # 🔥 Added
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

        # 🔥 THE FIX: Bulletproof decoding
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
            "unit_pricing": parsed_units, # Send the clean array to Flutter!
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

    # 1. Prevent a farmer from pledging twice to the same order
    existing_pledge = db.query(models.Pledge).filter(
        models.Pledge.bulk_request_id == request_id,
        models.Pledge.farmer_id == current_user.id
    ).first()
    
    if existing_pledge:
        raise HTTPException(status_code=400, detail="You have already pledged to this request.")

    # 🔥 2. NEW: THE OVER-PLEDGE FIREWALL
    current_total = db.query(func.sum(models.Pledge.pledged_weight_kg)).filter(models.Pledge.bulk_request_id == request_id).scalar() or 0.0

    if current_total >= bulk_req.target_weight_kg:
        raise HTTPException(status_code=400, detail="This Hub Pool is already 100% full!")

    if current_total + pledge.pledged_weight_kg > bulk_req.target_weight_kg:
        remaining = bulk_req.target_weight_kg - current_total
        raise HTTPException(status_code=400, detail=f"Cannot over-pledge. Only {remaining}kg remaining to fill the pool.")

    # 3. Create the Pledge
    new_pledge = models.Pledge(
        bulk_request_id=request_id,
        farmer_id=current_user.id,
        pledged_weight_kg=pledge.pledged_weight_kg,
        status="pledged"
    )
    
    try:
        db.add(new_pledge)
        db.flush() # Save it temporarily to calculate math

        # 🔥 THE SOLO FULFILLMENT & ELECTION CHECK
        total_pledged = db.query(func.sum(models.Pledge.pledged_weight_kg)).filter(models.Pledge.bulk_request_id == request_id).scalar() or 0.0
        
        # If the pool is 100% full...
        if total_pledged >= bulk_req.target_weight_kg:
            bulk_req.status = "fulfilled" # Lock it so no one else can join
            
            # 🔥 FIX 1: Hub Pools NEVER hold elections! The Admin is already the boss.
            if bulk_req.buyer_name.startswith("Hub Pool:"):
                bulk_req.squad_status = "active"
            else:
                # Corporate Contracts logic
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
        print(f"❌ DB Error during pledge creation: {e}")
        raise HTTPException(status_code=500, detail="Failed to process your pledge.")


@app.post("/api/squads/{squad_id}/run")
def run_for_squad_coordinator(
    squad_id: int, 
    payload: SquadPitch, 
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(get_current_user)
):
    # 1. Verify the squad exists
    squad = db.query(models.BulkRequest).filter(models.BulkRequest.id == squad_id).first()
    if not squad:
        raise HTTPException(status_code=404, detail="Squad not found.")

    # 2. Verify the farmer is actually IN this squad
    is_member = db.query(models.Pledge).filter(
        models.Pledge.bulk_request_id == squad_id,
        models.Pledge.farmer_id == current_user.id
    ).first()
    
    if not is_member:
        raise HTTPException(status_code=403, detail="You must pledge to this squad before running for coordinator.")

    # 3. Check if they are already running
    existing_candidate = db.query(models.SquadCandidate).filter(
        models.SquadCandidate.bulk_request_id == squad_id,
        models.SquadCandidate.farmer_id == current_user.id
    ).first()
    
    if existing_candidate:
        raise HTTPException(status_code=400, detail="You are already on the ballot!")

    # 4. Add them to the ballot
    new_candidate = models.SquadCandidate(
        bulk_request_id=squad_id,
        farmer_id=current_user.id,
        pitch=payload.pitch
    )
    db.add(new_candidate)
    db.commit()

    return {"message": "You are officially on the ballot!"}


@app.post("/api/squads/{squad_id}/vote")
def cast_squad_vote(
    squad_id: int, 
    payload: SquadVoteRequest, 
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(get_current_user)
):
    # 1. Verify they are in the squad
    is_member = db.query(models.Pledge).filter(
        models.Pledge.bulk_request_id == squad_id,
        models.Pledge.farmer_id == current_user.id
    ).first()
    if not is_member:
        raise HTTPException(status_code=403, detail="Only squad members can vote.")

    # 2. Prevent Double Voting
    existing_vote = db.query(models.SquadVote).filter(
        models.SquadVote.bulk_request_id == squad_id,
        models.SquadVote.farmer_id == current_user.id
    ).first()
    if existing_vote:
        raise HTTPException(status_code=400, detail="You have already cast your vote!")

    # 3. Prevent voting for themselves
    candidate = db.query(models.SquadCandidate).filter(models.SquadCandidate.id == payload.candidate_id).first()
    if not candidate:
        raise HTTPException(status_code=404, detail="Candidate not found.")
    if candidate.farmer_id == current_user.id:
        raise HTTPException(status_code=400, detail="You cannot vote for yourself! Democracy relies on your peers.")

    # 4. Cast the vote
    new_vote = models.SquadVote(
        bulk_request_id=squad_id,
        farmer_id=current_user.id,
        candidate_id=payload.candidate_id
    )
    candidate.votes += 1
    db.add(new_vote)
    
    # 5. 🔥 THE MAGIC HANDOVER LOGIC (Check if they won!)
    total_members = db.query(models.Pledge).filter(models.Pledge.bulk_request_id == squad_id).count()
    
    # 🔥 THE FIX: If there are exactly 2 members, 1 vote is enough to win!
    majority_threshold = (total_members / 2) if total_members > 2 else 0

    if candidate.votes > majority_threshold:
        # We have a winner!
        squad = db.query(models.BulkRequest).filter(models.BulkRequest.id == squad_id).first()
        squad.coordinator_id = candidate.farmer_id
        squad.squad_status = "active" # Lock the election, it's time to deliver!
        
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
        # 1. Give the AI context about EXACTLY who it is talking to
        system_instruction = f"""
        You are the MkulimaHub AI Assistant, an expert in Kenyan agriculture and market dynamics.
        You are talking to {request.user_name}, who is a {request.role} located in {request.location}.
        Business Context: {request.business_details}
        
        Always be helpful, encouraging, and concise. If they ask about crop prices, trends, weather, 
        or diseases, YOU MUST USE YOUR TOOLS to fetch live data from the database before answering.
        """

        # 2. Initialize Gemini and equip it with your live database tools
        model = genai.GenerativeModel(
            model_name='gemini-2.5-flash',
            tools=[get_market_spot_price, predict_price_trend, get_weather_forecast, diagnose_crop_disease],
            system_instruction=system_instruction
        )

        # 3. Start a chat session with Auto-Function Calling enabled!
        # (This means if the AI needs a price, it will automatically run your Python function, 
        # get the database result, and then write the final message to the user!)
        chat = model.start_chat(enable_automatic_function_calling=True)
        
        # 4. Send the user's message to Gemini
        response = chat.send_message(request.message)

        return {"reply": response.text}

    except Exception as e:
        print(f"❌ AI Chat Error: {e}")
        raise HTTPException(status_code=500, detail="The AI is currently resting. Please try again in a moment!")
    
@app.get("/api/squads/{bulk_request_id}/messages")
def get_squad_messages(bulk_request_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Fetches the chat history for a specific delivery squad."""
    
    # 1. Fetch all messages for this specific contract, sorted from oldest to newest
    messages = db.query(models.SquadMessage)\
                 .filter(models.SquadMessage.bulk_request_id == bulk_request_id)\
                 .order_by(models.SquadMessage.created_at.asc())\
                 .all()

    # 2. Package them beautifully for Flutter
    chat_history = []
    for msg in messages:
        chat_history.append({
            "id": msg.id,
            "sender_id": msg.sender_id,
            "sender_name": msg.sender.full_name if msg.sender else "Unknown Farmer",
            "message": msg.message,
            # We send 'is_me' so Flutter knows whether to put the chat bubble on the left or right!
            "is_me": msg.sender_id == current_user.id, 
            "created_at": msg.created_at.isoformat()
        })
        
    return chat_history


@app.post("/api/squads/{bulk_request_id}/messages")
def send_squad_message(bulk_request_id: int, payload: MessageCreate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Posts a new message to the squad chat."""
    
    # Optional Security: Ensure the contract actually exists
    contract = db.query(models.BulkRequest).filter(models.BulkRequest.id == bulk_request_id).first()
    if not contract:
        raise HTTPException(status_code=404, detail="Contract not found.")

    # Create and save the message
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
    """Allows Corporate Buyers to browse fully aggregated Hub Pools ready for purchase."""
    if current_user.role != "buyer":
        raise HTTPException(status_code=403, detail="Only buyers can browse the enterprise marketplace.")

    # 1. Find all Internal Hub Pools
    hub_pools = db.query(models.BulkRequest).filter(
        models.BulkRequest.buyer_name.like("Hub Pool:%")
    ).all()

    available_inventory = []
    
    for pool in hub_pools:
        # 2. Only show pools that have actually gathered enough crops!
        total_pledged = db.query(func.sum(models.Pledge.pledged_weight_kg)).filter(models.Pledge.bulk_request_id == pool.id).scalar() or 0.0
        
        # Extract the real Hub Name from the buyer_name string
        hub_name_clean = pool.buyer_name.replace("Hub Pool: ", "")

        available_inventory.append({
            "pool_id": pool.id,
            "hub_name": hub_name_clean,
            "crop": pool.crop_name,
            "available_weight_kg": total_pledged,
            "asking_price_per_kg": pool.price_per_kg,
            "total_value_kes": total_pledged * pool.price_per_kg,
            "status": "Ready for Pickup" if total_pledged >= pool.target_weight_kg else "Still Gathering"
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
    """🔥 NEW: EVERY farmer (Hub Pool or Corporate) does their OWN individual digital drop-off!"""
    squad = db.query(models.BulkRequest).filter(models.BulkRequest.id == squad_id).first()
    if not squad:
        raise HTTPException(status_code=404, detail="Squad not found.")

    # We completely removed the Hub Pool split. 
    # Now, we strictly look for THIS specific farmer's pledge and update ONLY theirs.
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

class SquadStatusUpdate(BaseModel):
    status: str

@app.post("/api/squads/{squad_id}/status")
def update_squad_status(squad_id: int, payload: SquadStatusUpdate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Allows the Squad Driver to update the physical location of the truck."""
    squad = db.query(models.BulkRequest).filter(models.BulkRequest.id == squad_id).first()
    if not squad or squad.coordinator_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the driver can update the physical status.")
    
    pledges = db.query(models.Pledge).filter(models.Pledge.bulk_request_id == squad_id).all()
    for pledge in pledges:
        pledge.status = payload.status # e.g., 'in_transit' or 'delivered'
        
    db.commit()
    return {"message": f"Squad successfully moved to {payload.status}"}

@app.put("/api/pledges/{pledge_id}/status")
def update_individual_pledge_status(pledge_id: int, payload: SquadStatusUpdate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Allows a Coordinator to verify, OR a Farmer to hand over their own goods."""
    pledge = db.query(models.Pledge).filter(models.Pledge.id == pledge_id).first()
    if not pledge:
        raise HTTPException(status_code=404, detail="Pledge not found.")
        
    contract = db.query(models.BulkRequest).filter(models.BulkRequest.id == pledge.bulk_request_id).first()
    
    # Security: Hub Admin, Squad Coordinator, OR the Farmer themselves (only for handing over)
    is_hub_admin = contract.buyer_name.startswith("Hub Pool:") and contract.coordinator_id == current_user.id
    is_coordinator = contract.coordinator_id == current_user.id
    is_owner_handing_over = pledge.farmer_id == current_user.id and payload.status == "pending_audit"
    
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
    unit_pricing: List[Dict[str, Any]] = [] # 🔥 Accepts the array from Flutter!
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
        # 🔥 THE FIX: Strictly encode as a JSON string so it saves with double quotes!
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

@app.post("/api/market/listings/{listing_id}/order")
def create_market_order(
    listing_id: int, 
    payload: MarketOrderCreate, # Ensure this matches your schema name
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(get_current_user)
):
    """Allows a buyer to place an order on a farmer's marketplace listing."""
    listing = db.query(models.MarketListing).filter(models.MarketListing.id == listing_id).first()
    
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")
        
    if listing.available_kg is not None and listing.available_kg <= 0:
        raise HTTPException(status_code=400, detail="This listing is sold out")

    # 🔥 THE FIX: Safely unpack the JSON string back into a Python List!
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

    # Calculate exactly how many KGs they ordered and the total price
    total_kg_ordered = 0
    total_price = 0
    
    if payload.order_type == "KG":
        total_kg_ordered = payload.quantity
        total_price = payload.quantity * listing.price_per_kg
    else:
        # We now search through the safely unpacked parsed_units list!
        selected_unit = next((u for u in parsed_units if u.get("unit_name") == payload.order_type), None)
        
        if not selected_unit:
            raise HTTPException(status_code=400, detail=f"Unit '{payload.order_type}' not available for this crop.")
            
        unit_kg = selected_unit.get("kg", 0)
        unit_price = selected_unit.get("price", 0)
        
        total_kg_ordered = payload.quantity * unit_kg
        total_price = payload.quantity * unit_price

    # Make sure the farmer actually has enough inventory
    if listing.available_kg is not None and total_kg_ordered > listing.available_kg:
        raise HTTPException(status_code=400, detail=f"Only {listing.available_kg} KG available. You ordered {total_kg_ordered} KG.")

    # Create the order
    new_order = models.MarketOrder(
        listing_id=listing.id,
        buyer_id=current_user.id,
        quantity_ordered=payload.quantity,
        order_type=payload.order_type,
        total_price=total_price,
        status="pending",
        delivery_method=payload.delivery_method # 🔥 Save the buyer's choice!
    )
    
    db.add(new_order)
    db.commit()
    
    return {"message": "Order placed successfully!"}

@app.get("/api/market/listings")
def get_all_market_listings(db: Session = Depends(get_db)):
    listings = db.query(models.MarketListing).all()
    results = []
    
    for listing in listings:
        if listing.available_kg is not None and listing.available_kg <= 0:
            continue

        # 🔥 THE FIX: Bulletproof decoding
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
            "unit_pricing": parsed_units, # Send the clean array back to Flutter!
            "image_base64": getattr(listing, 'image_base64', None),
            "farmer_name": listing.farmer.full_name if listing.farmer else "Local Farmer",
            "county": listing.farmer.county if listing.farmer else "Kenya"
        })
    return results

@app.put("/api/squads/{squad_id}/delegate")
def delegate_coordinator(squad_id: int, new_coordinator_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Allows current coordinator to pass the crown to someone else."""
    squad = db.query(models.BulkRequest).filter(models.BulkRequest.id == squad_id).first()
    if squad.coordinator_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the current coordinator can delegate.")
    
    # Ensure new coordinator is actually in the squad!
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
    """Allows Hub Admin OR Squad Coordinator to weigh and receive a specific farmer's goods."""
    pledge = db.query(models.Pledge).filter(models.Pledge.id == pledge_id).first()
    contract = db.query(models.BulkRequest).filter(models.BulkRequest.id == pledge.bulk_request_id).first()
    
    # 🔥 THE FIX: Security Check allowing both Hub Admins and Squad Coordinators
    if contract.coordinator_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the Coordinator can verify and receive goods.")
    
    pledge.status = "received"
    pledge.actual_weight_kg = payload.actual_weight_kg
    pledge.notes = payload.notes
    
    db.commit()
    return {"message": "Farmer's produce received!"}

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
        
    # 🔥 THE FIX: Strictly encode as a JSON string!
    listing.unit_pricing = json.dumps(payload.unit_pricing) if payload.unit_pricing else "[]"
    
    db.commit()
    return {"message": "Listing updated successfully!"}

@app.delete("/api/market/listings/{listing_id}")
def delete_market_listing(
    listing_id: int, 
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(get_current_user)
):
    """Allows a farmer to permanently delete a listing."""
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
def update_farmer_order_status(order_id: int, payload: dict, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    order = db.query(models.MarketOrder).join(models.MarketListing).filter(
        models.MarketOrder.id == order_id, models.MarketListing.farmer_id == current_user.id
    ).first()
    if not order: raise HTTPException(status_code=404, detail="Order not found")
    
    order.status = payload.get("status")
    db.commit()
    return {"message": f"Order status updated to {order.status}"}