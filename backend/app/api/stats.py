from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func, case
from datetime import datetime, timedelta

from app.db.database import get_db
from app.models.detection import Detection
from app.models.report import Report
from app.models.alert import Alert
from app.models.ndvi_stress import NDVIStressAlert
from app.models.fields import Field

router = APIRouter(prefix="/api", tags=["Stats"])


@router.get("/stats")
def get_dashboard_stats(db: Session = Depends(get_db)):
    
    now   = datetime.utcnow()
    today = now.replace(hour=0, minute=0, second=0, microsecond=0)
    week_ago  = now - timedelta(days=7)
    month_ago = now - timedelta(days=30)

    total_detections = db.query(func.count(Detection.id)).scalar() or 0

    detections_today = (
        db.query(func.count(Detection.id))
        .filter(Detection.created_at >= today)
        .scalar() or 0
    )

    detections_week = (
        db.query(func.count(Detection.id))
        .filter(Detection.created_at >= week_ago)
        .scalar() or 0
    )

    severity_rows = (
        db.query(Detection.severity, func.count(Detection.id))
        .group_by(Detection.severity)
        .all()
    )
    severity_counts = {row[0]: row[1] for row in severity_rows}

   
    disease_rows = (
        db.query(Detection.disease_label, func.count(Detection.id).label("count"))
        .group_by(Detection.disease_label)
        .order_by(func.count(Detection.id).desc())
        .limit(5)
        .all()
    )
    top_diseases = [
        {"disease": row[0], "count": row[1]} for row in disease_rows
    ]

    
    fourteen_ago = now - timedelta(days=14)
    trend_rows = (
        db.query(
            func.date(Detection.created_at).label("day"),
            func.count(Detection.id).label("count"),
        )
        .filter(Detection.created_at >= fourteen_ago)
        .group_by(func.date(Detection.created_at))
        .order_by(func.date(Detection.created_at))
        .all()
    )
    daily_trend = [
        {"date": str(row[0]), "count": row[1]} for row in trend_rows
    ]

    source_rows = (
        db.query(Report.source, func.count(Detection.id).label("count"))
        .join(Detection, Detection.report_id == Report.id)
        .group_by(Report.source)
        .all()
    )
    source_counts = {row[0]: row[1] for row in source_rows}

    total_alerts = db.query(func.count(Alert.id)).scalar() or 0
    active_alerts = (
        db.query(func.count(Alert.id))
        .filter(Alert.is_resolved == False)
        .scalar() or 0
    )

    ndvi_stress_total = (
        db.query(func.count(NDVIStressAlert.id))
        .filter(NDVIStressAlert.resolved == False)
        .scalar() or 0
    )
    ndvi_stress_critical = (
        db.query(func.count(NDVIStressAlert.id))
        .filter(
            NDVIStressAlert.resolved == False,
            NDVIStressAlert.severity == "Critical",
        )
        .scalar() or 0
    )

    total_fields = db.query(func.count(Field.id)).scalar() or 0

    
    detections_month = (
        db.query(func.count(Detection.id))
        .filter(Detection.created_at >= month_ago)
        .scalar() or 0
    )

    return {
        "detections": {
            "total":        total_detections,
            "today":        detections_today,
            "this_week":    detections_week,
            "this_month":   detections_month,
        },
        "severity": {
            "high":     severity_counts.get("High", 0),
            "moderate": severity_counts.get("Moderate", 0),
            "low":      severity_counts.get("Low", 0),
        },
        "top_diseases":  top_diseases,
        "daily_trend":   daily_trend,
        "sources":       source_counts,
        "alerts": {
            "total":  total_alerts,
            "active": active_alerts,
        },
        "ndvi_stress": {
            "active":   ndvi_stress_total,
            "critical": ndvi_stress_critical,
        },
        "fields": {
            "total": total_fields,
        },
        "generated_at": now.isoformat(),
    }
