import os
import pandas as pd
from database import engine
from sqlalchemy import text

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(BASE_DIR, "data")

def run_migration():
    print("🚀 Initiating The Great Migration (CSV to SQL Database)...")
    
    all_frames = []
    
    # 1. Read every single master CSV file
    for file in os.listdir(DATA_DIR):
        if file.startswith("master_") and file.endswith(".csv"):
            county_name = file.replace("master_", "").replace(".csv", "")
            file_path = os.path.join(DATA_DIR, file)
            
            df = pd.read_csv(file_path)
            if not df.empty and 'commodity' in df.columns:
                df['county'] = county_name # Attach the county name to the row
                all_frames.append(df)
                
    if not all_frames:
        print("❌ No CSV files found to migrate.")
        return

    # 2. Combine into one massive super-dataframe
    master_df = pd.concat(all_frames, ignore_index=True)
    
    # Clean up the data to match our new SQL columns exactly
    master_df['commodity'] = master_df['commodity'].astype(str).str.lower().str.strip()
    master_df['pricetype'] = master_df['pricetype'].astype(str).str.lower().str.strip()
    master_df['ds'] = pd.to_datetime(master_df['ds']).dt.date # Ensure it is a strict Date object
    
    # Keep only the columns we need
    final_df = master_df[['county', 'commodity', 'pricetype', 'price', 'ds']]
    
    # Remove duplicates just in case the CSVs had messy overlaps
    final_df = final_df.drop_duplicates(subset=['county', 'commodity', 'pricetype', 'ds'], keep='last')

    print(f"📊 Processed {len(final_df)} total historical records. Injecting into Database...")

    # 3. FAST SQL INJECTION: Use Pandas to blast the data into the SQLAlchemy engine
    try:
        final_df.to_sql('market_prices', con=engine, if_exists='append', index=False)
        print("✅ MIGRATION SUCCESSFUL! The Database is now fully populated.")
    except Exception as e:
        print(f"⚠️ Migration issue (you might have run this twice, triggering the duplicate shield): {e}")

if __name__ == "__main__":
    run_migration()