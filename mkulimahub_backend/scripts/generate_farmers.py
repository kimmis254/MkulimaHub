import pandas as pd
import random
from faker import Faker
import os

fake = Faker()

# CONFIGURATION
TOTAL_FARMERS = 1000

# --- UPDATED: Bounding Box for Makueni County, Kenya ---
# Makueni spans roughly Lat -1.5 to -3.0 and Long 37.0 to 38.3
LAT_MIN, LAT_MAX = -2.500, -1.600  
LON_MIN, LON_MAX = 37.200, 38.000 

# --- UPDATED: Crops common in Makueni ---
# Added Mangoes and Pigeon Peas (Green Grams/Ndengu is also huge there)
CROPS = ['Maize', 'Beans', 'Mangoes', 'Pigeon Peas', 'Green Grams']

def generate_farmers():
    print(f"🚜 Generating {TOTAL_FARMERS} dummy farmers in Makueni...")
    
    farmers = []
    
    for i in range(TOTAL_FARMERS):
        farmer = {
            "id": i + 1,
            "name": fake.name(),
            "phone": f"+2547{random.randint(10000000, 99999999)}",
            # Generate location within Makueni box
            "latitude": random.uniform(LAT_MIN, LAT_MAX),
            "longitude": random.uniform(LON_MIN, LON_MAX),
            # Random crop details
            "crop": random.choice(CROPS),
            "harvest_amount_kg": random.randint(50, 2000), # Between 50kg and 2 tons
            "harvest_date": fake.date_between(start_date='-1M', end_date='+1M')
        }
        farmers.append(farmer)

    # Convert to DataFrame
    df = pd.DataFrame(farmers)
    
    # Save to CSV
    output_path = 'mkulimahub_backend/scripts/data/farmers_dummy.csv'
    
    # Ensure directory exists
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    df.to_csv(output_path, index=False)
    print(f"✅ Success! Saved {TOTAL_FARMERS} Makueni farmers to {output_path}")
    print(df.head()) # Show first 5 rows

if __name__ == "__main__":
    generate_farmers()