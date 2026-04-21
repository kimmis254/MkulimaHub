from database import engine
from sqlalchemy import text
import models

print("🚀 Connecting to PostgreSQL...")

# 🔥 THE NUKE: Bypass SQLAlchemy sorting and force PostgreSQL to wipe everything instantly!
with engine.connect() as conn:
    print("🧨 Dropping the entire public schema...")
    conn.execute(text("DROP SCHEMA public CASCADE;"))
    conn.execute(text("CREATE SCHEMA public;"))
    conn.commit()

# 🔥 THE PAVE: Rebuild all tables with your new strict CASCADE rules
print("🏗️ Building fresh tables...")
models.Base.metadata.create_all(bind=engine)

print("✅ Database is 100% clean, empty, and rebuilt!")