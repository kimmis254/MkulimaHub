from pydantic import BaseModel
from typing import Optional, List, Dict, Any


class MarketListingCreate(BaseModel):
    crop_name: str
    base_inventory_kg: float
    is_selling_by_weight: bool
    price_per_kg: Optional[float] = None
    unit_pricing: List[Dict[str, Any]] = []
    image_base64: Optional[str] = None


class MarketListingUpdate(BaseModel):
    available_kg: float
    price_per_kg: Optional[float] = None
    unit_pricing: List[Dict[str, Any]] = []


class MarketOrderCreate(BaseModel):
    order_type: str
    quantity: float
    delivery_method: str = "Delivery"
    payment_method: str = "pay_now"


class PoolPurchasePayload(BaseModel):
    county: str
    ward: str
    payment_method: Optional[str] = "pay_now"


class PredictionRequest(BaseModel):
    commodity: str
    days: int
    region: str
    price_type: str


class AIChatRequest(BaseModel):
    message: str
    role: Optional[str] = "farmer"
    user_name: Optional[str] = "Farmer"
    location: Optional[str] = "Kenya"
    business_details: Optional[str] = ""
