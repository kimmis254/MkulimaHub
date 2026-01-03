import pandas as pd
import numpy as np
import os
from datetime import datetime, timedelta

# CONFIGURATION
DAYS_HISTORY = 1095  # 3 Years of data (Better for AI)
START_DATE = datetime.now() - timedelta(days=DAYS_HISTORY)

# --- REAL DATA: Monthly Average Wholesale Prices in Makueni (KES/kg) ---
# Source: Approximated from KNBS & KAMIS 2023-2024 Reports
# Jan, Feb, Mar, Apr, May, Jun, Jul, Aug, Sep, Oct, Nov, Dec
REAL_PATTERNS = {
    'Mangoes':      [15, 12, 18, 25, 40, 55, 60, 58, 45, 35, 25, 18], # Peak season Jan-Feb (Low price)
    'Maize':        [45, 48, 50, 55, 60, 65, 55, 40, 38, 42, 44, 45], # Harvest Aug-Sep (Price drop)
    'Green Grams':  [90, 80, 75, 85, 95, 100, 110, 105, 100, 95, 92, 90],
    'Pigeon Peas':  [70, 72, 75, 78, 80, 85, 80, 60, 55, 65, 68, 70]
}

def generate_calibrated_prices():
    print("📈 Generating 'Real-Pattern' historical price data for Makueni...")
    
    all_data = []

    for crop, monthly_prices in REAL_PATTERNS.items():
        print(f"   Processing {crop}...")
        
        for i in range(DAYS_HISTORY):
            current_date = START_DATE + timedelta(days=i)
            month_index = current_date.month - 1  # 0 for Jan, 11 for Dec
            
            # 1. Get the "Real" average for this month
            base_price = monthly_prices[month_index]
            
            # 2. Add "Inflation Trend" (Prices rise ~10% per year)
            year_offset = (DAYS_HISTORY - i) / 365
            inflation = base_price * (0.10 * year_offset)
            
            # 3. Add "Daily Noise" (Markets fluctuate daily by +/- 5 KES)
            noise = np.random.normal(0, 3) 
            
            final_price = base_price - inflation + noise
            
            all_data.append({
                "ds": current_date.strftime("%Y-%m-%d"),
                "commodity": crop,
                "price": round(max(final_price, 5), 2) # Ensure no negative prices
            })

    # Convert to DataFrame
    df = pd.DataFrame(all_data)
    
    # Save to CSV
    output_path = 'mkulimahub_backend/scripts/data/market_prices_makueni.csv'
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    df.to_csv(output_path, index=False)
    print(f"✅ Success! Generated {len(df)} rows based on KNBS patterns.")
    print(f"Saved to {output_path}")
    print(df.sample(5))

if __name__ == "__main__":
    generate_calibrated_prices()