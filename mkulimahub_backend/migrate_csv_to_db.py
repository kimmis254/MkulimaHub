import os
import pandas as pd
from database import engine, SessionLocal
from sqlalchemy import text

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(BASE_DIR, "data")

# 🔥 1. THE OFFICIAL BOUNCER LIST
KENYA_COUNTIES = [
    "Mombasa", "Kwale", "Kilifi", "Tana River", "Lamu", "Taita Taveta", 
    "Garissa", "Wajir", "Mandera", "Marsabit", "Isiolo", "Meru", 
    "Tharaka Nithi", "Embu", "Kitui", "Machakos", "Makueni", "Nyandarua", 
    "Nyeri", "Kirinyaga", "Muranga", "Kiambu", "Turkana", "West Pokot", 
    "Samburu", "Trans Nzoia", "Uasin Gishu", "Elgeyo Marakwet", "Nandi", 
    "Baringo", "Laikipia", "Nakuru", "Narok", "Kajiado", "Kericho", 
    "Bomet", "Kakamega", "Vihiga", "Bungoma", "Busia", "Siaya", 
    "Kisumu", "Homa Bay", "Migori", "Kisii", "Nyamira", "Nairobi"
]

# 🔥 2. THE GEOCODER DICTIONARY (Maps messy filenames to Official Counties)
TOWN_TO_COUNTY = {
    # Garissa Markets
    "adele": "Garissa", "adele_copy": "Garissa", "alango_arba": "Garissa",
    "dadaab": "Garissa", "kotile": "Garissa", "masalani": "Garissa",
    "mathaxgesi": "Garissa", "shanta_abak": "Garissa", "shauri_yako": "Garissa",
    "suq_jini": "Garissa",

    # Turkana Markets
    "kakuma_2": "Turkana", "kakuma_3": "Turkana", "kakuma_4": "Turkana",
    "kang'akipur": "Turkana", "lodwar": "Turkana", "lokichar": "Turkana",
    "lokipoto": "Turkana", "morulem": "Turkana", "nakukulas": "Turkana",

    # Marsabit Markets
    "dambala_fachana": "Marsabit", "dub_goba": "Marsabit", "kargi_south_horr": "Marsabit",
    "kasuroi": "Marsabit", "moyale": "Marsabit", "north_horr": "Marsabit",
    "sololo": "Marsabit", "walda": "Marsabit",

    # Isiolo Markets
    "bulesa_bulesa": "Isiolo", "kinna": "Isiolo", "kulamawe": "Isiolo", "malka_galla": "Isiolo",

    # Baringo Markets
    "amaya": "Baringo", "kimalel": "Baringo", "koriema": "Baringo", "marigat": "Baringo",

    # Samburu Markets
    "archers_post": "Samburu", "maralal": "Samburu", "tuum": "Samburu",

    # Kilifi Markets
    "bamba": "Kilifi", "dzikunze": "Kilifi", "kachororoni": "Kilifi",
    "kaembeni": "Kilifi", "kisumu_ndogo": "Kilifi", "malindi": "Kilifi",

    # Mandera Markets
    "el_wak": "Mandera",

    # Kajiado Markets
    "illbissil_food": "Kajiado", "kitengela": "Kajiado", "loitokitok": "Kajiado", "namanga": "Kajiado",

    # Makueni Markets
    "emali": "Makueni", "mtito_andei": "Makueni",

    # Other Towns to Counties
    "awasi": "Kisumu", "katito": "Kisumu", "maseno": "Kisumu", "kibuye": "Kisumu",
    "chwele": "Bungoma", "kimilili": "Bungoma", "webuye": "Bungoma",
    "dagoretti": "Nairobi", "dandora": "Nairobi", "gikomba": "Nairobi", "kangemi": "Nairobi",
    "kawangware": "Nairobi", "kibra": "Nairobi", "mathare": "Nairobi", "mukuru": "Nairobi",
    "wakulima_nairobi": "Nairobi",
    "mumias": "Kakamega", "karatina": "Nyeri", "kilgoris": "Narok",
    "kinango": "Kwale", "vanga": "Kwale", "mwea": "Kirinyaga",
    "kongowea": "Mombasa", "matuu": "Machakos", "tala": "Machakos",
    "maua": "Meru", "naivasha": "Nakuru", "nyahururu": "Laikipia", "taveta": "Taita Taveta",
    "homabay": "Homa Bay", "makutano": "West Pokot",
    
    # Files that are counties but have weird underscores in the filename
    "trans_nzoia": "Trans Nzoia", "uasin_gishu": "Uasin Gishu", "tana_river": "Tana River",
    "tharaka_nithi": "Tharaka Nithi", "west_pokot": "West Pokot"
}

def master_reset_and_migrate():
    print("🧨 STEP 1: Vaporizing all old data...")
    db = SessionLocal()
    try:
        db.execute(text("TRUNCATE TABLE market_prices RESTART IDENTITY CASCADE;"))
        db.commit()
        print("✅ Database is completely empty and clean.")
    except Exception as e:
        db.rollback()
        print(f"⚠️ Error wiping table: {e}")
        return
    finally:
        db.close()

    print("\n🚀 STEP 2: Extracting pristine data from CSVs...")
    all_frames = []
    unmapped_files = set()
    
    for file in os.listdir(DATA_DIR):
        if file.startswith("master_") and file.endswith(".csv"):
            raw_name = file.replace("master_", "").replace(".csv", "").strip().lower()
            
            # 3. USE THE GEOCODER
            # If the filename is already a county (like "bomet"), title-case it.
            # If it's a town (like "alango_arba"), look it up in the dictionary.
            target_county = TOWN_TO_COUNTY.get(raw_name, raw_name.title().replace("_", " "))
            
            file_path = os.path.join(DATA_DIR, file)
            df = pd.read_csv(file_path)
            
            if not df.empty and 'commodity' in df.columns:
                df['county'] = target_county # Inject our perfectly mapped county!
                all_frames.append(df)

    if not all_frames:
        print("❌ No CSV files found.")
        return

    master_df = pd.concat(all_frames, ignore_index=True)
    
    # 4. Clean strings
    master_df['commodity'] = master_df['commodity'].astype(str).str.lower().str.strip()
    master_df['pricetype'] = master_df['pricetype'].astype(str).str.lower().str.strip()
    master_df['ds'] = pd.to_datetime(master_df['ds']).dt.date 
    
    # 5. 🔥 THE BOUNCER: STRICTLY ENFORCE ONLY THE 47 COUNTIES
    initial_count = len(master_df)
    master_df = master_df[master_df['county'].isin(KENYA_COUNTIES)]
    dropped_count = initial_count - len(master_df)
    
    if dropped_count > 0:
        print(f"🛡️ The Bouncer blocked {dropped_count} rows from entering (Locations were not official counties).")
    
    final_df = master_df[['county', 'commodity', 'pricetype', 'price', 'ds']]
    
    final_df = final_df.rename(columns={
        'pricetype': 'market_type',
        'price': 'price_kes',
        'ds': 'date'
    })
    
    final_df = final_df.drop_duplicates(subset=['county', 'commodity', 'market_type', 'date'], keep='last')

    print(f"📊 Processed {len(final_df)} perfectly mapped, official records. Injecting into Database...")

    try:
        final_df.to_sql('market_prices', con=engine, if_exists='append', index=False)
        print("✅ MIGRATION SUCCESSFUL! The database is perfect.")
    except Exception as e:
        print(f"⚠️ Migration issue: {e}")

if __name__ == "__main__":
    master_reset_and_migrate()