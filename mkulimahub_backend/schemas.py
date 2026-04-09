from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from typing import List
from typing import Optional, Dict

class UserCreate(BaseModel):
    full_name: str
    phone_number: str
    password: str
    role: str = "farmer"  
    latitude: float 
    longitude: float

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
    role: str
    
    class Config:
        from_attributes = True 

class HarvestCreate(BaseModel):
    crop_name: str
    weight_kg: float
    price_per_kg: float

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
    role: str
    bio: str | None = None
    main_crops: str | None = None
    county: str | None = None
    sub_county: str | None = None
    ward: str | None = None
    village: str | None = None

    class Config:
        orm_mode = True

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
        orm_mode = True

class BulkRequestBase(BaseModel):
    buyer_name: str
    crop_name: str
    target_weight_kg: float
    price_per_kg: float
    county: str
    ward: Optional[str] = None

class BulkRequestCreate(BulkRequestBase):
    pass

class BulkRequestRead(BulkRequestBase):
    id: int
    status: str
    created_at: datetime
    pledges: List[PledgeRead] = [] 

    class Config:
        orm_mode = True

class HubMessageCreate(BaseModel):
    message: str

class HubMessageRead(BaseModel):
    id: int
    hub_name: str
    message: str
    created_at: datetime
    sender_name: str 

    class Config:
        orm_mode = True

class ChatMessage(BaseModel):
    message: str

