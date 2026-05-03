from database import engine
from sqlalchemy import text

print("🚀 Connecting to PostgreSQL...")

with engine.connect() as conn:
    print("🧨 Surgically wiping transactional data (Keeping Users & Market Prices)...")
    
    # 🔥 TRUNCATE empties the tables instantly. 
    # CASCADE ensures any linked foreign keys are also cleared out safely.
    conn.execute(text("""
        TRUNCATE 
            harvests, 
            bulk_requests, 
            pledges, 
            squad_messages, 
            hub_messages, 
            hub_requests, 
            hub_candidates, 
            hub_votes, 
            squad_candidates, 
            squad_votes, 
            hubs
        CASCADE;
    """))
    conn.commit()

print("✅ Database cleaned! Users and Market Prices survived the wipe.")