# app/db/database.py

import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./wheatguard.db")

if DATABASE_URL.startswith("sqlite"):
    engine = create_engine(
        DATABASE_URL,
        connect_args={"check_same_thread": False}
    )
    print(" Using SQLite (local dev mode)")
else:
    engine = create_engine(DATABASE_URL, pool_pre_ping=True)
    print(" Connected to PostgreSQL")

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def init_db():
    """
    IMPORTANT:
    Import ALL models here so SQLAlchemy knows they exist.
    Otherwise 'fields' table will NEVER be created.
    """
    from app.models.fields import Field
    from app.models.report import Report
    from app.models.detection import Detection
    from app.models.alert import Alert
    from app.models.fcm_device import FCMDevice
    from app.models.ndvi_history import NDVIHistory
    from app.models.ndvi_stress import NDVIStressAlert

    print("Creating database tables (if not exists)...")
    Base.metadata.create_all(bind=engine)
    print(" Tables ready")


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
