from database import SessionLocal
import models

# 🔥 The Master Geocoder Dictionary
TOWN_TO_COUNTY = {
    "awasi": "kisumu", "katito": "kisumu", "maseno": "kisumu", "kibuye": "kisumu", "kisumu": "kisumu",
    "bamba": "kilifi", "malindi": "kilifi", "kilifi": "kilifi",
    "chwele": "bungoma", "kimilili": "bungoma", "webuye": "bungoma",
    "dadaab": "garissa", "garissa": "garissa",
    "dagoretti": "nairobi", "dandora": "nairobi", "gikomba": "nairobi", "kangemi": "nairobi", 
    "kawangware": "nairobi", "kibra": "nairobi", "mathare": "nairobi", "mukuru": "nairobi", 
    "wakulima_nairobi": "nairobi", "nairobi": "nairobi",
    "emali": "makueni", "makueni": "makueni", "mtito andei": "makueni",
    "loitokitok": "kajiado", "namanga": "kajiado", "kitengela": "kajiado", "kajiado": "kajiado",
    "mumias": "kakamega", "kakamega": "kakamega",
    "kakuma": "turkana", "lodwar": "turkana", "lokichar": "turkana", "nakukulas": "turkana", "turkana": "turkana",
    "karatina": "nyeri", "nyeri": "nyeri",
    "kilgoris": "narok", "narok": "narok",
    "kinango": "kwale", "vanga": "kwale", "kwale": "kwale",
    "mwea": "kirinyaga", "kirinyaga": "kirinyaga",
    "kongowea": "mombasa", "mombasa": "mombasa",
    "matuu": "machakos", "tala": "machakos", "machakos": "machakos",
    "maralal": "samburu",
    "marigat": "baringo",
    "moyale": "marsabit", "marsabit": "marsabit",
    "maua": "meru", "meru": "meru",
    "naivasha": "nakuru", "nakuru": "nakuru",
    "nyahururu": "laikipia",
    "taveta": "taita taveta",
    "trans-nzoia": "trans nzoia", # Removed underscore for clean title
    "uasin-gishu": "uasin gishu", # Removed underscore for clean title
    "homabay": "homa bay",
    "makutano": "west pokot"      # Removed underscore for clean title
}

def scrub_database():
    print("🧹 Starting Bulletproof Database Scrub...")
    db = SessionLocal()
    
    try:
        distinct_markets = db.query(models.MarketPrice.county).distinct().all()
        
        updates_made = 0
        total_rows_changed = 0
        
        for market in distinct_markets:
            raw_name = market[0]
            if not raw_name: continue
            
            # 1. Brutal strip and lowercase for dictionary matching
            clean_name = raw_name.lower().strip()
            
            # 2. Check the dictionary map
            if clean_name in TOWN_TO_COUNTY:
                target_name = TOWN_TO_COUNTY[clean_name]
            else:
                # 🔥 THE FIX: If it's not in the dictionary, aggressively scrub the weird artifacts!
                target_name = clean_name.replace("_", " ").replace(" copy", "").replace("-", " ").strip()
                
            # 3. 🔥 THE FIX: Force beautiful Title Case formatting (e.g., "Alango Arba", "Turkana")
            final_clean_county = target_name.title()
                
            # 4. If the raw DB name is different from the target, run the UPDATE
            if raw_name != final_clean_county:
                updated_rows = db.query(models.MarketPrice)\
                    .filter(models.MarketPrice.county == raw_name)\
                    .update({"county": final_clean_county}, synchronize_session=False)
                
                total_rows_changed += updated_rows
                updates_made += 1
                print(f"✅ Fixed {updated_rows} rows: '{raw_name}' -> '{final_clean_county}'")
                
        db.commit()
        print(f"\n🎉 Scrub Complete! Fixed {updates_made} messy market names, updating {total_rows_changed} total rows.")
        
    except Exception as e:
        db.rollback()
        print(f"❌ Error during scrub: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    scrub_database()