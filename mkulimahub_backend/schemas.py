from pydantic import BaseModel
from typing import Optional, List, Dict
from datetime import datetime
from models import UserRole  # 🔥 Importing your Enum!

class UserCreate(BaseModel):
    full_name: str
    phone_number: str
    password: str
    role: Optional[UserRole] = UserRole.FARMER  # 🔥 Now strictly mapped to Enum
    
    # 🔥 FIXED: Made optional. Corporate Buyers won't pass GPS coordinates on signup!
    latitude: Optional[float] = None 
    longitude: Optional[float] = None

class UserLogin(BaseModel):
    phone_number: str
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str

class UserResponse(BaseModel):
    id: int
    full_name: str
    phone_number: Optional[str]
    role: UserRole  # 🔥 Strict Enum response
    
    class Config:
        from_attributes = True 

# 🔥 UPDATED: Harvest Schemas 
class HarvestBase(BaseModel):
    crop_name: str
    weight_kg: float
    price_per_kg: float

class HarvestCreate(HarvestBase):
    pass

class HarvestRead(HarvestBase):
    id: int
    farmer_id: int
    is_pooled: bool           # 🔥 Added flag
    hub_id: Optional[int] = None

    class Config:
        from_attributes = True

class UserProfileUpdate(BaseModel):
    bio: str | None = None
    main_crops: str | None = None
    farm_size_acres: float | None = None
    farming_method: str | None = None
    county: str | None = None
    sub_county: str | None = None
    ward: str | None = None
    village: str | None = None

    latitude: Optional[float] = None
    longitude: Optional[float] = None

class UserRead(BaseModel):
    id: int
    full_name: str
    phone_number: Optional[str]
    role: UserRole  # 🔥 The crucial field!
    bio: str | None = None
    main_crops: str | None = None
    
    farm_size_acres: float | None = None 
    farming_method: str | None = None
    hub_id: int | None = None
    
    county: str | None = None
    sub_county: str | None = None
    ward: str | None = None
    village: str | None = None

    class Config:
        from_attributes = True

class PledgeBase(BaseModel):
    pledged_weight_kg: float

class PledgeCreate(PledgeBase):
    bulk_request_id: int

class PledgeRead(PledgeBase):
    id: int
    farmer_id: Optional[int] = None
    bulk_request_id: int
    created_at: datetime
    
    class Config:
        from_attributes = True

# 🔥 UPDATED: Bulk Request Schemas
class BulkRequestBase(BaseModel):
    # Removed buyer_name from Base so frontend doesn't need to pass it in Create
    crop_name: str
    target_weight_kg: float
    price_per_kg: float
    county: str
    ward: Optional[str] = None
    urgency: Optional[str] = "High"

class BulkRequestCreate(BulkRequestBase):
    pass

class BulkRequestRead(BulkRequestBase):
    id: int
    buyer_id: Optional[int] = None
    buyer_name: str
    status: str
    
    # 🔥 NEW: Squad Info
    coordinator_id: Optional[int] = None
    squad_status: str
    
    created_at: datetime
    pledges: List[PledgeRead] = [] 

    class Config:
        from_attributes = True

class HubMessageCreate(BaseModel):
    message: str

class HubMessageRead(BaseModel):
    id: int
    hub_name: str
    message: str
    created_at: datetime
    sender_name: str 

    class Config:
        from_attributes = True

class ChatMessage(BaseModel):
    message: str

class BulkRequestSimple(BaseModel):
    id: int
    buyer_name: str
    crop_name: str
    target_weight_kg: float
    price_per_kg: float
    county: str
    squad_status: str
    coordinator_id: Optional[int] = None

    class Config:
        from_attributes = True

class PledgeWithRequest(PledgeRead):
    bulk_request: BulkRequestSimple

    class Config:
        from_attributes = True