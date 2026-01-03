import pandas as pd
from prophet import Prophet
import joblib
import os

# CONFIGURATION
DATA_PATH = 'scripts/data/market_prices_makueni.csv'
MODEL_DIR = 'mkulimahub_backend/models'

def train_models():
    print("🧠 Starting AI Training...")
    
    # 1. Load the Data
    if not os.path.exists(DATA_PATH):
        print(f"❌ Error: Data file not found at {DATA_PATH}")
        return

    df = pd.read_csv(DATA_PATH)
    
    # Ensure the models directory exists
    os.makedirs(MODEL_DIR, exist_ok=True)

    # 2. Train a separate model for EACH crop
    unique_crops = df['commodity'].unique()
    
    for crop in unique_crops:
        print(f"   Training model for: {crop}...")
        
        # Filter data for this specific crop
        crop_df = df[df['commodity'] == crop][['ds', 'price']]
        
        # Rename columns to 'ds' and 'y' (Required by Prophet)
        crop_df.columns = ['ds', 'y']
        
        # Initialize and Train Prophet
        model = Prophet(daily_seasonality=True)
        model.fit(crop_df)
        
        # Save the trained model
        model_filename = os.path.join(MODEL_DIR, f'model_{crop.lower().replace(" ", "_")}.joblib')
        joblib.dump(model, model_filename)
        
        print(f"   ✅ Saved {crop} model to {model_filename}")

    print("🎉 All models trained successfully!")

if __name__ == "__main__":
    train_models()