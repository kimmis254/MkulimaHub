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

# 🔥 NEW IMPORTS FOR BACKGROUND SCHEDULING
from apscheduler.schedulers.background import BackgroundScheduler
from contextlib import asynccontextmanager

models.Base.metadata.create_all(bind=engine)

# ==========================================
# 1. APP & SCHEDULER INITIALIZATION
# ==========================================

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
    existing_user = db.query(models.User).filter(models.User.phone_number == user.phone_number).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Phone number already registered")

    new_user = models.User(
        full_name=user.full_name,
        phone_number=user.phone_number,
        hashed_password=security.get_password_hash(user.password),
        role=user.role
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

@app.get("/users/me")
def get_my_profile(current_user: models.User = Depends(get_current_user)):
    return {
        "id": current_user.id,
        "full_name": current_user.full_name,
        "phone_number": current_user.phone_number,
        "bio": current_user.bio,
        "farm_size_acres": current_user.farm_size_acres,
        "main_crops": current_user.main_crops,
        "farming_method": current_user.farming_method,
        "county": current_user.county,
        "sub_county": current_user.sub_county,
        "ward": current_user.ward,
        "village": current_user.village,
        "hub_id": current_user.hub_id # Expose the hub_id so Flutter knows their status!
    }

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
def get_my_pledges(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    pledges = db.query(models.Pledge).filter(models.Pledge.farmer_id == current_user.id).all()
    result = []
    for p in pledges:
        result.append({
            "id": p.id,
            "pledged_weight_kg": p.pledged_weight_kg,
            "buyer_name": p.bulk_request.buyer_name,
            "crop_name": p.bulk_request.crop_name,
            "status": p.bulk_request.status,
            "date": p.created_at.strftime("%Y-%m-%d")
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
def get_frozen_clusters(crop: str = None, db: Session = Depends(get_db)):
    """
    NEW FASTER ENDPOINT: Pulls permanently frozen Hubs from the DB instead of calculating on the fly.
    """
    query = db.query(models.Hub)
    if crop and crop != 'All':
        query = query.filter(models.Hub.crop.ilike(f"%{crop}%"))
    
    hubs = query.all()
    
    # Also fetch the "Noise" - farmers who have GPS but no Hub
    indep_query = db.query(models.User).filter(
        models.User.latitude.isnot(None),
        models.User.longitude.isnot(None),
        models.User.hub_id == None
    )
    if crop and crop != 'All':
        indep_query = indep_query.filter(models.User.main_crops.ilike(f"%{crop}%"))
    
    independent_farmers = indep_query.all()
    
    # Format Response for Flutter
    final_hubs = []
    total_analyzed = len(independent_farmers)
    
    for h in hubs:
        hub_members = db.query(models.User).filter(models.User.hub_id == h.id).all()
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
    
    return {
        "total_farmers_analyzed": total_analyzed,
        "total_hubs_found": len(final_hubs),
        "hubs": final_hubs,
        "independent_farmers": indep_list
    }


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

@app.post("/predict")
def predict_prices(request: PredictionRequest, db: Session = Depends(get_db)):
    safe_region = request.region.lower().strip().replace(" ", "_")
    req_crop = request.commodity.lower().strip()
    req_type = request.price_type.lower().strip()

    fallback_type = "none"

    def get_db_data(target_county, target_crop, target_type):
        query = db.query(models.MarketPrice.ds, models.MarketPrice.price).filter(
            models.MarketPrice.commodity == target_crop,
            models.MarketPrice.pricetype == target_type
        )
        if target_county:
            query = query.filter(models.MarketPrice.county == target_county)
            
        records = query.all()
        if not records:
            return pd.DataFrame()
            
        df = pd.DataFrame([{"ds": r.ds, "price": r.price} for r in records])
        df['ds'] = pd.to_datetime(df['ds'])
        df = df.groupby('ds', as_index=False)['price'].mean()
        df = df.sort_values(by='ds')
        return df

    df_filtered = get_db_data(safe_region, req_crop, req_type)

    if df_filtered.empty:
        alt_type = "retail" if req_type == "wholesale" else "wholesale"
        df_filtered = get_db_data(safe_region, req_crop, alt_type)
        if not df_filtered.empty:
            fallback_type = f"alt_type_{alt_type}"

    if df_filtered.empty:
        df_filtered = get_db_data(None, req_crop, req_type)
        if not df_filtered.empty:
            fallback_type = "national"
        else:
            alt_type = "retail" if req_type == "wholesale" else "wholesale"
            df_filtered = get_db_data(None, req_crop, alt_type)
            if not df_filtered.empty:
                fallback_type = f"national_alt_{alt_type}"

    if df_filtered.empty:
        raise HTTPException(status_code=404, detail="Crop not found anywhere in the database.")

    historical_dates = df_filtered['ds'].dt.strftime('%Y-%m-%d').tolist()
    historical_prices = df_filtered['price'].round(2).tolist()

    if len(df_filtered) < 3:
        last_date = df_filtered['ds'].iloc[-1]
        last_price = float(df_filtered['price'].iloc[-1])
        future_dates = [(last_date + pd.Timedelta(days=i)).strftime('%Y-%m-%d') for i in [7, 14, 30]]
        future_prices = [last_price, last_price, last_price] 
        
        return {
            "historical_dates": historical_dates,
            "historical_prices": historical_prices,
            "future_dates": future_dates,
            "future_prices": future_prices,
            "current_price": last_price,
            "predicted_price": last_price,
            "trend": "stable",
            "fallback_type": "flatline" 
        }

    try:
        m = Prophet(daily_seasonality=False, yearly_seasonality=True)
        m.fit(df_filtered[['ds', 'price']].rename(columns={'price': 'y'}))
        
        future = m.make_future_dataframe(periods=90)
        forecast = m.predict(future)
        
        future_forecast = forecast[forecast['ds'] > df_filtered['ds'].max()]
        future_prices_list = future_forecast['yhat'].round(2).tolist()
        
        hist_max = max(historical_prices)
        hist_min = min(historical_prices)
        
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
        raise HTTPException(status_code=500, detail="AI prediction failed")


load_dotenv()
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

def fetch_weather_data(location: str = "Kenya"):
    conditions = ["Sunny, 28°C", "Heavy Rain expected", "Overcast, 22°C", "Dry spell, 30°C"]
    return f"Live Weather Data for {location}: {random.choice(conditions)}."

def run_ml_diagnosis(symptoms: str):
    symptoms = symptoms.lower()
    if "yellow" in symptoms and "leaves" in symptoms:
        return "ML Model Prediction: 85% probability of Nitrogen Deficiency. 15% Maize Lethal Necrosis."
    elif "spots" in symptoms or "brown" in symptoms:
        return "ML Model Prediction: 90% probability of Fungal Blight."
    else:
        return "ML Model Prediction: Unable to classify with high confidence. Need more data."

def query_agronomy_database(query: str):
    return "KALRO Database excerpt: For optimal maize yields in Eastern Kenya, apply 50kg of DAP fertilizer per acre during planting, and top-dress with CAN after 4 weeks."

@app.post("/api/ai-chat")
def advanced_agri_bot(chat: schemas.ChatMessage): 
    user_msg = chat.message.lower()
    system_context = ""
    
    if "weather" in user_msg or "rain" in user_msg or "forecast" in user_msg:
        system_context = fetch_weather_data()
    elif "disease" in user_msg or "yellow" in user_msg or "spots" in user_msg or "sick" in user_msg:
        system_context = run_ml_diagnosis(user_msg)
    else:
        system_context = query_agronomy_database(user_msg)

    try:
        prompt = f"""
        You are MkulimaBot, an expert agronomist AI for the MkulimaHub app in Kenya.
        
        The farmer asked: "{chat.message}"
        
        You MUST base your advice strictly on the following system data retrieved from our backend:
        [SYSTEM DATA]: {system_context}
        
        Format your response nicely, be encouraging, and keep it under 3 short paragraphs.
        """
        
        model = genai.GenerativeModel('gemini-2.5-flash')
        response = model.generate_content(prompt)
        
        return {"reply": response.text}
        
    except Exception as e:
        return {"reply": f"MkulimaBot is resting. (Error: {str(e)})"}

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
    """Finds the closest permanent hubs to an independent farmer."""
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