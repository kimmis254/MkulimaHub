import os
from dotenv import load_dotenv

load_dotenv()

# Database
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres:Waynekim254@localhost:5433/mkulimahub_db"
)

# JWT / Security
SECRET_KEY = os.getenv("SECRET_KEY", "supersecret_mkulimahub_key_change_this_later")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # 1 week

# Google OAuth
GOOGLE_CLIENT_ID = os.getenv(
    "GOOGLE_CLIENT_ID",
    "654543955611-g18qameesn4daglsc8pup7rkj6c1n541.apps.googleusercontent.com"
)

# Gemini AI
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")

# M-Pesa
MPESA_ENVIRONMENT = os.getenv("MPESA_ENVIRONMENT", "sandbox")
BACKEND_BASE_URL = os.getenv("BACKEND_BASE_URL", "")

# Clustering parameters
EARTH_RADIUS_KM = 6371.0
MAX_DISTANCE_KM = 5.0

# Kenya Counties (reference data)
KENYA_COUNTIES = [
    "Mombasa", "Kwale", "Kilifi", "Tana River", "Lamu", "Taita Taveta",
    "Garissa", "Wajir", "Mandera", "Marsabit", "Isiolo", "Meru",
    "Tharaka Nithi", "Embu", "Kitui", "Machakos", "Makueni", "Nyandarua",
    "Nyeri", "Kirinyaga", "Murang'a", "Kiambu", "Turkana", "West Pokot",
    "Samburu", "Trans Nzoia", "Uasin Gishu", "Elgeyo Marakwet", "Nandi",
    "Baringo", "Laikipia", "Nakuru", "Narok", "Kajiado", "Kericho",
    "Bomet", "Kakamega", "Vihiga", "Bungoma", "Busia", "Siaya",
    "Kisumu", "Homa Bay", "Migori", "Kisii", "Nyamira", "Nairobi"
]
