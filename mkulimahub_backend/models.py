from sqlalchemy import Column, Integer, String, Float, DateTime, JSON, ForeignKey, Enum as SQLEnum, UniqueConstraint, Date, Boolean
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
    farmer_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    
    crop_name = Column(String, nullable=False) 
    weight_kg = Column(Float, nullable=False)
    price_per_kg = Column(Float, nullable=True) 
    
    cluster_id = Column(Integer, nullable=True) 
    
    # 🔥 NEW: Tracking Hub Pooled Listings
    is_pooled = Column(Boolean, default=False)
    hub_id = Column(Integer, ForeignKey("hubs.id"), nullable=True)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    farmer = relationship("User", back_populates="harvests")

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    full_name = Column(String, index=True)
    
    email = Column(String, unique=True, index=True, nullable=True)
    google_uid = Column(String, unique=True, nullable=True)
    
    phone_number = Column(String, unique=True, index=True, nullable=True)
    hashed_password = Column(String, nullable=True)
    
    # 🔥 STRICT ENUM ENFORCEMENT
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
    hub_id = Column(Integer, ForeignKey("hubs.id"), nullable=True)

    hub = relationship("Hub", back_populates="members", foreign_keys=[hub_id])
    pledges = relationship("Pledge", back_populates="farmer")
    harvests = relationship("Harvest", back_populates="farmer")

class BulkRequest(Base):
    __tablename__ = "bulk_requests"
    
    id = Column(Integer, primary_key=True, index=True)
    buyer_id = Column(Integer, ForeignKey("users.id"))
    buyer_name = Column(String, index=True) 
    crop_name = Column(String, index=True)
    target_weight_kg = Column(Float)
    price_per_kg = Column(Float)
    county = Column(String)
    ward = Column(String, nullable=True) 
    urgency = Column(String, default="High") 
    status = Column(String, default="Open") 
    
    # 🔥 NEW: Delivery Squad Management
    coordinator_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    squad_status = Column(String, default="gathering") # gathering, voting, active, completed
    
    created_at = Column(DateTime, default=datetime.utcnow)
    
    pledges = relationship("Pledge", back_populates="bulk_request")
    coordinator = relationship("User", foreign_keys=[coordinator_id])
    status = Column(String, default="open", index=True)

class Pledge(Base):
    __tablename__ = "pledges"
    
    id = Column(Integer, primary_key=True, index=True)
    bulk_request_id = Column(Integer, ForeignKey("bulk_requests.id"))
    farmer_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    
    pledged_weight_kg = Column(Float)
    actual_weight_kg = Column(Float, nullable=True) # Scale weight logged by coordinator
    
    status = Column(String, default="pledged") # pledged, dropped_off, rejected
    notes = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    bulk_request = relationship("BulkRequest", back_populates="pledges")
    farmer = relationship("User", back_populates="pledges")

class HubMessage(Base):
    __tablename__ = "hub_messages"
    
    id = Column(Integer, primary_key=True, index=True)
    hub_name = Column(String, index=True)
    sender_id = Column(Integer, ForeignKey("users.id"))
    message = Column(String)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    sender = relationship("User")

class MarketPrice(Base):
    __tablename__ = "market_prices"

    id = Column(Integer, primary_key=True, index=True)
    date = Column(Date) # 🔥 Make sure this says 'date', NOT 'ds'
    region = Column(String)
    county = Column(String)
    market = Column(String)
    market_id = Column(Integer)
    latitude = Column(Float)
    longitude = Column(Float)
    category = Column(String)
    commodity = Column(String)
    commodity_id = Column(Integer)
    unit = Column(String)
    price_flag = Column(String)
    market_type = Column(String) # 🔥 Make sure this says 'market_type', NOT 'pricetype'
    currency = Column(String)
    price_kes = Column(Float) # 🔥 Make sure this says 'price_kes', NOT 'price'
    price_usd = Column(Float)

class Hub(Base):
    __tablename__ = "hubs"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    crop = Column(String, index=True)
    center_latitude = Column(Float)
    center_longitude = Column(Float)
    
    coordinator_id = Column(Integer, ForeignKey("users.id"), nullable=True) 
    created_at = Column(DateTime, default=datetime.utcnow)

    coordinator = relationship("User", foreign_keys=[coordinator_id])
    members = relationship("User", back_populates="hub", foreign_keys="[User.hub_id]")
    requests = relationship("HubRequest", back_populates="hub")

