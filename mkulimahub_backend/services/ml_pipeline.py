from sqlalchemy.orm import Session
from datetime import datetime
import pandas as pd
from prophet import Prophet

import models
from database import SessionLocal


def scheduled_ml_predictions():
    db: Session = SessionLocal()
    try:
        crops = db.query(models.MarketPrice.commodity).distinct().all()
        crop_list = [c[0] for c in crops if c[0]]

        for crop in crop_list:
            for market_type in ["Wholesale", "Retail"]:
                cache_key = f"{crop.lower()}_national_{market_type.lower()}"

                records = db.query(models.MarketPrice.date, models.MarketPrice.price_kes).filter(
                    models.MarketPrice.commodity.ilike(f"%{crop}%"),
                    models.MarketPrice.market_type.ilike(f"%{market_type}%")
                ).all()

                # Ensure we have enough data to form a real trend
                if len(records) < 14:
                    continue

                df = pd.DataFrame([{"ds": r.date, "y": r.price_kes} for r in records])
                df['ds'] = pd.to_datetime(df['ds'])

                # Remove KAMIS typos
                q_low = df["y"].quantile(0.01)
                q_hi = df["y"].quantile(0.99)
                df = df[(df["y"] <= q_hi) & (df["y"] >= q_low)]

                df = df.groupby('ds', as_index=False)['y'].mean().sort_values(by='ds')

                if len(df) < 14:
                    continue

                print(f"Training model for {cache_key}...")

                df['floor'] = max(0.0, df['y'].min() * 0.2)
                df['cap'] = df['y'].max() * 2.0

                # Initialize Prophet with logistic growth
                m = Prophet(
                    growth='logistic',
                    daily_seasonality=False,
                    weekly_seasonality=True,
                    yearly_seasonality=True,
                    changepoint_prior_scale=0.05  # Makes trend lines smoother
                )
                m.fit(df)

                # Setup the future dataframe with the same bounds
                future = m.make_future_dataframe(periods=30)
                future['floor'] = df['floor'].iloc[0]
                future['cap'] = df['cap'].iloc[0]

                forecast = m.predict(future)

                historical_prices = df['y'].round(2).tolist()
                future_forecast = forecast[forecast['ds'] > df['ds'].max()]

                # Double check no negative values slip into JSON
                future_prices = [max(0.0, round(x, 2)) for x in future_forecast['yhat']]
                current_p = float(historical_prices[-1])
                predicted_p = future_prices[-1] if future_prices else current_p

                payload = {
                    "historical_dates": df['ds'].dt.strftime('%Y-%m-%d').tolist(),
                    "historical_prices": historical_prices,
                    "future_dates": future_forecast['ds'].dt.strftime('%Y-%m-%d').tolist(),
                    "future_prices": future_prices,
                    "current_price": current_p,
                    "predicted_price": predicted_p,
                    "trend": "rising" if predicted_p > current_p else "falling" if predicted_p < current_p else "stable",
                    "fallback_type": "national"
                }

                existing = db.query(models.CachedPrediction).filter_by(cache_key=cache_key).first()
                if existing:
                    existing.payload = payload
                    existing.last_updated = datetime.utcnow()
                else:
                    new_cache = models.CachedPrediction(cache_key=cache_key, payload=payload)
                    db.add(new_cache)

                db.commit()

        print("All ML Models Trained and Cached!")
    except Exception as e:
        print(f"[SCHEDULER ERROR]: {e}")
        db.rollback()
    finally:
        db.close()
