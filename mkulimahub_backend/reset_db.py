from database import engine
import models

print("🚨 Dropping old database tables...")
models.Base.metadata.drop_all(bind=engine)

print("✨ Recreating brand new tables with Latitude & Longitude...")
models.Base.metadata.create_all(bind=engine)

print("✅ Done! You can now restart your server.")