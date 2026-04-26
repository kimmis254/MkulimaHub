from database import engine
from sqlalchemy import text

def patch_database():
    print("🛠️ Patching the database with the new 'status' column...")
    try:
        with engine.connect() as conn:
            # 🔥 THE FIX: Changed the table name to bulk_requests! 
            # (If your __tablename__ in models.py is different, use that instead)
            conn.execute(text("ALTER TABLE bulk_requests ADD COLUMN IF NOT EXISTS status VARCHAR DEFAULT 'open';"))
            conn.commit()
            print("✅ Patch successful! Contracts now have a status column.")
    except Exception as e:
        print(f"❌ Error patching database: {e}")

if __name__ == "__main__":
    patch_database()