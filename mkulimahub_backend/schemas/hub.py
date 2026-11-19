from pydantic import BaseModel
from datetime import datetime


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


class HubPitchPayload(BaseModel):
    pitch: str


class HubPoolCreate(BaseModel):
    crop_name: str
    target_weight_kg: float
    price_per_kg: float
