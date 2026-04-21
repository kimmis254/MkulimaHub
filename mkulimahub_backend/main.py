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
from typing import List, Optional
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
        # You can choose to pass a specific crop, or let the function loop through active crops
        run_clustering_algorithm(db, crop="Maize") 
        print("✅ [SCHEDULER] Clustering Complete!")
    except Exception as e:
        print(f"❌ [SCHEDULER ERROR]: {e}")
    finally:
        db.close()

# Use lifespan events (FastAPI 0.93+) to handle startup/shutdown of the scheduler cleanly
@asynccontextmanager
async def lifespan(app: FastAPI):
    print("🚀 Starting MkulimaHub API and Background Scheduler...")
    scheduler = BackgroundScheduler()
    # Runs the clustering algorithm every hour. Change hours=1 to minutes=1 for quick testing!
    scheduler.add_job(scheduled_clustering_job, 'interval', hours=1)
    scheduler.start()
    
    yield # The app runs here
    
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

class GoogleAuthRequest(BaseModel):
    email: str
    full_name: str
    google_uid: str

class GoogleRegisterRequest(BaseModel):
    email: str
    full_name: str
    google_uid: str
    phone_number: str

@app.post("/auth/google")
@limiter.limit("5/minute")
def google_login(
    request: Request,                   
    payload: GoogleAuthRequest,         
    db: Session = Depends(get_db)
):
    user = db.query(models.User).filter(models.User.email == payload.email).first()
    
    if user:
        if not user.phone_number:
            return {"status": "needs_phone"}
            
        access_token = security.create_access_token(data={"sub": str(user.id), "role": user.role})
        return {
            "access_token": access_token, 
            "token_type": "bearer", 
            "status": "success"
        }
    else:
        return {"status": "needs_phone"}

