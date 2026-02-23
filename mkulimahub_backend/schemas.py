from pydantic import BaseModel
from typing import Optional

# 1. Schema for Registering (What the User sends)
class UserCreate(BaseModel):
    full_name: str
    phone_number: str
    password: str
    role: str = "farmer"  # Default to farmer
    # We ask for Lat/Long as simple numbers, handle the complex Geometry in backend
    latitude: float 
    longitude: float

# 2. Schema for Login
class UserLogin(BaseModel):
    phone_number: str
    password: str

# 3. Schema for the Token response
class Token(BaseModel):
    access_token: str
    token_type: str

# 4. Schema for Returning User Data (Hide the password!)
class UserResponse(BaseModel):
    id: int
    full_name: str
    phone_number: str
    role: str
    
    class Config:
        from_attributes = True # Allows Pydantic to read SQLAlchemy models

# What the farmer sends when posting a harvest
class HarvestCreate(BaseModel):
    crop_name: str
    weight_kg: float
    price_per_kg: float

class UserProfileUpdate(BaseModel):
    bio: str | None = None
    main_crops: str | None = None
    farm_size_acres: float | None = None
    farming_method: str | None = None
    # Add Location Fields
    county: str | None = None
    sub_county: str | None = None
    ward: str | None = None
    village: str | None = None

class UserRead(BaseModel):
    id: int
    full_name: str
    phone_number: str
    role: str
    bio: str | None = None
    main_crops: str | None = None
    # Add Location Fields here too so Flutter can see them!
    county: str | None = None
    sub_county: str | None = None
    ward: str | None = None
    village: str | None = None

    class Config:
        orm_mode = True