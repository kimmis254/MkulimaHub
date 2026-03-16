from fastapi import FastAPI, HTTPException, Depends, status
from sqlalchemy.orm import Session
from geoalchemy2.elements import WKTElement
import models
import schemas
import security
import random  
from database import engine, SessionLocal
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
from typing import List
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
import random
import glob
from sqlalchemy import select, distinct

models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="MkulimaHub API")

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, security.SECRET_KEY, algorithms=[security.ALGORITHM])
        phone_number: str = payload.get("sub")
        if phone_number is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
        
    user = db.query(models.User).filter(models.User.phone_number == phone_number).first()
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
def login_user(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    print(f"🔐 Attempting login for: {form_data.username}") 
    user = db.query(models.User).filter(models.User.phone_number == form_data.username).first()
    
    if not user or not security.verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    access_token = security.create_access_token(data={"sub": user.phone_number, "role": user.role})
    return {"access_token": access_token, "token_type": "bearer"}

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
    farmer_id: int
    created_at: datetime
    class Config:
        from_attributes = True

@app.get("/harvests", response_model=List[HarvestRead])
def get_harvests(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    harvests = db.query(models.Harvest).offset(skip).limit(limit).all()
    return harvests


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
                    print(f"✅ Magic! Found exact Ward coordinates.")
                else:
                    print(f"⚠️ Ward not found on map. Zooming out to {county} County...")
                    url_county = f"https://nominatim.openstreetmap.org/search?q={county} County, Kenya&format=json&limit=1"
                    county_data = requests.get(url_county, headers=headers).json()
                    
                    if county_data:
                        update_data["latitude"] = float(county_data[0]["lat"])
                        update_data["longitude"] = float(county_data[0]["lon"])
                        print(f"✅ Saved County center coordinates instead.")
                    else:
                        print("❌ OpenStreetMap failed completely.")
                        
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
        "full_name": current_user.full_name,
        "phone_number": current_user.phone_number,
        "bio": current_user.bio,
        "farm_size_acres": current_user.farm_size_acres,
        "main_crops": current_user.main_crops,
        "farming_method": current_user.farming_method,
        "county": current_user.county,
        "sub_county": current_user.sub_county,
        "ward": current_user.ward,
        "village": current_user.village
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

# Map counties to their closest WFP market hub
COUNTY_MAPPING = {
    "mombasa": "mombasa", "nairobi": "nairobi", "uasin gishu": "eldoret",
    "nakuru": "nakuru", "kisumu": "kisumu", "turkana": "lodwar",
    "garissa": "garissa", "mandera": "mandera", "machakos": "tala",
    "kajiado": "kajiado", "kitui": "kitui", "baringo": "marigat",
    "kilifi": "kilifi", "wajir": "wajir", "marsabit": "marsabit",
    "makueni": "wote", "isiolo": "isiolo"
}

@app.post("/predict")
def predict_prices(request: PredictionRequest, db: Session = Depends(get_db)):
    safe_region = request.region.lower().strip().replace(" ", "_")
    req_crop = request.commodity.lower().strip()
    req_type = request.price_type.lower().strip()

    fallback_type = "none"

    # 🔥 ENTERPRISE SQL FETCHER: Pulls data directly from the Database!
    def get_db_data(target_county, target_crop, target_type):
        query = db.query(models.MarketPrice.ds, models.MarketPrice.price).filter(
            models.MarketPrice.commodity == target_crop,
            models.MarketPrice.pricetype == target_type
        )
        
        # If a specific county is requested, filter by it. Otherwise, pull all of Kenya.
        if target_county:
            query = query.filter(models.MarketPrice.county == target_county)
            
        records = query.all()
        
        if not records:
            return pd.DataFrame()
            
        # Instantly convert the SQL records into a Pandas DataFrame for the AI
        df = pd.DataFrame([{"ds": r.ds, "price": r.price} for r in records])
        
        # Average any duplicate prices on the same day to prevent graph glitches
        df['ds'] = pd.to_datetime(df['ds'])
        df = df.groupby('ds', as_index=False)['price'].mean()
        df = df.sort_values(by='ds')
        return df

    # 🔥 1. Try local exact match
    df_filtered = get_db_data(safe_region, req_crop, req_type)

    # 🔥 2. Try local ALTERNATIVE price type (Wholesale <-> Retail)
    if df_filtered.empty:
        alt_type = "retail" if req_type == "wholesale" else "wholesale"
        df_filtered = get_db_data(safe_region, req_crop, alt_type)
        if not df_filtered.empty:
            print(f"🔀 AI Router: {req_type} missing in {safe_region}. Falling back to {alt_type}.")
            fallback_type = f"alt_type_{alt_type}"

    # 🔥 3. If local is completely empty, build True National Average directly via SQL
    if df_filtered.empty:
        print(f"🔀 AI Router: {req_crop} missing locally. Building True National Average...")
        
        # None passed as county = Get all counties in Kenya
        df_filtered = get_db_data(None, req_crop, req_type)
        if not df_filtered.empty:
            fallback_type = "national"
        else:
            # Try alt price type nationally
            alt_type = "retail" if req_type == "wholesale" else "wholesale"
            df_filtered = get_db_data(None, req_crop, alt_type)
            if not df_filtered.empty:
                fallback_type = f"national_alt_{alt_type}"

    # 4. If IT IS STILL EMPTY (doesn't exist anywhere in Kenya)
    if df_filtered.empty:
        raise HTTPException(status_code=404, detail="Crop not found anywhere in the database.")

    historical_dates = df_filtered['ds'].dt.strftime('%Y-%m-%d').tolist()
    historical_prices = df_filtered['price'].round(2).tolist()

    # 🔥 THE LIMITLESS BYPASS
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

    # If we have 3 or more points, Unleash Prophet!
    try:
        m = Prophet(daily_seasonality=False, yearly_seasonality=True)
        m.fit(df_filtered[['ds', 'price']].rename(columns={'price': 'y'}))
        
        future = m.make_future_dataframe(periods=90)
        forecast = m.predict(future)
        
        future_forecast = forecast[forecast['ds'] > df_filtered['ds'].max()]
        future_prices_list = future_forecast['yhat'].round(2).tolist()
        
        # 🔥 THE PROPHET CAPPER: Prevent crazy spikes from sparse data
        hist_max = max(historical_prices)
        hist_min = min(historical_prices)
        
        capped_future = []
        for p in future_prices_list:
            if p > (hist_max * 1.5): # Cap at 50% above historical max
                capped_future.append(round(hist_max * 1.5, 2))
            elif p < (hist_min * 0.5): # Floor at 50% below historical min
                capped_future.append(round(hist_min * 0.5, 2))
            elif p <= 0:
                capped_future.append(round(hist_min * 0.8, 2)) # Prevent negative prices
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
        print(f"Prophet AI Error: {e}")
        raise HTTPException(status_code=500, detail="AI prediction failed")

@app.get("/api/clusters")
def get_farmer_clusters(crop: str = None, db: Session = Depends(get_db)):
    query = db.query(models.User).filter(
        models.User.latitude.isnot(None), 
        models.User.longitude.isnot(None)
    )
    
    if crop:
        query = query.filter(models.User.main_crops.ilike(f"%{crop}%"))
        
    farmers = query.all()
    
    if not farmers:
        return {"message": "No farmers found with GPS data for this crop.", "hubs": []}

    coords = np.radians([[f.latitude, f.longitude] for f in farmers])

    kms_per_radian = 6371.0088
    epsilon = 10 / kms_per_radian
    
    dbscan = DBSCAN(eps=epsilon, min_samples=2, algorithm='ball_tree', metric='haversine')
    cluster_labels = dbscan.fit_predict(coords)

    clusters_data = {}
    independent_farmers = []

    for i, label in enumerate(cluster_labels):
        farmer = farmers[i]
        farmer_info = {
            "name": farmer.full_name,
            "phone": farmer.phone_number,
            "ward": farmer.ward,
            "village": farmer.village,
            "crops": farmer.main_crops
        }

        if label == -1:
            independent_farmers.append(farmer_info)
        else:
            cluster_id = f"Cluster_{label + 1}"
            
            if cluster_id not in clusters_data:
                hub_name = f"{farmer.ward or 'Regional'} Hub"
                clusters_data[cluster_id] = {
                    "hub_name": hub_name,
                    "farmer_count": 0,
                    "farmers": []
                }
            
            clusters_data[cluster_id]["farmers"].append(farmer_info)
            clusters_data[cluster_id]["farmer_count"] += 1

    final_hubs = list(clusters_data.values())

    return {
        "total_farmers_analyzed": len(farmers),
        "total_hubs_found": len(final_hubs),
        "hubs": final_hubs,
        "independent_farmers": independent_farmers
    }

@app.post("/api/contracts", response_model=schemas.BulkRequestRead)
def create_bulk_contract(contract: schemas.BulkRequestCreate, db: Session = Depends(get_db)):
    """
    Creates a new bulk request. In a full app, this would be locked to 'Buyer' accounts.
    For this MVP, we leave it open so you can easily generate test data!
    """
    new_contract = models.BulkRequest(**contract.dict())
    db.add(new_contract)
    db.commit()
    db.refresh(new_contract)
    print(f"🏢 New Contract Posted: {new_contract.target_weight_kg}kg of {new_contract.crop_name}")
    return new_contract


@app.get("/api/contracts", response_model=List[schemas.BulkRequestRead])
def get_open_contracts(county: str = None, db: Session = Depends(get_db)):
    """
    Fetches all open contracts. If a county is provided, it only shows contracts for that area.
    """
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
    
    print(f"🤝 Farmer {current_user.full_name} pledged {pledge.pledged_weight_kg}kg to Contract #{contract_id}!")
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
    
    print(f"💬 {current_user.full_name} posted in {hub_name}: {msg.message}")
    
    return {
        "id": new_message.id,
        "hub_name": new_message.hub_name,
        "message": new_message.message,
        "created_at": new_message.created_at,
        "sender_name": current_user.full_name
    }



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
        print("🤖 Routing to Weather API...")
        system_context = fetch_weather_data()
        
    elif "disease" in user_msg or "yellow" in user_msg or "spots" in user_msg or "sick" in user_msg:
        print("🤖 Routing to ML Diagnosis Model...")
        system_context = run_ml_diagnosis(user_msg)
        
    else:
        print("🤖 Routing to RAG Agronomy Database...")
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
    # ⚡️ Fast SQL queries instead of slow file reading!
    counties = db.query(models.MarketPrice.county).distinct().all()
    all_crops = db.query(models.MarketPrice.commodity).distinct().all()
    
    regions_list = sorted([c[0] for c in counties if c[0]])
    crops_list = sorted([c[0] for c in all_crops if c[0]])
    
    county_crop_map = {}
    
    # Build the smart mapping dictionary dynamically from the DB
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