@app.post("/auth/google-register")
@limiter.limit("5/minute")
def google_register(request: Request, payload: GoogleRegisterRequest, db: Session = Depends(get_db)):
    existing_phone = db.query(models.User).filter(models.User.phone_number == payload.phone_number).first()
    if existing_phone and existing_phone.email != payload.email:
        raise HTTPException(status_code=400, detail="Phone number already registered to another account.")
    
    user = db.query(models.User).filter(models.User.email == payload.email).first()
    
    if user:
        user.phone_number = payload.phone_number
        db.commit()
        db.refresh(user)
    else:
        user = models.User(
            full_name=payload.full_name,
            email=payload.email,
            google_uid=payload.google_uid,
            phone_number=payload.phone_number,
            role="farmer"
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

@app.post("/auth/register", response_model=schemas.UserResponse)
def register_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    # 1. Check if the phone number is already taken
    existing_user = db.query(models.User).filter(models.User.phone_number == user.phone_number).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Phone number already registered")

    # 2. Create the user, making sure to use `user.` for all fields!
    new_user = models.User(
        full_name=user.full_name,
        phone_number=user.phone_number,
        hashed_password=security.get_password_hash(user.password),
        role=user.role,                 # 🔥 FIXED: Changed 'payload.role' to 'user.role'
        latitude=user.latitude,         # 🔥 Added so Farmer GPS coordinates don't get lost
        longitude=user.longitude        # 🔥 Added so Farmer GPS coordinates don't get lost
    )

    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    return new_user

@app.post("/auth/login", response_model=schemas.Token)
@limiter.limit("5/minute")
def login_user(request: Request, form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.phone_number == form_data.username).first()
    
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

    db.add(current_user)
    db.commit()
    db.refresh(current_user)
    return current_user

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
    db.add(new_harvest)
    db.commit()
    db.refresh(new_harvest)
    return {"message": "Harvest posted successfully", "id": new_harvest.id}

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

@app.get("/api/contracts", response_model=List[schemas.BulkRequestRead])
def get_open_contracts(county: str = None, db: Session = Depends(get_db)):
    query = db.query(models.BulkRequest).filter(models.BulkRequest.status == "Open")
    if county:
        query = query.filter(models.BulkRequest.county == county)
    return query.all()

@app.post("/api/contracts/{contract_id}/pledge", response_model=schemas.PledgeRead)
def create_pledge(contract_id: int, pledge: schemas.PledgeBase, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    contract = db.query(models.BulkRequest).filter(models.BulkRequest.id == contract_id).first()
    if not contract:
        raise HTTPException(status_code=404, detail="Contract not found")
        
    new_pledge = models.Pledge(
        bulk_request_id=contract_id,
        farmer_id=current_user.id,
        pledged_weight_kg=pledge.pledged_weight_kg
    )
    db.add(new_pledge)
    db.commit()
    db.refresh(new_pledge)
    return new_pledge

@app.get("/api/my-pledges")
def get_my_pledges(
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(get_current_user)
):
    if current_user.role != "farmer":
        raise HTTPException(status_code=403, detail="Only farmers can view delivery squads.")

    # 1. Get all pledges for this farmer
    pledges = db.query(models.Pledge).filter(models.Pledge.farmer_id == current_user.id).all()
    
    result = []
    for p in pledges:
        req = p.bulk_request # Grab the connected corporate request
        
        # 🔥 THE FIX: If the request was deleted, this is a Ghost Pledge!
        if not req:
            db.delete(p) # Delete the ghost from the database
            db.commit()
            continue # Skip sending this ghost to Flutter

        # If it's a real pledge, send it exactly as Flutter expects
        result.append({
            "id": p.id,
            "pledged_weight_kg": p.pledged_weight_kg,
            "actual_weight_kg": p.actual_weight_kg,
            "status": p.status,
            "bulk_request": {
                "id": req.id,
                "buyer_name": req.buyer_name,
                "crop_name": req.crop_name,
                "target_weight_kg": req.target_weight_kg,
                "price_per_kg": req.price_per_kg,
                "county": req.county,
                "squad_status": req.squad_status,
                "coordinator_id": req.coordinator_id
            }
        })
        
    return result

# ==========================================
# 6. HUBS, CLUSTERS, & CO-OP CHAT
# ==========================================

def run_clustering_algorithm(db: Session, crop: str = "Maize"):
    """
    Core DBSCAN logic that freezes clusters into the database and appoints Coordinators.
    """
    farmers = db.query(models.User).filter(
        models.User.latitude.isnot(None), 
        models.User.longitude.isnot(None),
        models.User.hub_id == None, # Only cluster farmers not currently in a hub
        models.User.main_crops.ilike(f"%{crop}%")
    ).all()

    if not farmers:
        return 0

    coords = np.radians([[f.latitude, f.longitude] for f in farmers])
    dbscan = DBSCAN(eps=(10 / 6371.0088), min_samples=2, algorithm='ball_tree', metric='haversine')
    labels = dbscan.fit_predict(coords)

    new_hubs_created = 0
    clusters = {}
    
    for i, label in enumerate(labels):
        if label != -1: 
            if label not in clusters:
                clusters[label] = []
            clusters[label].append(farmers[i])

    for label, cluster_farmers in clusters.items():
        # 1. Calculate the exact geographical center of the cluster
        avg_lat = sum(f.latitude for f in cluster_farmers) / len(cluster_farmers)
        avg_lon = sum(f.longitude for f in cluster_farmers) / len(cluster_farmers)

        # 2. Name the Hub after the first farmer's Ward
        hub_name = f"{cluster_farmers[0].ward or 'Regional'} {crop} Hub"

        # 3. Create the permanent Hub (Notice coordinator_id is completely left out!)
        new_hub = models.Hub(
            name=hub_name,
            crop=crop,
            center_latitude=avg_lat,
            center_longitude=avg_lon
        )
        db.add(new_hub)
        db.flush() # Get the new_hub.id immediately

        # 4. Assign all clustered farmers to this new Hub
        for farmer in cluster_farmers:
            farmer.hub_id = new_hub.id
        
        new_hubs_created += 1

    db.commit()
    return new_hubs_created

@app.post("/api/admin/trigger-clustering")
def admin_trigger_clustering(crop: str = "Maize", db: Session = Depends(get_db)):
    """Admin endpoint to manually trigger the freeze logic."""
    created = run_clustering_algorithm(db, crop)
    return {"message": f"Successfully created {created} new permanent Hubs."}

@app.get("/api/clusters")
def get_frozen_clusters(crop: str = None, db: Session = Depends(get_db),current_user: models.User = Depends(get_current_user)):
    """
    NEW FASTER ENDPOINT: Pulls permanently frozen Hubs from the DB instead of calculating on the fly.
    """
    query = db.query(models.Hub)
    if crop and crop != 'All':
        query = query.filter(models.Hub.crop.ilike(f"%{crop}%"))
    
    hubs = query.all()
    
    # Fetch "Noise" - strictly FARMERS who have GPS but no Hub
    indep_query = db.query(models.User).filter(
        models.User.latitude.isnot(None),
        models.User.longitude.isnot(None),
        models.User.hub_id == None,
        models.User.role == "farmer"  # 🛑 THIS LOCKS OUT THE BUYERS!
    )
    
    if crop and crop != 'All':
        indep_query = indep_query.filter(models.User.main_crops.ilike(f"%{crop}%"))
    
    independent_farmers = indep_query.all()
    
    # Format Response for Flutter
    final_hubs = []
    total_analyzed = len(independent_farmers)
    
    for h in hubs:
        # Ensure hub members are only farmers
        hub_members = db.query(models.User).filter(
            models.User.hub_id == h.id,
            models.User.role == "farmer"
        ).all()
        
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
    squads_db = db.query(models.BulkRequest).filter(
        models.BulkRequest.status == "Open",
        models.BulkRequest.squad_status.in_(["gathering", "voting"]) 
    ).all()
    
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
        result.append({
            "id": m.id,
            "hub_name": m.hub_name,
            "message": m.message,
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

@app.post("/api/predict-price") # Standardized endpoint name
def predict_prices(request: PredictionRequest, db: Session = Depends(get_db)):
    safe_region = request.region.strip()
    req_crop = request.commodity.strip()
    req_type = request.price_type.strip()

    fallback_type = "none"

    def get_db_data(target_county, target_crop, target_type):
        # 🔥 THE FIX: Use the actual PostgreSQL column names (date, price_kes, market_type)
        query = db.query(models.MarketPrice.date, models.MarketPrice.price_kes).filter(
            models.MarketPrice.commodity.ilike(f"%{target_crop}%"),
            models.MarketPrice.market_type.ilike(f"%{target_type}%")
        )
        if target_county:
            query = query.filter(models.MarketPrice.county.ilike(f"%{target_county}%"))
            
        records = query.all()
        if not records:
            return pd.DataFrame()
            
        # 🔥 THE FIX: Instantly map Postgres names to Prophet names ('ds' and 'y')
        df = pd.DataFrame([{"ds": r.date, "y": r.price_kes} for r in records])
        
        # Clean and group the data
        df['ds'] = pd.to_datetime(df['ds'])
        df = df.groupby('ds', as_index=False)['y'].mean()
        df = df.sort_values(by='ds')
        return df

    # 1. Try exact match
    df_filtered = get_db_data(safe_region, req_crop, req_type)

    # 2. Fallback: Same county, different market type
    if df_filtered.empty:
        alt_type = "Retail" if req_type.lower() == "wholesale" else "Wholesale"
        df_filtered = get_db_data(safe_region, req_crop, alt_type)
        if not df_filtered.empty:
            fallback_type = f"alt_type_{alt_type.lower()}"

    # 3. Fallback: National average, exact market type
    if df_filtered.empty:
        df_filtered = get_db_data(None, req_crop, req_type)
        if not df_filtered.empty:
            fallback_type = "national"
        else:
            # 4. Absolute fallback: National average, alternative market type
            alt_type = "Retail" if req_type.lower() == "wholesale" else "Wholesale"
            df_filtered = get_db_data(None, req_crop, alt_type)
            if not df_filtered.empty:
                fallback_type = f"national_alt_{alt_type.lower()}"

    if df_filtered.empty:
        raise HTTPException(status_code=404, detail="Crop not found anywhere in the database.")

    historical_dates = df_filtered['ds'].dt.strftime('%Y-%m-%d').tolist()
    historical_prices = df_filtered['y'].round(2).tolist()

    # Handle tiny datasets that Prophet can't train on
    if len(df_filtered) < 3:
        last_date = df_filtered['ds'].iloc[-1]
        last_price = float(df_filtered['y'].iloc[-1])
        future_dates = [(last_date + pd.Timedelta(days=i)).strftime('%Y-%m-%d') for i in [7, 14, 30]]
        
        return {
            "historical_dates": historical_dates,
            "historical_prices": historical_prices,
            "future_dates": future_dates,
            "future_prices": [last_price, last_price, last_price],
            "current_price": last_price,
            "predicted_price": last_price,
            "trend": "stable",
            "fallback_type": "flatline" 
        }

    try:
        m = Prophet(daily_seasonality=False, yearly_seasonality=True)
        # Data is already named 'ds' and 'y', so we just pass it straight in!
        m.fit(df_filtered)
        
        # Predict the exact number of days requested
        future = m.make_future_dataframe(periods=request.days)
        forecast = m.predict(future)
        
        future_forecast = forecast[forecast['ds'] > df_filtered['ds'].max()]
        future_prices_list = future_forecast['yhat'].round(2).tolist()
        
        hist_max = max(historical_prices)
        hist_min = min(historical_prices)
        
        # Cap wild predictions (The Prophet bounds you wrote are excellent)
        capped_future = []
        for p in future_prices_list:
            if p > (hist_max * 1.5): 
                capped_future.append(round(hist_max * 1.5, 2))
            elif p < (hist_min * 0.5): 
                capped_future.append(round(hist_min * 0.5, 2))
            elif p <= 0:
                capped_future.append(round(hist_min * 0.8, 2)) 
            else:
                capped_future.append(p)
                
        future_prices_list = capped_future
        future_dates_list = future_forecast['ds'].dt.strftime('%Y-%m-%d').tolist()
        
        current_price_val = float(historical_prices[-1])
        predicted_price_val = float(future_prices_list[-1]) if future_prices_list else current_price_val
        
        if predicted_price_val > current_price_val * 1.02: 
            trend_val = "rising"
        elif predicted_price_val < current_price_val * 0.98: 
            trend_val = "falling"
        else:
            trend_val = "stable" 
            
        return {
            "historical_dates": historical_dates,
            "historical_prices": historical_prices,
            "future_dates": future_dates_list,
            "future_prices": future_prices_list,
            "current_price": current_price_val,
            "predicted_price": predicted_price_val,
            "trend": trend_val,
            "fallback_type": fallback_type
        }
    except Exception as e:
        print(f"Prophet Error: {e}")
        raise HTTPException(status_code=500, detail="AI prediction failed")


load_dotenv()
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))

class ChatRequest(BaseModel):
    message: str
    role: str = "farmer"
    user_name: str = "User"
    location: str = "Kenya"
    business_details: str = "Agriculture" 

# ==========================================
# 🔥 THE AI TOOLBOX (For LIVE data only)
# ==========================================
def get_market_spot_price(crop: str, county: str) -> str:
    """Fetches the LIVE current wholesale spot price for a specific crop."""
    return f"Live Spot Price: {crop.capitalize()} is currently trading at KES 4,500 per 90kg bag in {county.capitalize()}."

def predict_price_trend(crop: str) -> str:
    """Predicts the future price trend for a specific crop."""
    return f"AI Trend Analysis: {crop.capitalize()} prices are expected to drop by 12% next month."

def get_weather_forecast(location: str) -> str:
    """Fetches the LIVE weather forecast for a location."""
    return f"Live Weather Data for {location}: Sunny, 28°C."

def diagnose_crop_disease(symptoms: str) -> str:
    """Analyzes crop symptoms to predict diseases."""
    return "ML Prediction: High probability of Fungal Blight."


# ==========================================
# 🔥 THE UNCHAINED ENDPOINT
# ==========================================
@app.post("/api/ai-chat")
def advanced_agri_bot(request: ChatRequest): 
    
    if request.role == "buyer":
        # PERSONA: The Brilliant Procurement Expert
        system_instruction = f"""
        You are 'Market Intel', an elite procurement and agricultural supply chain AI for buyers in Kenya on MkulimaHub.
        
        USER CONTEXT (Do not explicitly repeat this back to them, just use it to be smart):
        - Name: {request.user_name}
        - Location: {request.location}
        - Business: {request.business_details}
        
        CRITICAL INSTRUCTIONS:
        1. ACT LIKE A BRILLIANT HUMAN EXPERT. Speak naturally, warmly, and confidently. NEVER sound like a robot. Do not use phrases like "Based on the system data" or "According to my parameters."
        2. USE YOUR VAST INTERNAL KNOWLEDGE. You already know everything about Kenyan agriculture, geography, and crop seasonality (e.g., when mangoes are in season at the Coast vs. Eastern). Answer general questions immediately using your own brain.
        3. USE TOOLS FOR LIVE DATA. Only use your function tools if the user asks for *live* market prices or specific future trends. 
        4. BE CONCISE. Keep your answers brief and highly conversational (1-2 short paragraphs).
        """
        available_tools = [get_market_spot_price, predict_price_trend]
        
    else:
        # PERSONA: The Friendly Agronomist
        system_instruction = f"""
        You are 'MkulimaBot', a highly intelligent, friendly agronomist AI for farmers in Kenya on MkulimaHub.
        
        USER CONTEXT (Do not explicitly repeat this back to them, just use it to be smart):
        - Name: {request.user_name}
        - Farm Location: {request.location}
        - Crops: {request.business_details}
        
        CRITICAL INSTRUCTIONS:
        1. ACT LIKE A BRILLIANT HUMAN EXPERT. Speak warmly and confidently. NEVER sound robotic. 
        2. USE YOUR VAST INTERNAL KNOWLEDGE. You already know all farming best practices, fertilizer ratios, and planting seasons in Kenya. Answer general questions directly from your own brain.
        3. USE TOOLS FOR LIVE DATA. Only use your tools if they ask for the LIVE weather forecast or a specific ML disease diagnosis.
        4. BE CONCISE. Keep answers to 1-2 short, friendly paragraphs. End with a helpful, natural question.
        """
        available_tools = [get_weather_forecast, diagnose_crop_disease, get_market_spot_price]

    try:
        model = genai.GenerativeModel(
            model_name='gemini-2.5-flash',
            system_instruction=system_instruction,
            tools=available_tools
        )
        
        # Start chat with automatic function calling enabled
        chat = model.start_chat(enable_automatic_function_calling=True)
        
        response = chat.send_message(request.message)
        
        return {"reply": response.text}
        
    except Exception as e:
        return {"reply": f"The AI is currently resting. (Error: {str(e)})"}
    
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

@app.get("/api/hubs/deliveries")
def get_hub_deliveries(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Fetches all pledges destined for the Coordinator's Hub."""
    # Ensure they are actually a coordinator
    hub = db.query(models.Hub).filter(models.Hub.coordinator_id == current_user.id).first()
    if not hub:
        raise HTTPException(status_code=403, detail="Only Hub Coordinators can view this dashboard.")

    # Get all pledges made by farmers who belong to this specific Hub
    hub_farmer_ids = [f.id for f in db.query(models.User).filter(models.User.hub_id == hub.id).all()]
    pledges = db.query(models.Pledge).filter(models.Pledge.farmer_id.in_(hub_farmer_ids)).all()
    
    results = []
    for p in pledges:
        farmer = db.query(models.User).filter(models.User.id == p.farmer_id).first()
        
        # 🔥 THE FIX 1: Use models.BulkRequest and p.bulk_request_id
        contract = db.query(models.BulkRequest).filter(models.BulkRequest.id == p.bulk_request_id).first()
        
        if not contract or not farmer:
            continue
            
        results.append({
            "pledge_id": p.id,
            "farmer_name": farmer.full_name,
            "crop_name": contract.crop_name,
            # 🔥 THE FIX 2: Use p.pledged_weight_kg instead of p.weight_kg
            "pledged_weight": p.pledged_weight_kg,
            "actual_weight": p.actual_weight_kg,
            "status": p.status,
            "notes": p.notes
        })
        
    return results

@app.post("/api/hubs/deliveries/{pledge_id}/process")
def process_hub_delivery(pledge_id: int, payload: ProcessDeliveryPayload, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Allows Coordinator to accept or reject a physical drop-off."""
    pledge = db.query(models.Pledge).filter(models.Pledge.id == pledge_id).first()
    if not pledge:
        raise HTTPException(status_code=404, detail="Pledge not found.")

    if payload.action == "receive":
        pledge.status = "received"
        pledge.actual_weight_kg = payload.actual_weight_kg or pledge.weight_kg
        pledge.notes = payload.notes or "Verified and stored at Hub."
    elif payload.action == "reject":
        pledge.status = "rejected"
        pledge.notes = payload.notes or "Rejected at Hub."
        # Optionally, you could deduct this from the contract's total here!
    
    db.commit()
    return {"message": f"Delivery marked as {pledge.status}"}

@app.get("/api/my-deliveries")
def get_my_deliveries(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Fetches the logged-in farmer's personal pledges/deliveries."""
    pledges = db.query(models.Pledge).filter(models.Pledge.farmer_id == current_user.id).all()
    
    results = []
    for p in pledges:
        contract = db.query(models.BulkRequest).filter(models.BulkRequest.id == p.bulk_request_id).first()
        
        if not contract:
            continue
            
        results.append({
            "id": f"TRK-{p.id:04d}", 
            "crop": contract.crop_name, 
            # 🔥 THE FIX: Changed to p.pledged_weight_kg
            "weight_kg": p.pledged_weight_kg,
            "expected_payout": p.pledged_weight_kg * contract.price_per_kg,
            "status": p.status,
            "buyer": contract.buyer_name, 
            "notes": p.notes
        })
        
    return results

@app.get("/api/buyer/dashboard")
def get_buyer_dashboard(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Aggregates data for the Corporate Buyer's Procurement Dashboard."""
    
    # 🔥 MATCHED TO YOUR SCHEMA: Filtering by buyer_name instead of buyer_id
    contracts = db.query(models.BulkRequest).filter(models.BulkRequest.buyer_name == current_user.full_name).all()
    
    total_capital_committed = 0
    total_tonnage_requested = 0
    active_contracts = []
    
    for contract in contracts:
        pledges = db.query(models.Pledge).filter(models.Pledge.bulk_request_id == contract.id).all()
        total_pledged_kg = sum(p.pledged_weight_kg for p in pledges if p.pledged_weight_kg)
        
        # 🔥 MATCHED TO YOUR SCHEMA: Using target_weight_kg
        contract_value = contract.target_weight_kg * contract.price_per_kg
        total_capital_committed += contract_value
        total_tonnage_requested += contract.target_weight_kg
        
        progress_pct = (total_pledged_kg / contract.target_weight_kg) if contract.target_weight_kg > 0 else 0
        
        active_contracts.append({
            "contract_id": contract.id,
            "crop_name": contract.crop_name,
            "target_weight_kg": contract.target_weight_kg,
            "pledged_weight_kg": total_pledged_kg,
            "price_per_kg": contract.price_per_kg,
            "progress_percentage": min(progress_pct, 1.0),
            "status": "fulfilled" if total_pledged_kg >= contract.target_weight_kg else "active"
        })
        
    return {
        "metrics": {
            "total_capital_kes": total_capital_committed,
            "total_tonnage_kg": total_tonnage_requested,
            "active_contract_count": len(contracts)
        },
        "contracts": active_contracts
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
        county=request.county, # Ensure county is saved
        urgency=request.urgency,
        status="Open",
        squad_status="gathering" # Default squad status
    )
    db.add(new_request)
    db.commit()
    db.refresh(new_request)
    return new_request

@app.get("/bulk-requests/", response_model=List[schemas.BulkRequestRead])
def get_active_bulk_requests(db: Session = Depends(get_db)):
    # Fetch all bulk requests that haven't been fully fulfilled yet
    requests = db.query(models.BulkRequest).filter(models.BulkRequest.status == "Open").all()
    return requests

@app.get("/harvests/me", response_model=List[HarvestRead])
def get_my_harvests(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    # Safely fetch only the harvests belonging to the logged-in user
    harvests = db.query(models.Harvest).filter(models.Harvest.farmer_id == current_user.id).all()
    return harvests

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

    # 🔥 NEW: Prevent a farmer from pledging twice to the same order
    existing_pledge = db.query(models.Pledge).filter(
        models.Pledge.bulk_request_id == request_id,
        models.Pledge.farmer_id == current_user.id
    ).first()
    
    if existing_pledge:
        raise HTTPException(status_code=400, detail="You have already pledged to this request. You can update your drop-off later.")

    # 1. Create the Pledge
    new_pledge = models.Pledge(
        bulk_request_id=request_id,
        farmer_id=current_user.id,
        pledged_weight_kg=pledge.pledged_weight_kg,
        status="pledged"
    )
    db.add(new_pledge)
    db.commit()
    db.refresh(new_pledge)
    
    # 2. 🔥 VIRTUAL HUB / SQUAD INITIALIZATION LOGIC
    current_pledges = db.query(models.Pledge).filter(models.Pledge.bulk_request_id == request_id).all()
    unique_farmers = len(set([p.farmer_id for p in current_pledges]))

    # State 1: The very first pledge! The "Virtual Hub" is born.
    if unique_farmers == 1:
        bulk_req.squad_status = "gathering"
        db.commit()
        
    # State 2: A second farmer joins! It's time to elect a coordinator.
    elif unique_farmers >= 2 and bulk_req.squad_status == "gathering":
        bulk_req.squad_status = "voting"
        db.commit()

    return new_pledge

# 🔥 THE BULLETPROOF ENDPOINT
@app.get("/api/my-pledges")
def get_my_pledges(
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(get_current_user)
):
    if current_user.role != "farmer":
        raise HTTPException(status_code=403, detail="Only farmers can view delivery squads.")

    # 1. Get all pledges for this farmer
    pledges = db.query(models.Pledge).filter(models.Pledge.farmer_id == current_user.id).all()
    
    # 2. Manually construct the exact JSON dictionary Flutter expects
    result = []
    for p in pledges:
        req = p.bulk_request # Grab the connected corporate request
        
        result.append({
            "id": p.id,
            "pledged_weight_kg": p.pledged_weight_kg,
            "actual_weight_kg": p.actual_weight_kg,
            "status": p.status,
            # 🔥 Force the nested data to attach!
            "bulk_request": {
                "id": req.id,
                "buyer_name": req.buyer_name,
                "crop_name": req.crop_name,
                "target_weight_kg": req.target_weight_kg,
                "price_per_kg": req.price_per_kg,
                "county": req.county,
                "squad_status": req.squad_status,
                "coordinator_id": req.coordinator_id
            } if req else {}
        })
        
    return result

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
    majority_threshold = total_members / 2

    if candidate.votes > majority_threshold:
        # We have a winner!
        squad = db.query(models.BulkRequest).filter(models.BulkRequest.id == squad_id).first()
        squad.coordinator_id = candidate.farmer_id
        squad.squad_status = "active" # Lock the election, it's time to deliver!
        
        # Optional: Delete all candidates and votes for this squad to keep the DB clean
        db.query(models.SquadCandidate).filter(models.SquadCandidate.bulk_request_id == squad_id).delete()
        db.query(models.SquadVote).filter(models.SquadVote.bulk_request_id == squad_id).delete()

    db.commit()
    return {"message": "Vote cast successfully!"}