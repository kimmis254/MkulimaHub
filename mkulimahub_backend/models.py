from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Enum, UniqueConstraint, Date
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from geoalchemy2 import Geometry
from database import Base
import enum
from datetime import datetime

class UserRole(str, enum.Enum):
    FARMER = "farmer"
    BUYER = "buyer"
    ADMIN = "admin"


class Harvest(Base):
    __tablename__ = "harvests"

    id = Column(Integer, primary_key=True, index=True)
    farmer_id = Column(Integer, ForeignKey("users.id"))
    
    crop_name = Column(String, nullable=False) # e.g., "Maize"
    weight_kg = Column(Float, nullable=False)
    price_per_kg = Column(Float, nullable=True) # Optional asking price
    
    cluster_id = Column(Integer, nullable=True) 
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    farmer = relationship("User", back_populates="harvests")
class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    full_name = Column(String, index=True)
    phone_number = Column(String, unique=True, index=True)
    hashed_password = Column(String)
    role = Column(String, default="farmer")
    
    bio = Column(String, nullable=True)
    farm_size_acres = Column(Float, nullable=True)
    main_crops = Column(String, nullable=True)
    farming_method = Column(String, nullable=True)

    county = Column(String, nullable=True)
    sub_county = Column(String, nullable=True)
    ward = Column(String, nullable=True)
    village = Column(String, nullable=True)

    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)

    pledges = relationship("Pledge", back_populates="farmer")

    harvests = relationship("Harvest", back_populates="farmer")

class BulkRequest(Base):
    __tablename__ = "bulk_requests"
    
    id = Column(Integer, primary_key=True, index=True)
    buyer_name = Column(String, index=True) 
    crop_name = Column(String, index=True)
    target_weight_kg = Column(Float)
    price_per_kg = Column(Float)
    county = Column(String)
    ward = Column(String, nullable=True) 
    status = Column(String, default="Open") 
    created_at = Column(DateTime, default=datetime.utcnow)
    
    pledges = relationship("Pledge", back_populates="bulk_request")

class Pledge(Base):
    __tablename__ = "pledges"
    
    id = Column(Integer, primary_key=True, index=True)
    bulk_request_id = Column(Integer, ForeignKey("bulk_requests.id"))
    farmer_id = Column(Integer, ForeignKey("users.id"))
    pledged_weight_kg = Column(Float)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    bulk_request = relationship("BulkRequest", back_populates="pledges")
    farmer = relationship("User", back_populates="pledges")

class HubMessage(Base):
    __tablename__ = "hub_messages"
    
    id = Column(Integer, primary_key=True, index=True)
    hub_name = Column(String, index=True) # e.g., "Makindu Hub"
    sender_id = Column(Integer, ForeignKey("users.id"))
    message = Column(String)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    sender = relationship("User")

class MarketPrice(Base):
    __tablename__ = "market_prices"

    id = Column(Integer, primary_key=True, index=True)
    county = Column(String, index=True)      # e.g., "nairobi"
    commodity = Column(String, index=True)   # e.g., "beans"
    pricetype = Column(String, index=True)   # "wholesale" or "retail"
    price = Column(Float)
    ds = Column(Date, index=True)            # The date of the price

    # 🔥 ENTERPRISE SHIELD: Prevent the daily scraper from accidentally inserting duplicate prices for the same day
    __table_args__ = (
        UniqueConstraint('county', 'commodity', 'pricetype', 'ds', name='_county_commodity_price_date_uc'),
    )