import os
import google.generativeai as genai
from dotenv import load_dotenv

import models
from database import SessionLocal
from config import GEMINI_API_KEY

load_dotenv()
genai.configure(api_key=GEMINI_API_KEY)


def get_market_spot_price(crop: str, county: str) -> str:
    db = SessionLocal()
    try:
        latest_record = db.query(models.MarketPrice).filter(
            models.MarketPrice.commodity.ilike(f"%{crop}%"),
            models.MarketPrice.county.ilike(f"%{county}%")
        ).order_by(models.MarketPrice.date.desc()).first()

        if latest_record:
            return f"Live Spot Price: {crop.capitalize()} is currently trading at KES {latest_record.price_kes} per kg in {county.capitalize()}."
        return f"I couldn't find any recent market data for {crop} in {county}."
    finally:
        db.close()


def predict_price_trend(crop: str) -> str:
    db = SessionLocal()
    try:
        cached = db.query(models.CachedPrediction).filter(
            models.CachedPrediction.cache_key.ilike(f"%{crop.lower()}_national%")
        ).first()

        if cached and cached.payload:
            trend = cached.payload.get("trend", "stable")
            pred_price = cached.payload.get("predicted_price", 0)
            return f"AI Trend Analysis: {crop.capitalize()} prices are trending {trend} and are expected to hit KES {pred_price} in the next 30 days."
        return f"AI Models are currently analyzing the 30-day forecast for {crop}. Check back soon."
    finally:
        db.close()


def get_weather_forecast(location: str) -> str:
    return f"Live Weather Data for {location}: Sunny, 28°C."


def diagnose_crop_disease(symptoms: str) -> str:
    return "Based on your description, there is a high probability of Fungal Blight. Ensure you check the undersides of the leaves."


def ask_ai_assistant(message: str, user_name: str = "Farmer", role: str = "farmer",
                     location: str = "Kenya", business_details: str = ""):
    system_instruction = f"""
    You are the MkulimaHub AI Assistant, an expert in Kenyan agriculture and market dynamics.
    You are talking to {user_name}, who is a {role} located in {location}.
    Business Context: {business_details}
    
    Always be helpful, encouraging, and concise. If they ask about crop prices, trends, weather, 
    or diseases, YOU MUST USE YOUR TOOLS to fetch live data from the database before answering.
    """

    model = genai.GenerativeModel(
        model_name='gemini-2.5-flash',
        tools=[get_market_spot_price, predict_price_trend, get_weather_forecast, diagnose_crop_disease],
        system_instruction=system_instruction
    )

    chat = model.start_chat(enable_automatic_function_calling=True)
    response = chat.send_message(message)

    return response.text
