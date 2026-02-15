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
    password_hash = Column(String)
    role = Column(String)
    
    # EXISTING Location (Keep this!)
    location = Column(Geometry(geometry_type='POINT', srid=4326))
    
    # --- NEW PROFILE FIELDS ---
    bio = Column(String, nullable=True)             # e.g., "I have been farming maize for 10 years."
    farm_size_acres = Column(Float, nullable=True)  # e.g., 2.5
    main_crops = Column(String, nullable=True)      # e.g., "Maize, Beans, Avocado"
    farming_method = Column(String, nullable=True)  # e.g., "Organic" or "Conventional"
    profile_image_url = Column(String, nullable=True) # URL to their photo (optional for now)

    harvests = relationship("Harvest", back_populates="farmer")
# Note: We don't store "Clusters" as a permanent table yet, 
# because they change every time we run the algorithm.
# For now, we just assign a 'cluster_id' to the harvest.