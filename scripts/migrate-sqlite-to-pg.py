"""Migrate data from SQLite to PostgreSQL.

Usage: DATABASE_URL=postgresql://... python scripts/migrate-sqlite-to-pg.py
"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import sessionmaker
from src.storage.models import Base

SQLITE_URL = "sqlite:///data/accounting.db"
PG_URL = os.getenv("DATABASE_URL")

if not PG_URL:
    print("ERROR: Set DATABASE_URL environment variable to PostgreSQL connection string")
    sys.exit(1)

if 'postgresql' not in PG_URL:
    print("ERROR: DATABASE_URL must be a PostgreSQL connection string")
    sys.exit(1)

print(f"Source: {SQLITE_URL}")
print(f"Target: {PG_URL}")

# Create engines
sqlite_engine = create_engine(SQLITE_URL)
pg_engine = create_engine(PG_URL)

# Create all tables in PG
Base.metadata.create_all(pg_engine)
print("Tables created in PostgreSQL")

# Get all table names
inspector = inspect(sqlite_engine)
tables = inspector.get_table_names()

# Migrate each table
SQLiteSession = sessionmaker(bind=sqlite_engine)
PGSession = sessionmaker(bind=pg_engine)

sqlite_session = SQLiteSession()
pg_session = PGSession()

for table_name in tables:
    if table_name.startswith('sqlite_') or table_name == 'alembic_version':
        continue

    print(f"Migrating {table_name}...", end=" ")

    # Read all rows from SQLite
    rows = sqlite_session.execute(text(f"SELECT * FROM {table_name}")).fetchall()

    if not rows:
        print("(empty)")
        continue

    # Get column names
    columns = [col['name'] for col in inspector.get_columns(table_name)]

    # Insert into PG in batches
    batch_size = 500
    count = 0
    for i in range(0, len(rows), batch_size):
        batch = rows[i:i + batch_size]
        for row in batch:
            values = dict(zip(columns, row))
            placeholders = ", ".join([f":{col}" for col in columns])
            cols_str = ", ".join(columns)
            pg_session.execute(
                text(f"INSERT INTO {table_name} ({cols_str}) VALUES ({placeholders}) ON CONFLICT DO NOTHING"),
                values
            )
            count += 1
        pg_session.commit()

    # Reset sequence for auto-increment
    try:
        max_id = pg_session.execute(text(f"SELECT MAX(id) FROM {table_name}")).scalar()
        if max_id:
            pg_session.execute(text(f"SELECT setval(pg_get_serial_sequence('{table_name}', 'id'), {max_id})"))
            pg_session.commit()
    except Exception:
        pass

    print(f"{count} rows")

print("\nMigration complete!")
sqlite_session.close()
pg_session.close()
