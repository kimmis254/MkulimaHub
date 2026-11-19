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
import random

from database import SessionLocal
import models
from sqlalchemy.exc import IntegrityError

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

STANDARD_WEIGHTS_KG = {
    "maize": 90.0, "beans": 90.0, "sorghum": 90.0, "millet": 90.0,
    "wheat": 90.0, "green grams": 90.0, "cowpeas": 90.0, "rice": 50.0,
    "potatoes": 50.0, "irish potatoes": 50.0, "sweet potatoes": 98.0,
    "tomatoes": 64.0, "onions": 13.0, "cabbage": 126.0, "carrots": 138.0,
    "capsicums": 50.0, "sukuma wiki": 50.0, "spinach": 50.0
}

def clean_price(price_str):
    cleaned = re.sub(r'[^\d.]', '', str(price_str))
    try:
        return float(cleaned) if cleaned else None
    except ValueError:
        return None

def save_batch_to_db(records):
    if not records: return 0
    db = SessionLocal()
    new_inserts = 0
    for record in records:
        try:
            new_price = models.MarketPrice(
                county=record["county"], commodity=record["commodity"],
                market_type=record["pricetype"], price_kes=record["price"], date=record["ds"]
            )
            db.add(new_price)
            db.commit()
            new_inserts += 1
        except IntegrityError:
            db.rollback() 
    db.close()
    return new_inserts

def create_driver():
    """Spins up a fresh, memory-clean headless Chrome browser."""
    options = Options()
    options.add_argument("--headless") 
    options.add_argument("--window-size=1920,1080")
    options.add_argument("--disable-gpu")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-extensions")
    options.add_argument("--blink-settings=imagesEnabled=false") 

    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=options)
    driver.set_page_load_timeout(300) 
    return driver

def run_daily_scraper(is_deep_scrape=False, start_crop=1, start_page=1):
    
    if is_deep_scrape:
        print(f"🌙 INITIATING 'GOD MODE' DEEP SCRAPE (Target: 2020, No Limits)...")
    else:
        print("🌙 INITIATING DAILY MIDNIGHT SCRAPE...")
    
    driver = create_driver()
    batch_records = []
    total_saved_overall = 0
    
    crop_ids_to_scrape = range(start_crop, 273) 

    try:
        for crop_id in crop_ids_to_scrape:
    
            
            page_number = start_page if crop_id == start_crop else 1
            max_pages = 100 if is_deep_scrape else 1 # 🔥 Removes the 100-page limit
            records_for_this_crop = 0
            old_date_strikes = 0
            
            while page_number <= max_pages:
                
                if page_number > start_page and page_number % 50 == 0:
                    print("Restarting Chrome to free up system memory...")
                    driver.quit()
                    driver = create_driver()
                
                url = f"https://kamis.kilimo.go.ke/site/market?product={crop_id}&per_page=100&page={page_number}"
                driver.get(url)
                sleep_time = random.uniform(4, 8) 
                print(f"  ⏳ Waiting {sleep_time:.2f} seconds to be polite to the server...")
                time.sleep(sleep_time)
                
                tables = driver.find_elements(By.TAG_NAME, "table")
                if not tables or "No results" in tables[0].text:
                    print(f" No results for Crop ID {crop_id} at page {page_number}. Exhausted or invalid ID. Moving to next crop.")
                    break 

                rows = tables[0].find_elements(By.TAG_NAME, "tr")
                if len(rows) <= 1: 
                    break
                    
                records_found_on_page = 0
                target_reached = False
                
                for row in rows[1:]: 
                    cols = row.find_elements(By.TAG_NAME, "td")
                    
                    if len(cols) == 1 and "No results" in cols[0].text: 
                        target_reached = True
                        break
                        
                    if len(cols) >= 10: 
                        records_found_on_page += 1
                        records_for_this_crop += 1
                        
                        date_raw = cols[9].text.strip()
                        try: sql_date = datetime.strptime(date_raw, "%d-%b-%Y").date()
                        except: sql_date = pd.to_datetime(date_raw).date()
                            
                        if is_deep_scrape and sql_date.year < 2020:
                            old_date_strikes += 1
                            if old_date_strikes >= 15:
                                print(f"  🛑 Safely reached {sql_date.strftime('%B %Y')}. 2020 Target Achieved for this crop!")
                                target_reached = True 
                                break
                            else:
                                continue 
                        else:
                            if sql_date.year >= 2020 and sql_date.year <= datetime.now().year + 1:
                                old_date_strikes = 0
                        
                        commodity = cols[1].text.strip().lower().replace("dry", "").replace("white", "").strip()
                        if not commodity or commodity == '-': commodity = cols[0].text.strip().lower() 
                        
                        market_raw = cols[8].text.strip().lower()
                        county = TOWN_TO_COUNTY.get(market_raw, market_raw)
                        
                        weight_divisor = 1.0
                        for key, weight in STANDARD_WEIGHTS_KG.items():
                            if key in commodity:
                                weight_divisor = weight
                                break
                        
                        ws_price = clean_price(cols[5].text.strip())
                        if ws_price and ws_price > 300: ws_price = round(ws_price / weight_divisor, 2)
                            
                        rt_price = clean_price(cols[6].text.strip())
                        if rt_price and rt_price > 300: rt_price = round(rt_price / weight_divisor, 2)
                        
                        if ws_price and ws_price > 0: batch_records.append({"county": county, "commodity": commodity, "pricetype": "wholesale", "price": ws_price, "ds": sql_date})
                        if rt_price and rt_price > 0: batch_records.append({"county": county, "commodity": commodity, "pricetype": "retail", "price": rt_price, "ds": sql_date})
                
                if records_found_on_page > 0:
                    print(f"Crop {crop_id} - Page {page_number}: Extracted {records_found_on_page} rows. (Crop Total: {records_for_this_crop})")
                
                if len(batch_records) >= 500:
                    saved = save_batch_to_db(batch_records)
                    total_saved_overall += saved
                    print(f"  💾 Auto-saved buffer. (Session total: {total_saved_overall})")
                    batch_records.clear() 

                if target_reached:
                    break
                
                disabled_next = driver.find_elements(By.XPATH, "//li[contains(@class, 'next') and contains(@class, 'disabled')]")
                if disabled_next:
                    print(f"  🏁 Reached final available page for Crop ID {crop_id}.")
                    break
                    
                page_number += 1
            
        if len(batch_records) > 0:
            total_saved_overall += save_batch_to_db(batch_records)
            
        print(f"Sequence complete! Successfully secured {total_saved_overall} diverse crop records.")

    except Exception as e:
        print(f"Scraper crashed: {e}")
        if len(batch_records) > 0: save_batch_to_db(batch_records)
    finally:
        driver.quit()

if __name__ == "__main__":
    RESUME_CROP = 129
    RESUME_PAGE = 1 
    
    run_daily_scraper(is_deep_scrape=True, start_crop=RESUME_CROP, start_page=RESUME_PAGE)