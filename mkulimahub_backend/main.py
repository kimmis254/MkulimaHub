from fastapi import FastAPI, HTTPException, Depends, status
from sqlalchemy.orm import Session
from geoalchemy2.elements import WKTElement
import models
import schemas
import security
import random  # <--- Added for AI simulation
from database import engine, SessionLocal
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
from typing import List
from datetime import datetime, timedelta
from pydantic import BaseModel

# Create tables (if they don't exist, though Alembic usually handles this)
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="MkulimaHub API")

# Dependency: Get Database Session
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Tells FastAPI that the token comes from the /auth/login url
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        # Decode the Token
        payload = jwt.decode(token, security.SECRET_KEY, algorithms=[security.ALGORITHM])
        phone_number: str = payload.get("sub")
        if phone_number is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
        
    # Get the user from DB
    user = db.query(models.User).filter(models.User.phone_number == phone_number).first()
    if user is None:
        raise credentials_exception
        
    return user

@app.get("/")
def read_root():
    return {"message": "MkulimaHub API is active!", "status": "secure"}

# --- AUTH ROUTE 1: REGISTER ---
@app.post("/auth/register", response_model=schemas.UserResponse)
def register_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    # 1. Check if phone number already exists
    existing_user = db.query(models.User).filter(models.User.phone_number == user.phone_number).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Phone number already registered")

    # 2. Convert Lat/Long to PostGIS Geometry
    # Format: POINT(longitude latitude) -> Note the order!
    geo_location = WKTElement(f'POINT({user.longitude} {user.latitude})', srid=4326)

    # 3. Create new user object
    new_user = models.User(
        full_name=user.full_name,
        phone_number=user.phone_number,
        password_hash=security.get_password_hash(user.password),
        role=user.role,
        location=geo_location
    )

    # 4. Save to DB
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    return new_user

# --- AUTH ROUTE 2: LOGIN (UPDATED FOR SWAGGER SUPPORT) ---
@app.post("/auth/login", response_model=schemas.Token)
def login_user(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    
    # Note: OAuth2 always sends 'username' and 'password' fields.
    # We map 'username' to our 'phone_number' column.
    print(f"🔐 Attempting login for: {form_data.username}") 

    user = db.query(models.User).filter(models.User.phone_number == form_data.username).first()
    
    # Check if user exists AND password is correct
    if not user or not security.verify_password(form_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Generate Token
    access_token = security.create_access_token(data={"sub": user.phone_number, "role": user.role})
    
    return {"access_token": access_token, "token_type": "bearer"}

# --- PROTECTED ROUTE: ADD HARVEST ---
@app.post("/harvests", status_code=status.HTTP_201_CREATED)
def create_harvest(
    harvest: schemas.HarvestCreate, 
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(get_current_user) # <--- THE LOCK!
):
    # Security Check: Only Farmers can post harvests
    if current_user.role != "farmer":
        raise HTTPException(status_code=403, detail="Only farmers can post harvests")

    new_harvest = models.Harvest(
        farmer_id=current_user.id, # We get ID automatically from the token!
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

# --- PUBLIC ROUTE: GET ALL HARVESTS (For the Marketplace) ---
@app.get("/harvests", response_model=List[HarvestRead])
def get_harvests(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    harvests = db.query(models.Harvest).offset(skip).limit(limit).all()
    return harvests

# --- NEW AI SECTION START ---

# Schema for AI Prediction Request
class PredictionRequest(BaseModel):
    commodity: str
    days: int

@app.put("/users/profile")
def update_profile(
    profile_data: schemas.UserProfileUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user) # Locked!
):
    # Update fields if provided
    if profile_data.bio:
        current_user.bio = profile_data.bio
    if profile_data.farm_size_acres:
        current_user.farm_size_acres = profile_data.farm_size_acres
    if profile_data.main_crops:
        current_user.main_crops = profile_data.main_crops
    if profile_data.farming_method:
        current_user.farming_method = profile_data.farming_method
    
    db.commit()
    db.refresh(current_user)
    return {"message": "Profile updated successfully", "user": current_user.full_name}

# --- PROTECTED ROUTE: GET PROFILE (To show current data) ---
@app.get("/users/me")
def get_my_profile(current_user: models.User = Depends(get_current_user)):
    # We return the user object directly, Pydantic will filter it
    return {
        "full_name": current_user.full_name,
        "phone_number": current_user.phone_number,
        "bio": current_user.bio,
        "farm_size_acres": current_user.farm_size_acres,
        "main_crops": current_user.main_crops,
        "farming_method": current_user.farming_method
    }

# --- AI ROUTE: PREDICT PRICES ---
@app.post("/predict")
def predict_prices(request: PredictionRequest):
    print(f"🔮 Predicting prices for: {request.commodity}")
    
    # SIMULATED AI ENGINE
    # (This generates realistic-looking data so you can test the Mobile Graph immediately)
    
    base_price = 50.0
    if request.commodity == "Maize": base_price = 45.0
    if request.commodity == "Beans": base_price = 90.0
    if request.commodity == "Mangoes": base_price = 25.0
    
    forecast = []
    current_price = base_price

    for i in range(request.days):
        # Add a random fluctuation (-2 to +3 shillings) to simulate market trends
        change = random.uniform(-2, 3) 
        current_price += change
        
        forecast.append({
            "date": (datetime.now() + timedelta(days=i)).strftime('%Y-%m-%d'),
            "predicted_price": round(current_price, 2),
            "trend": "rising" if change > 0 else "falling"
        })
        
    return {"forecast": forecast}