"""
Database connection and session management
"""
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from contextlib import contextmanager
from dotenv import load_dotenv
from .models import Base

# Load environment variables
load_dotenv(os.path.join(os.path.dirname(__file__), '../../.env'))

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
    except Exception as e:
        session.rollback()
        print(f"Error adding file_hash column: {e}")
    finally:
        session.close()


def init_database():
    """Initialize the database with all tables"""
    db.create_tables()
    run_migrations()
    print("Database initialized successfully")


if __name__ == "__main__":
    init_database()