class HubRequest(Base):
    __tablename__ = "hub_requests"
    
    id = Column(Integer, primary_key=True, index=True)
    hub_id = Column(Integer, ForeignKey("hubs.id"))
    farmer_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    status = Column(String, default="pending") 
    created_at = Column(DateTime, default=datetime.utcnow)

    hub = relationship("Hub", back_populates="requests")
    farmer = relationship("User")

class HubCandidate(Base):
    __tablename__ = "hub_candidates"
    
    id = Column(Integer, primary_key=True, index=True)
    hub_id = Column(Integer, ForeignKey("hubs.id"))
    farmer_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    pitch = Column(String) 
    created_at = Column(DateTime, default=datetime.utcnow)

class HubVote(Base):
    __tablename__ = "hub_votes"
    
    id = Column(Integer, primary_key=True, index=True)
    hub_id = Column(Integer, ForeignKey("hubs.id"))
    voter_id = Column(Integer, ForeignKey("users.id"))
    candidate_id = Column(Integer, ForeignKey("hub_candidates.id"))
    created_at = Column(DateTime, default=datetime.utcnow)

class SquadCandidate(Base):
    __tablename__ = "squad_candidates"

    id = Column(Integer, primary_key=True, index=True)
    bulk_request_id = Column(Integer, ForeignKey("bulk_requests.id", ondelete="CASCADE"))
    farmer_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    pitch = Column(String)
    votes = Column(Integer, default=0)

    # Relationships
    farmer = relationship("User")
    bulk_request = relationship("BulkRequest")

class SquadVote(Base):
    __tablename__ = "squad_votes"

    id = Column(Integer, primary_key=True, index=True)
    bulk_request_id = Column(Integer, ForeignKey("bulk_requests.id", ondelete="CASCADE"))
    farmer_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    candidate_id = Column(Integer, ForeignKey("squad_candidates.id", ondelete="CASCADE"))

class CachedPrediction(Base):
    __tablename__ = "cached_predictions"
    
    id = Column(Integer, primary_key=True, index=True)
    # We will combine crop, region, and type into one key like "maize_nairobi_wholesale"
    cache_key = Column(String, unique=True, index=True) 
    payload = Column(JSON) # Stores the exact dictionary Flutter expects!
    last_updated = Column(DateTime, default=datetime.utcnow)

class SquadMessage(Base):
    __tablename__ = "squad_messages"

    id = Column(Integer, primary_key=True, index=True)
    bulk_request_id = Column(Integer, ForeignKey("bulk_requests.id", ondelete="CASCADE"), nullable=False)
    sender_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    message = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationship to easily grab the sender's name
    sender = relationship("User")

class MarketListing(Base):
    __tablename__ = "market_listings"

    id = Column(Integer, primary_key=True, index=True)
    farmer_id = Column(Integer, ForeignKey("users.id"))
    crop_name = Column(String, index=True)
    
    base_inventory_kg = Column(Float)
    available_kg = Column(Float) 
    
    is_selling_by_weight = Column(Boolean, default=True)
    price_per_kg = Column(Float, nullable=True)
    
    unit_pricing = Column(JSON, default=list) 
    
    # 🔥 ADD THIS LINE RIGHT HERE!
    image_base64 = Column(String, nullable=True) 
    
    status = Column(String, default="active") 
    created_at = Column(DateTime, default=datetime.utcnow)

    farmer = relationship("User")
    orders = relationship("MarketOrder", back_populates="listing")

class MarketOrder(Base):
    __tablename__ = "market_orders"

    id = Column(Integer, primary_key=True, index=True)
    listing_id = Column(Integer, ForeignKey("market_listings.id"))
    buyer_id = Column(Integer, ForeignKey("users.id"))
    
    # 🔥 Updated to capture EXACTLY what they bought
    order_type = Column(String) # e.g., "weight", "Bucket", "Sack"
    quantity_ordered = Column(Float) 
    
    kg_deducted = Column(Float) 
    total_price = Column(Float)
    
    status = Column(String, default="pending") 
    created_at = Column(DateTime, default=datetime.utcnow)

    listing = relationship("MarketListing", back_populates="orders")
    buyer = relationship("User")

    delivery_method = Column(String, default="Delivery") 
    dispute_notes = Column(String, nullable=True)
    dispute_image = Column(String, nullable=True)