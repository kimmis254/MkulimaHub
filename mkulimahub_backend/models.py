from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Enum
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from geoalchemy2 import Geometry
from database import Base
import enum

# Define Roles
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
    
    # Link back to specific cluster (Assigned by your DBSCAN script)
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
    
    # Profile Fields
    bio = Column(String, nullable=True)
    farm_size_acres = Column(Float, nullable=True)
    main_crops = Column(String, nullable=True)
    farming_method = Column(String, nullable=True)

    # --- ADD THESE 4 LINES ---
    county = Column(String, nullable=True)
    sub_county = Column(String, nullable=True)
    ward = Column(String, nullable=True)
    village = Column(String, nullable=True)

    harvests = relationship("Harvest", back_populates="farmer")
# Note: We don't store "Clusters" as a permanent table yet, 
# because they change every time we run the algorithm.
# For now, we just assign a 'cluster_id' to the harvest.