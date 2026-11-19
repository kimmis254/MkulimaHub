from apscheduler.schedulers.background import BackgroundScheduler
from sqlalchemy.orm import Session
from database import SessionLocal
from services.clustering import run_clustering_algorithm
from services.ml_pipeline import scheduled_ml_predictions


def scheduled_clustering_job():
    print("🤖 [SCHEDULER] Running Automatic DBSCAN Clustering...")
    db: Session = SessionLocal()
    try:
        run_clustering_algorithm(db, target_crop="All")
        print("[SCHEDULER] Clustering Complete!")
    except Exception as e:
        print(f"[SCHEDULER ERROR]: {e}")
    finally:
        db.close()


def create_scheduler():
    scheduler = BackgroundScheduler()
    scheduler.add_job(scheduled_clustering_job, 'interval', hours=1)
    scheduler.add_job(scheduled_ml_predictions, 'cron', hour=2, minute=0)
    return scheduler
