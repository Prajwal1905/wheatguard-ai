from sqlalchemy import create_engine

DATABASE_URL = "postgresql://postgres:admin@localhost:5432/wheatguard"

try:
    engine = create_engine(DATABASE_URL)
    with engine.connect() as connection:
        result = connection.execute("SELECT version();")
        print(" Connected successfully!")
        print("PostgreSQL version:", result.scalar())
except Exception as e:
    print(" Connection failed:")
    print(e)
