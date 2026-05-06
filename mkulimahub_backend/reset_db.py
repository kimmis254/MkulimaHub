from database import engine, SessionLocal
from sqlalchemy import text
import models

db = SessionLocal()

print("💥 Selectively dropping contract and marketplace tables...")

# A precise list of ONLY the tables we want to wipe and rebuild
tables_to_drop = [
    "market_orders",
    "market_listings",
    "pledges",
    "squad_votes",
    "squad_candidates",
    "squad_messages",
    "bulk_requests",
    "hub_messages",
    "users"
]

for table in tables_to_drop:
    try:
        # CASCADE ensures we don't get "Foreign Key Constraint" crash errors
        db.execute(text(f"DROP TABLE IF EXISTS {table} CASCADE;"))
        print(f" - Dropped {table}")
    except Exception as e:
        print(f" - Error dropping {table}: {e}")

db.commit()
db.close()

print("\n🏗️ Rebuilding the dropped tables with the new schema...")
# This will ONLY create tables that are missing. 
# It will see "users" and "market_prices" already exist and leave them completely untouched!
models.Base.metadata.create_all(bind=engine)

print("✅ Success! Your contracts are wiped, but Users and Market Prices are perfectly safe.")