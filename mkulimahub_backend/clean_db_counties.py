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
    "trans-nzoia": "trans_nzoia",
    "uasin-gishu": "uasin_gishu",
    "homabay": "homa bay",
    "makutano": "west_pokot"
}

def scrub_database():
    print("🧹 Starting Bulletproof Database Scrub...")
    db = SessionLocal()
    
    try:
        # 1. Get the EXACT raw values currently sitting in the DB
        distinct_markets = db.query(models.MarketPrice.county).distinct().all()
        
        updates_made = 0
        total_rows_changed = 0
        
        for market in distinct_markets:
            raw_name = market[0]
            if not raw_name: continue
            
            # 2. Use Python to brutally strip invisible spaces and make it lowercase
            clean_name = raw_name.lower().strip()
            
            # 3. Check our dictionary. If it's not in the dictionary (like 'bomet'), 
            # we just use the clean_name so it still fixes whitespace/capitalization!
            target_county = TOWN_TO_COUNTY.get(clean_name, clean_name)
                
            # 4. If the raw DB name is different from the target, run the UPDATE
            if raw_name != target_county:
                updated_rows = db.query(models.MarketPrice)\
                    .filter(models.MarketPrice.county == raw_name)\
                    .update({"county": target_county}, synchronize_session=False)
                
                total_rows_changed += updated_rows
                updates_made += 1
                print(f"✅ Fixed {updated_rows} rows: '{raw_name}' -> '{target_county}'")
                
        db.commit()
        print(f"\n🎉 Scrub Complete! Fixed {updates_made} messy market names, updating {total_rows_changed} total rows.")
        
    except Exception as e:
        db.rollback()
        print(f"❌ Error during scrub: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    scrub_database()