import os
import time
import pandas as pd
import re
from datetime import datetime
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from webdriver_manager.chrome import ChromeDriverManager

# 🔥 Import your database tools
from database import SessionLocal
import models
from sqlalchemy.exc import IntegrityError

# 🔥 The Master Geocoder Dictionary
TOWN_TO_COUNTY = {
    "nairobi": "nairobi", "dandora": "nairobi", "kangemi": "nairobi", "kawangware": "nairobi", 
    "mathare": "nairobi", "wakulima_nairobi": "nairobi", "kibra": "nairobi", "mukuru": "nairobi", 
    "mombasa": "mombasa", "kongowea": "mombasa", "vanga": "kwale", "kilifi": "kilifi",
    "nakukulas": "turkana", "lodwar": "turkana", "kakuma": "turkana", "lokichar": "turkana",
    "garissa": "garissa", "dadaab": "garissa", "wajir": "wajir", "mandera": "mandera",
    "marsabit": "marsabit", "moyale": "marsabit", "isiolo": "isiolo", "maralal": "samburu",
    "marigat": "baringo", "makutano": "west_pokot", "makueni": "makueni", "tala": "machakos", 
    "kajiado": "kajiado", "kitengela": "kajiado", "nakuru": "nakuru", "eldoret": "uasin_gishu", 
    "trans-nzoia": "trans_nzoia", "kisumu": "kisumu", "kibuye": "kisumu", "kakamega": "kakamega",
    "karatina": "nyeri", "meru": "meru", "kitui": "kitui", "kirinyaga": "kirinyaga", "bomet": "bomet"
}

def clean_price(price_str):
    cleaned = re.sub(r'[^\d.]', '', str(price_str))
    try:
        return float(cleaned) if cleaned else None
    except ValueError:
        return None

def run_daily_scraper():
    print("🌙 INITIATING DAILY MIDNIGHT SCRAPE...")
    
    options = Options()
    options.add_argument("--headless") # 🔥 Turned on Headless so it runs silently in the background!
    options.add_argument("--window-size=1920,1080")
    options.add_argument("--disable-gpu")
    options.add_argument("--no-sandbox")

    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=options)
    processed_records = []
    
    try:
        page_number = 1
        MAX_PAGES = 2 # 🔥 SPEED LIMIT: Only check the first 2 pages for new daily data!
        
        while page_number <= MAX_PAGES:
            url = f"https://kamis.kilimo.go.ke/site/market?page={page_number}"
            print(f"🌍 Extracting Page {page_number} of {MAX_PAGES}...")
            driver.get(url)
            time.sleep(4) 
            
            tables = driver.find_elements(By.TAG_NAME, "table")
            if len(tables) == 0: break

            target_table = tables[0]
            rows = target_table.find_elements(By.TAG_NAME, "tr")
            
            if len(rows) <= 1: break
                
            for row in rows[1:]: 
                cols = row.find_elements(By.TAG_NAME, "td")
                
                if len(cols) == 1 and "No results" in cols[0].text: break
                    
                if len(cols) >= 10: 
                    commodity_raw = cols[1].text.strip()
                    ws_price_raw = cols[5].text.strip()
                    rt_price_raw = cols[6].text.strip()
                    market_raw = cols[8].text.strip().lower()
                    date_raw = cols[9].text.strip()
                    
                    commodity = commodity_raw.lower().replace("dry", "").replace("white", "").strip()
                    if not commodity or commodity == '-':
                        commodity = cols[0].text.strip().lower() 
                    
                    # 🔥 Map the market to the true county
                    county = TOWN_TO_COUNTY.get(market_raw, market_raw)
                    
                    ws_price = clean_price(ws_price_raw)
                    rt_price = clean_price(rt_price_raw)
                    
                    # Format date for SQL
                    try:
                        sql_date = datetime.strptime(date_raw, "%d-%b-%Y").date()
                    except:
                        sql_date = pd.to_datetime(date_raw).date()
                    
                    if ws_price and ws_price > 0:
                        processed_records.append({
                            "county": county, "commodity": commodity, 
                            "pricetype": "wholesale", "price": ws_price, "ds": sql_date
                        })
                    
                    if rt_price and rt_price > 0:
                        processed_records.append({
                            "county": county, "commodity": commodity, 
                            "pricetype": "retail", "price": rt_price, "ds": sql_date
                        })
            
            page_number += 1
                
        print(f"✅ Scraping complete. Found {len(processed_records)} new records. Injecting into Database...")
        
        if len(processed_records) == 0:
            return

        # 🔥 INJECT DIRECTLY INTO SQL DATABASE
        db = SessionLocal()
        new_inserts = 0
        duplicates = 0
        
        for record in processed_records:
            try:
                new_price = models.MarketPrice(
                    county=record["county"],
                    commodity=record["commodity"],
                    pricetype=record["pricetype"],
                    price=record["price"],
                    ds=record["ds"]
                )
                db.add(new_price)
                db.commit()
                new_inserts += 1
            except IntegrityError:
                # This safely catches records we already downloaded yesterday and ignores them!
                db.rollback()
                duplicates += 1
                
        db.close()
        print(f"🎉 Database updated! {new_inserts} new rows added. (Skipped {duplicates} existing duplicates).")

    except Exception as e:
        print(f"🛑 Scraper crashed: {e}")
    finally:
        driver.quit()

if __name__ == "__main__":
    run_daily_scraper()