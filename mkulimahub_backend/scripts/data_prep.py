import pandas as pd
import os
import re

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BACKEND_DIR = os.path.dirname(SCRIPT_DIR)
DATA_DIR = os.path.join(BACKEND_DIR, "data")

def clean_string(text: str) -> str:
    text = re.sub(r'\(.*?\)', '', str(text))
    return text.strip().lower()

def clean_market_name(name: str) -> str:
    name = str(name).lower().strip()
    
    # 1. Safely handle the "Wakulima" trap before stripping parentheses
    if 'wakulima' in name and 'nairobi' in name: return 'wakulima_nairobi'
    if 'wakulima' in name and 'nakuru' in name: return 'wakulima_nakuru'
    
    # 2. Strip parentheses (e.g., "Garissa town (Garissa)" -> "Garissa town")
    name = re.sub(r'\(.*?\)', '', name).strip()
    
    # 3. Strip redundant suffixes so duplicates merge perfectly
    name = name.replace('_town', '').replace(' town', '')
    name = name.replace('_market', '').replace(' market', '')
    name = name.replace('_centre', '').replace(' centre', '')
    name = name.replace(' center', '')
    
    return name.strip()

def build_enterprise_datasets():
    print("⏳ [Phase 2 ETL] Scrubbing & Geofencing WFP market data...")
    df = pd.read_csv(os.path.join(BACKEND_DIR,"scripts", "wfp_food_prices_ken.csv")) 
    
    df.rename(columns={'date': 'ds'}, inplace=True)
    df['commodity'] = df['commodity'].apply(clean_string)
    df['pricetype'] = df['pricetype'].apply(clean_string)
    df['market'] = df['market'].apply(clean_market_name)
    
    # 🔥 GEOFENCING: Ban refugee camp sectors, slums, and unhelpful micro-markets
    banned_markets = [
        'mogadishu', 'ethiopia', 'hongkong', 'bangladesh', 'moroto', 
        'kakuma 2', 'kakuma 3', 'kakuma 4', 'ifo', 'hagadera', 'dagahaley',
        'kisumu ndogo', 'kalahari', 'shonda', 'junda', 'napak'
    ]
    df = df[~df['market'].isin(banned_markets)]
    
    excluded_items = ['fuel', 'milk', 'oil', 'bread', 'meat', 'sugar', 'salt']
    df = df[~df['commodity'].str.contains('|'.join(excluded_items))]

    print("⚖️ Standardizing prices to KES per 1 KG...")
    df['unit_weight'] = df['unit'].str.extract(r'(\d+)').astype(float)
    df['unit_weight'] = df['unit_weight'].fillna(1.0)
    df['price'] = df['price'] / df['unit_weight']

    # CRITICAL: Delete old ghost files before saving new ones!
    if os.path.exists(DATA_DIR):
        for file in os.listdir(DATA_DIR):
            os.remove(os.path.join(DATA_DIR, file))
    os.makedirs(DATA_DIR, exist_ok=True)
    
    # Create Local Databases
    valid_markets = df['market'].unique()
    for market in valid_markets:
        market_df = df[df['market'] == market]
        final_df = market_df[['ds', 'price', 'commodity', 'pricetype']].dropna()
        if len(final_df) < 15: continue # Keep threshold low to allow more crops
        
        safe_market_name = market.replace(" ", "_")
        file_path = os.path.join(DATA_DIR, f"market_prices_{safe_market_name}.csv")
        final_df.to_csv(file_path, index=False)
        
    print(f"✅ Datasets built successfully in: {DATA_DIR}")

if __name__ == "__main__":
    build_enterprise_datasets()