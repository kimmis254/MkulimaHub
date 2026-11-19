from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


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


class PledgeUpdate(BaseModel):
    pledged_weight_kg: float


class BulkRequestBase(BaseModel):
    crop_name: str
    target_weight_kg: float
    price_per_kg: float
    county: str
    ward: Optional[str] = None
    urgency: Optional[str] = "High"
    deadline_hours: Optional[int] = 24


class BulkRequestCreate(BulkRequestBase):
    pass


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


class BulkRequestRead(BulkRequestBase):
    id: int
    buyer_id: Optional[int] = None
    buyer_name: str
    status: str
    coordinator_id: Optional[int] = None
    squad_status: str
    created_at: datetime
    deadline_time: Optional[datetime] = None
    pledges: List[PledgeRead] = []

    class Config:
        from_attributes = True


class PledgeWithRequest(PledgeRead):
    bulk_request: BulkRequestSimple

    class Config:
        from_attributes = True


class CoordinatorPitch(BaseModel):
    pitch: str


class VotePayload(BaseModel):
    candidate_id: int


class SquadPitch(BaseModel):
    pitch: str


class SquadVoteRequest(BaseModel):
    candidate_id: int


class SquadStatusUpdate(BaseModel):
    status: str


class ProcessDeliveryPayload(BaseModel):
    action: str
    actual_weight_kg: Optional[float] = None
    notes: Optional[str] = None


class QAUpdate(BaseModel):
    status: str
    notes: Optional[str] = None
    dispute_image: Optional[str] = None


class ReceiveLineItemPayload(BaseModel):
    actual_weight_kg: float
    notes: Optional[str] = None


class UnattendedDropoffPayload(BaseModel):
    scale_photo_url: str
    crop_photo_url: str


class MessageCreate(BaseModel):
    message: str
