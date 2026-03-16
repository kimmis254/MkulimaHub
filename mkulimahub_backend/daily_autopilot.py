import os
import subprocess

# 1. Define the path to your scraper script
SCRAPER_SCRIPT = "scripts/kamis_daily_scraper.py" 

def run_midnight_pipeline():
    print("🌙 [12:00 AM] MkulimaHub Autopilot waking up...")
    
    try:
        # Step 1: Scrape today's new market prices and inject directly into SQL
        print(f"🚜 Running daily scraper & DB injector: {SCRAPER_SCRIPT}")
        subprocess.run(["python", SCRAPER_SCRIPT], check=True)
        
        print("✅ Pipeline complete! The SQL Database is updated and the AI is ready.")
    except Exception as e:
        print(f"❌ Autopilot crashed: {e}")

if __name__ == "__main__":
    run_midnight_pipeline()