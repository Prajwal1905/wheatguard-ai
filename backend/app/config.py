import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

# Read from environment (Docker will provide this)
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres:admin@localhost:5432/wheatguard"  # fallback for local run
)

engine = create_engine(DATABASE_URL, pool_pre_ping=True)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)

Base = declarative_base()
