import sqlite3

# Connect to your existing database safely
conn = sqlite3.connect('mkulimahub.db') 
cursor = conn.cursor()

try:
    # 1. FREE THE FARMERS: Remove them from any existing hubs 
    # (This updates the column to NULL without deleting the actual user)
    cursor.execute("UPDATE users SET hub_id = NULL;")
    print("✅ All farmers are now Independent.")

    # 2. DESTROY THE OLD CO-OP TABLES
    cursor.execute("DROP TABLE IF EXISTS hub_votes;")
    cursor.execute("DROP TABLE IF EXISTS hub_candidates;")
    cursor.execute("DROP TABLE IF EXISTS hub_requests;")
    cursor.execute("DROP TABLE IF EXISTS hubs;")
    print("✅ Old Hubs and Election tables securely deleted.")

    conn.commit()
    print("🎉 Reset complete! Your crop data and user profiles are 100% safe.")

except Exception as e:
    print(f"⚠️ Error occurred: {e}")

finally:
    conn.close()