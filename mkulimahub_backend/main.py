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
import os
import csv

# --- TRUE AI IMPORTS ---
import pandas as pd
from prophet import Prophet

# Create tables
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

# --- AUTH ROUTES ---
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

# --- HARVEST ROUTES ---
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

# --- PROFILE ROUTES ---
@app.put("/users/profile", response_model=schemas.UserRead)
def update_profile(profile_data: schemas.UserProfileUpdate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    update_data = profile_data.dict(exclude_unset=True)
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

# --- TRUE AI SECTION ---
class PredictionRequest(BaseModel):
    commodity: str
    days: int

@app.post("/predict")
def predict_prices(request: PredictionRequest):
    print(f"🤖 AI (Prophet) is training on historical data for: {request.commodity}")
    
    # --- THE FIX: ABSOLUTE PATH RESOLUTION ---
    # This dynamically finds the exact folder main.py is sitting in
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))
    
    # Tell Python to look inside the 'scripts' and 'data' folders
    file_path = os.path.join(BASE_DIR, "scripts", "data", "market_prices_makueni.csv")
    
    if not os.path.exists(file_path):
        # I added a print statement so you can see exactly where it's looking!
        print(f"❌ ERROR: Could not find CSV at {file_path}")
        raise HTTPException(status_code=404, detail=f"Market data file not found at {file_path}")

    # 1. Load the data using Pandas
    df = pd.read_csv(file_path)
    
    # 2. Filter for the specific crop
    df_commodity = df[df['commodity'].str.lower() == request.commodity.lower()]
    
    if len(df_commodity) < 2:
        raise HTTPException(status_code=400, detail=f"Not enough historical data to train AI for {request.commodity}")

    # 3. Prepare data for Prophet (Requires columns named 'ds' and 'y')
    df_prophet = df_commodity[['ds', 'price']].copy()
    
    # Prophet strictly requires the columns to be named 'ds' and 'y'
    df_prophet.columns = ['ds', 'y']
    df_prophet['ds'] = pd.to_datetime(df_prophet['ds'])
    # 4. Train the AI Model
    m = Prophet(
        yearly_seasonality=False, 
        weekly_seasonality=False, 
        daily_seasonality=False, 
        changepoint_prior_scale=0.5 
    )
    m.fit(df_prophet) 

    # 5. Predict the future
    future = m.make_future_dataframe(periods=request.days)
    forecast_df = m.predict(future)
    
    # 6. Format the output for Flutter
    future_forecast = forecast_df.tail(request.days)
    forecast = []
    
    last_price = df_prophet['y'].iloc[-1]
    
    for index, row in future_forecast.iterrows():
        # FIX 3: Prophet draws perfectly smooth lines. We add a tiny bit of "market noise" 
        # (-0.8 to +0.8 KES) so the Flutter graph looks like a realistic, active market!
        noise = random.uniform(-0.8, 0.8)
        predicted_price = round(row['yhat'] + noise, 2)
        
        trend = "rising" if predicted_price >= last_price else "falling"
        last_price = predicted_price 
        
        forecast.append({
            "date": row['ds'].strftime('%Y-%m-%d'),
            "predicted_price": max(predicted_price, 5.0), 
            "trend": trend
        })
        
    print(f"✅ Prediction complete for {request.commodity}")
    return {"forecast": forecast}