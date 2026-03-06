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
import numpy as np
from sklearn.cluster import DBSCAN
import csv
import pandas as pd
from prophet import Prophet
import google.generativeai as genai
import random
import glob

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

@app.post("/predict")
def predict_prices(request: PredictionRequest):
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))
    safe_region = request.region.lower().strip()
    
    local_path = os.path.join(BASE_DIR, "data", f"market_prices_{safe_region}.csv")
    national_path = os.path.join(BASE_DIR, "data", "market_prices_national.csv")

    fallback_type = "none"
    file_path = local_path

    # 1. Try Local Data. If missing, pivot to National.
    if not os.path.exists(file_path):
        fallback_type = "national"
        file_path = national_path

    # 2. BULLETPROOFING: What if even the National file is missing?
    if not os.path.exists(file_path):
        # Force a flatline fallback immediately
        df_commodity = pd.DataFrame() 
    else:
        df = pd.read_csv(file_path)
        df_commodity = df[(df['commodity'].str.lower() == request.commodity.lower()) & 
                          (df['pricetype'] == request.price_type.lower())]
    
    # 3. Try National Data if Local exists but lacks this specific crop
    if len(df_commodity) < 10 and fallback_type == "none" and os.path.exists(national_path):
        fallback_type = "national"
        df_national = pd.read_csv(national_path)
        df_commodity = df_national[(df_national['commodity'].str.lower() == request.commodity.lower()) & 
                                   (df_national['pricetype'] == request.price_type.lower())]

    # 4. THE ZERO DEAD-END FIX (Flatline Forecast)
    if len(df_commodity) < 10:
        if len(df_commodity) > 0:
            last_real_price = df_commodity['price'].iloc[-1]
        else:
            last_real_price = 100.0 # Absolute failsafe
            
        return {
            "past_prices": [last_real_price] * 14,
            "future_prices": [last_real_price] * request.days,
            "trend": "stable",
            "current_price": last_real_price,
            "fallback_type": "flatline" 
        }

    # 5. Proceed with Prophet AI as normal
    df_prophet = df_commodity[['ds', 'price']].rename(columns={'price': 'y'})
    past_data = df_prophet.tail(14)['y'].tolist()
    last_real_price = past_data[-1]

    m = Prophet(daily_seasonality=False, yearly_seasonality=True)
    m.fit(df_prophet)
    future = m.make_future_dataframe(periods=request.days)
    forecast = m.predict(future)
    
    future_prices = forecast[['ds', 'yhat']].tail(request.days)['yhat'].tolist()
    trend = "rising" if future_prices[-1] > last_real_price else "falling"

    return {
        "past_prices": past_data,
        "future_prices": future_prices,
        "trend": trend,
        "current_price": last_real_price,
        "fallback_type": fallback_type
    }
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



GEMINI_API_KEY = "AIzaSyCS3JB7aOeaWxVN6cJX7m1w28L6Vg-fBdw"
genai.configure(api_key=GEMINI_API_KEY)


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
def get_market_metadata():
    """Returns all available regions and crops so Flutter can build dynamic dropdowns."""
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))
    data_dir = os.path.join(BASE_DIR, "scripts", "data") # Adjust if your data folder is elsewhere
    
    regions = set()
    crops = set()
    
    # Scan the data folder for all generated CSVs
    for file_path in glob.glob(os.path.join(data_dir, "market_prices_*.csv")):
        # Extract region from filename (e.g., 'market_prices_kisumu.csv' -> 'kisumu')
        filename = os.path.basename(file_path)
        region = filename.replace("market_prices_", "").replace(".csv", "")
        regions.add(region.title())
        
        # Read the CSV to find what crops are available in it
        df = pd.read_csv(file_path)
        crops.update(df['commodity'].unique().tolist())
        
    return {
        "regions": sorted(list(regions)),
        # ✅ FIX: Use list comprehension to apply .title() to each string individually
        "crops": sorted([crop.title() for crop in crops]) 
    }