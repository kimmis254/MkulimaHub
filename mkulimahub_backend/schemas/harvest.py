from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class HarvestBase(BaseModel):
    crop_name: str
    weight_kg: float
    price_per_kg: float


class HarvestCreate(HarvestBase):
    pass


class HarvestRead(HarvestBase):
    id: int
    farmer_id: int
    is_pooled: bool
    hub_id: Optional[int] = None

    class Config:
        from_attributes = True


class HarvestReadExtended(HarvestCreate):
    """Extended harvest read used by the /harvests endpoint."""
    id: int
    farmer_id: Optional[int] = None
    created_at: datetime

    class Config:
        from_attributes = True
