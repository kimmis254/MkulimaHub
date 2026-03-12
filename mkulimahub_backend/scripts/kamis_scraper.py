import os
import time
import pandas as pd
import re
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from webdriver_manager.chrome import ChromeDriverManager

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(BASE_DIR, "data")

def clean_price(price_str):
    cleaned = re.sub(r'[^\d.]', '', str(price_str))
    try:
        return float(cleaned) if cleaned else None
    except ValueError:
        return None

def run_historical_heist():
    print("🚀 INITIATING MASSIVE HISTORICAL DATA HEIST (2005 - 2026)...")
    print("⚠️ This will scrape all ~3,500 pages. Grab a coffee, this will take a while!")
    
    options = Options()
    # options.add_argument("--headless") # Keep it off if you want to watch it work!
    options.add_argument("--window-size=1920,1080")
    options.add_argument("--disable-gpu")
    options.add_argument("--no-sandbox")

    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=options)
    processed_records = []
    
    try:
        page_number = 1
        
        while True:
            url = f"https://kamis.kilimo.go.ke/site/market?page={page_number}"
            print(f"🌍 Extracting Page {page_number} of ~3500...")
            driver.get(url)
            
            # Brief pause to let the table render
            time.sleep(4) 
            
            tables = driver.find_elements(By.TAG_NAME, "table")
            if len(tables) == 0:
                print("🛑 No table found. We reached the end of the 2005 data!")
                break

            target_table = tables[0]
            rows = target_table.find_elements(By.TAG_NAME, "tr")
            
            if len(rows) <= 1:
                print("🛑 Table is empty. Heist Complete!")
                break
                
            valid_rows_on_page = 0
            
            for row in rows[1:]: 
                cols = row.find_elements(By.TAG_NAME, "td")
                
                if len(cols) == 1 and "No results" in cols[0].text:
                    print("🛑 Reached 'No results found'. Heist Complete.")
                    break
                    
                if len(cols) >= 10: 
                    commodity_raw = cols[1].text.strip()
                    ws_price_raw = cols[5].text.strip()
                    rt_price_raw = cols[6].text.strip()
                    county_raw = cols[8].text.strip()
                    date_raw = cols[9].text.strip()
                    
                    commodity = commodity_raw.lower().replace("dry", "").replace("white", "").strip()
                    if not commodity or commodity == '-':
                        commodity = cols[0].text.strip().lower() 
                    
                    market = county_raw.lower().strip()
                    ws_price = clean_price(ws_price_raw)
                    rt_price = clean_price(rt_price_raw)
                    
                    added = False
                    if ws_price and ws_price > 0:
                        processed_records.append({
                            "ds": date_raw, "market": market, "commodity": commodity, 
                            "pricetype": "wholesale", "price": ws_price
                        })
                        added = True
                    
                    if rt_price and rt_price > 0:
                        processed_records.append({
                            "ds": date_raw, "market": market, "commodity": commodity, 
                            "pricetype": "retail", "price": rt_price
                        })
                        added = True
                        
                    if added:
                        valid_rows_on_page += 1
            
            if valid_rows_on_page == 0:
                print(f"🛑 No valid data on Page {page_number}. Ending Heist.")
                break
                
            page_number += 1
                
        print(f"✅ HEIST SUCCESSFUL! Extracted {len(processed_records)} historical records.")
        
        if len(processed_records) == 0:
            return

        # 🔥 INJECT 20 YEARS OF DATA INTO OUR CSVs
        df_new = pd.DataFrame(processed_records)
        counties_found = df_new['market'].unique()
        
        os.makedirs(DATA_DIR, exist_ok=True)
        
        for county in counties_found:
            safe_county = county.replace(" ", "_")
            file_path = os.path.join(DATA_DIR, f"market_prices_{safe_county}.csv")
            county_df = df_new[df_new['market'] == county]
            
            if os.path.exists(file_path):
                df_existing = pd.read_csv(file_path)
                df_combined = pd.concat([df_existing, county_df], ignore_index=True)
                df_combined.drop_duplicates(subset=['ds', 'commodity', 'pricetype'], keep='last', inplace=True)
                df_combined.to_csv(file_path, index=False)
            else:
                county_df.to_csv(file_path, index=False)
                
        print(f"🎉 2005-2026 Data injected into {len(counties_found)} counties!")

    except Exception as e:
        print(f"🛑 Scraper crashed: {e}")
    finally:
        print("🧹 Cleaning up and closing browser...")
        driver.quit()

if __name__ == "__main__":
    run_historical_heist()