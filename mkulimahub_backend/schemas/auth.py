from pydantic import BaseModel
from typing import Optional
from models import UserRole


class UserCreate(BaseModel):
    full_name: str
    phone_number: str
    password: str
    role: Optional[UserRole] = UserRole.FARMER
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
    role: UserRole

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
    phone_number: Optional[str] = None


class UserRead(BaseModel):
    id: int
    full_name: str
    phone_number: Optional[str]
    role: UserRole
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


class GoogleAuthRequest(BaseModel):
    id_token: str
    phone_number: Optional[str] = None
    role: Optional[str] = "farmer"


class PhoneAuthRequest(BaseModel):
    phone_number: str
    uid: str


class PasswordResetRequest(BaseModel):
    phone_number: str
    uid: str
    new_password: str


class ChatMessage(BaseModel):
    message: str
