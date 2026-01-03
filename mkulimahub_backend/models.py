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

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    full_name = Column(String, nullable=False)
    phone_number = Column(String, unique=True, index=True, nullable=False)
    role = Column(String, default="farmer") # 'farmer' or 'buyer'
    password_hash = Column(String, nullable=False)
    
    # GEO-SPATIAL MAGIC: This column stores GPS coords as a geometry point
    # srid=4326 is the standard ID for GPS coordinates (WGS84)
    location = Column(Geometry('POINT', srid=4326), nullable=True) 
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    harvests = relationship("Harvest", back_populates="farmer")

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

# Note: We don't store "Clusters" as a permanent table yet, 
# because they change every time we run the algorithm.
# For now, we just assign a 'cluster_id' to the harvest.