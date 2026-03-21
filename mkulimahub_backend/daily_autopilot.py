import os
import subprocess
from datetime import datetime

# 1. Define the path to your scraper script
SCRAPER_SCRIPT = "scripts/kamis_daily_scraper.py" 
# 2. Define where you want the paper trail saved
LOG_FILE = "midnight_scraper.log"

def run_midnight_pipeline():
    # Open the log file in "append" mode so it adds to the bottom every night
    with open(LOG_FILE, "a", encoding="utf-8") as log:
        timestamp = datetime.now().strftime("%Y-%m-%d %I:%M %p")
        log.write(f"\n[{timestamp}] 🌙 MkulimaHub Autopilot waking up...\n")
        
        try:
            log.write(f"[{timestamp}] 🚜 Running daily scraper & DB injector...\n")
            
            # 🔥 We use capture_output=True to catch all the 'prints' from your scraper script
            result = subprocess.run(["python", SCRAPER_SCRIPT], capture_output=True, text=True)
            
            # Write the scraper's prints to our log file
            log.write(result.stdout)
            
            if result.returncode == 0:
                log.write(f"[{timestamp}] ✅ Pipeline complete! The SQL Database is updated.\n")
            else:
                log.write(f"[{timestamp}] ⚠️ Scraper had an error:\n{result.stderr}\n")
                
        except Exception as e:
            log.write(f"[{timestamp}] ❌ Autopilot completely crashed: {e}\n")

if __name__ == "__main__":
    run_midnight_pipeline()