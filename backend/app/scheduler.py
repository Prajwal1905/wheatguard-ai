from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from sqlalchemy.orm import Session
from app.db.database import SessionLocal
from app.ndvi_stress import scan_ndvi_stress
from app.utils.socket_manager import broadcast_ndvi_stress_updates
from app.crud import get_active_ndvi_stress_alerts

scheduler = AsyncIOScheduler()

def run_ndvi_stress_job():
    print(" Running scheduled NDVI Stress Scan")

    db: Session = SessionLocal()
    try:
        scan_ndvi_stress(db)

        
        alerts = get_active_ndvi_stress_alerts(db)

        
        import asyncio
        asyncio.run(broadcast_ndvi_stress_updates([
            {
                "id": a.id,
                "lat": a.lat,
                "lon": a.lon,
                "baseline_ndvi": a.baseline_ndvi,
                "current_ndvi": a.current_ndvi,
                "drop": a.drop,
                "severity": a.severity,
                "created_at": str(a.created_at),
            }
            for a in alerts
        ]))

        print(" NDVI stress broadcast completed")

    except Exception as e:
        print(" NDVI stress scan error:", e)
    finally:
        db.close()


def start_scheduler():
    # Run every day at 2 AM
    scheduler.add_job(
        run_ndvi_stress_job,
        CronTrigger(hour=2, minute=0),
        id="daily_ndvi_stress_scan"
    )

    scheduler.start()
    print(" Scheduler started: NDVI scan at 2:00 AM daily")
