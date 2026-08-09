"""
Database connection and session management
"""
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from contextlib import contextmanager
from .models import Base

import src.config  # noqa: F401 — centralized env loading

DATABASE_URL = os.getenv('DATABASE_URL', 'sqlite:///data/accounting.db')


def _build_engine(db_url: str):
    if db_url.startswith('sqlite:///'):
        sqlite_path = db_url.replace('sqlite:///', '', 1)
        sqlite_dir = os.path.dirname(sqlite_path)
        if sqlite_dir:
            os.makedirs(sqlite_dir, exist_ok=True)

    # Configure engine based on database type
    if "sqlite" in db_url:
        return create_engine(
            db_url,
            echo=False,
            connect_args={"check_same_thread": False}
        )
    elif "postgresql" in db_url:
        return create_engine(
            db_url,
            echo=False,
            pool_size=10,
            max_overflow=20,
            pool_pre_ping=True
        )
    else:
        return create_engine(db_url, echo=False)

# Create engine
engine = _build_engine(DATABASE_URL)

# Create session factory
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Database:
    """Database manager for invoice processing system"""
    
    def __init__(self, db_url: str = None):
        self.engine = _build_engine(db_url or DATABASE_URL)
        self.SessionLocal = sessionmaker(bind=self.engine)
    
    def create_tables(self):
        """Create all tables in the database"""
        Base.metadata.create_all(bind=self.engine)
    
    def drop_tables(self):
        """Drop all tables (use with caution)"""
        Base.metadata.drop_all(bind=self.engine)
    
    def get_session(self) -> Session:
        """Get a new database session"""
        return self.SessionLocal()
    
    @contextmanager
    def session_scope(self):
        """Provide a transactional scope around a series of operations"""
        session = self.SessionLocal()
        try:
            yield session
            session.commit()
        except Exception:
            session.rollback()
            raise
        finally:
            session.close()


# Global database instance
db = Database()


def run_migrations():
    """Run database migrations"""
    from sqlalchemy import text
    session = db.get_session()
    try:
        # SQLite-specific migrations
        if 'sqlite' in str(db.engine.url):
            # Check if file_hash column exists
            result = session.execute(text("PRAGMA table_info(bank_transactions)"))
            columns = [row[1] for row in result.fetchall()]
            if 'file_hash' not in columns:
                session.execute(text("ALTER TABLE bank_transactions ADD COLUMN file_hash VARCHAR(64)"))
                session.commit()
                print("Added file_hash column to bank_transactions table")

            # Check if quota columns exist
            result = session.execute(text("PRAGMA table_info(organizations)"))
            org_columns = [row[1] for row in result.fetchall()]
            if 'invoices_processed_this_month' not in org_columns:
                session.execute(text("ALTER TABLE organizations ADD COLUMN invoices_processed_this_month INTEGER DEFAULT 0"))
                session.commit()
                print("Added invoices_processed_this_month column to organizations table")
            if 'monthly_quota_reset_date' not in org_columns:
                session.execute(text("ALTER TABLE organizations ADD COLUMN monthly_quota_reset_date DATETIME"))
                session.commit()
                print("Added monthly_quota_reset_date column to organizations table")
            if 'stripe_subscription_id' not in org_columns:
                session.execute(text("ALTER TABLE organizations ADD COLUMN stripe_subscription_id VARCHAR(255)"))
                session.commit()
                print("Added stripe_subscription_id column to organizations table")
        else:
            # PostgreSQL: check columns via information_schema
            result = session.execute(text("""
                SELECT column_name FROM information_schema.columns
                WHERE table_name = 'bank_transactions' AND column_name = 'file_hash'
            """))
            if not result.fetchone():
                session.execute(text("ALTER TABLE bank_transactions ADD COLUMN file_hash VARCHAR(64)"))
                session.commit()
                print("Added file_hash column to bank_transactions table")

            # Check if quota columns exist in organizations
            result = session.execute(text("""
                SELECT column_name FROM information_schema.columns
                WHERE table_name = 'organizations' AND column_name = 'invoices_processed_this_month'
            """))
            if not result.fetchone():
                session.execute(text("ALTER TABLE organizations ADD COLUMN invoices_processed_this_month INTEGER DEFAULT 0"))
                session.commit()
                print("Added invoices_processed_this_month column to organizations table")

            result = session.execute(text("""
                SELECT column_name FROM information_schema.columns
                WHERE table_name = 'organizations' AND column_name = 'monthly_quota_reset_date'
            """))
            if not result.fetchone():
                session.execute(text("ALTER TABLE organizations ADD COLUMN monthly_quota_reset_date TIMESTAMP"))
                session.commit()
                print("Added monthly_quota_reset_date column to organizations table")

            result = session.execute(text("""
                SELECT column_name FROM information_schema.columns
                WHERE table_name = 'organizations' AND column_name = 'stripe_subscription_id'
            """))
            if not result.fetchone():
                session.execute(text("ALTER TABLE organizations ADD COLUMN stripe_subscription_id VARCHAR(255)"))
                session.commit()
                print("Added stripe_subscription_id column to organizations table")
    except Exception as e:
        session.rollback()
        print(f"Error during migrations: {e}")
    finally:
        session.close()


def init_database():
    """Initialize the database with all tables"""
    db.create_tables()
    run_migrations()
    print("Database initialized successfully")


if __name__ == "__main__":
    init_database()
