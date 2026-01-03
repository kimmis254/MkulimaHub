from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import joblib
import os
import pandas as pd
from datetime import datetime, timedelta

app = FastAPI(title="MkulimaHub API")

# Define request body format
class PredictionRequest(BaseModel):
    commodity: str
    days: int = 30  # Default to predicting next 30 days

# Load models helper
MODEL_DIR = 'models' # Since main.py is in mkulimahub_backend, models is in same folder relative to execution?
# NOTE: Depending on where you run uvicorn from, path might vary. 
# We'll use absolute path to be safe.
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_DIR = os.path.join(BASE_DIR, 'models')

@app.get("/")
def read_root():
    return {"message": "MkulimaHub API is running!", "status": "active"}

@app.post("/predict")
def predict_price(request: PredictionRequest):
    """
    Predicts future prices for a specific commodity.
    """
    # 1. Construct model filename (e.g., model_mangoes.joblib)
    filename = f"model_{request.commodity.lower().replace(' ', '_')}.joblib"
    model_path = os.path.join(MODEL_DIR, filename)
    
    # 2. Check if model exists
    if not os.path.exists(model_path):
        available_models = [f.replace('model_', '').replace('.joblib', '') for f in os.listdir(MODEL_DIR)]
        raise HTTPException(status_code=404, detail=f"Model for '{request.commodity}' not found. Available: {available_models}")

    # 3. Load the model
    try:
        model = joblib.load(model_path)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error loading model: {str(e)}")

    # 4. Create future dates dataframe
    future = model.make_future_dataframe(periods=request.days)
    
    # 5. Predict
    forecast = model.predict(future)
    
    # 6. Extract only the future data (last N days)
    future_forecast = forecast.tail(request.days)
    
    # 7. Format result for JSON response
    results = []
    for index, row in future_forecast.iterrows():
        results.append({
            "date": row['ds'].strftime('%Y-%m-%d'),
            "predicted_price": round(row['yhat'], 2),
            "trend": "up" if row['yhat'] > row['trend'] else "down" # Simple trend logic
        })
        
    return {
        "commodity": request.commodity,
        "forecast": results
    }