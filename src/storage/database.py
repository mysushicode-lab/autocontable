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
        # ── Sequence system migrations ──────────────────────────────────────
        def execute_safe(sql):
            try:
                session.execute(text(sql))
                session.commit()
            except Exception:
                session.rollback()

        if 'sqlite' in str(db.engine.url):
            # Sequence tables
            execute_safe("""CREATE TABLE IF NOT EXISTS sequence_pools (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                pool_id VARCHAR(100) UNIQUE NOT NULL,
                name VARCHAR(200) NOT NULL,
                strategy VARCHAR(50) DEFAULT 'chronological',
                target_lifecycle_stages JSON,
                cooldown_days INTEGER DEFAULT 0,
                loop_when_exhausted BOOLEAN DEFAULT 0,
                loop_cooldown_days INTEGER DEFAULT 90,
                fallback_pool_id VARCHAR(100),
                is_active BOOLEAN DEFAULT 1,
                created_at DATETIME
            )""")
            execute_safe("""CREATE TABLE IF NOT EXISTS sequence_definitions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                sequence_id VARCHAR(100) UNIQUE NOT NULL,
                name VARCHAR(200) NOT NULL,
                pool_id VARCHAR(100) NOT NULL,
                target_lifecycle_stages JSON,
                priority INTEGER DEFAULT 50,
                steps JSON,
                on_complete_action VARCHAR(50) DEFAULT 'exit',
                on_complete_next_pool VARCHAR(100),
                on_complete_cooldown_days INTEGER DEFAULT 0,
                is_active BOOLEAN DEFAULT 1,
                created_at DATETIME
            )""")
            execute_safe("""CREATE TABLE IF NOT EXISTS completed_sequences (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                organization_id INTEGER REFERENCES organizations(id),
                user_id INTEGER REFERENCES users(id),
                quiz_contact_id INTEGER REFERENCES quiz_contacts(id),
                sequence_id VARCHAR(100) NOT NULL,
                pool_id VARCHAR(100) NOT NULL,
                completed_at DATETIME
            )""")

            # Organization new columns
            result = session.execute(text("PRAGMA table_info(organizations)"))
            org_cols = [row[1] for row in result.fetchall()]
            for col, typedef in [
                ("lifecycle_stage", "VARCHAR(50)"),
                ("current_sequence_id", "VARCHAR(100)"),
                ("current_step_index", "INTEGER DEFAULT 0"),
                ("sequence_entered_at", "DATETIME"),
                ("last_email_sent_at", "DATETIME"),
                ("sequence_cooldown_until", "DATETIME"),
                ("emails_sent_today", "INTEGER DEFAULT 0"),
                ("emails_sent_this_week", "INTEGER DEFAULT 0"),
                ("last_freq_reset_daily", "DATETIME"),
                ("last_freq_reset_weekly", "DATETIME"),
                ("engagement_score", "FLOAT DEFAULT 50.0"),
                ("total_emails_sent", "INTEGER DEFAULT 0"),
                ("total_emails_opened", "INTEGER DEFAULT 0"),
            ]:
                if col not in org_cols:
                    execute_safe(f"ALTER TABLE organizations ADD COLUMN {col} {typedef}")

            # QuizContact new columns
            result = session.execute(text("PRAGMA table_info(quiz_contacts)"))
            qc_cols = [row[1] for row in result.fetchall()]
            for col, typedef in [
                ("current_sequence_id", "VARCHAR(100)"),
                ("current_step_index", "INTEGER DEFAULT 0"),
                ("sequence_entered_at", "DATETIME"),
                ("last_email_sent_at", "DATETIME"),
                ("sequence_cooldown_until", "DATETIME"),
                ("emails_sent_today", "INTEGER DEFAULT 0"),
                ("emails_sent_this_week", "INTEGER DEFAULT 0"),
                ("last_freq_reset_daily", "DATETIME"),
                ("last_freq_reset_weekly", "DATETIME"),
            ]:
                if col not in qc_cols:
                    execute_safe(f"ALTER TABLE quiz_contacts ADD COLUMN {col} {typedef}")
        else:
            # PostgreSQL sequence tables
            execute_safe("""CREATE TABLE IF NOT EXISTS sequence_pools (
                id SERIAL PRIMARY KEY,
                pool_id VARCHAR(100) UNIQUE NOT NULL,
                name VARCHAR(200) NOT NULL,
                strategy VARCHAR(50) DEFAULT 'chronological',
                target_lifecycle_stages JSON,
                cooldown_days INTEGER DEFAULT 0,
                loop_when_exhausted BOOLEAN DEFAULT FALSE,
                loop_cooldown_days INTEGER DEFAULT 90,
                fallback_pool_id VARCHAR(100),
                is_active BOOLEAN DEFAULT TRUE,
                created_at TIMESTAMP
            )""")
            execute_safe("""CREATE TABLE IF NOT EXISTS sequence_definitions (
                id SERIAL PRIMARY KEY,
                sequence_id VARCHAR(100) UNIQUE NOT NULL,
                name VARCHAR(200) NOT NULL,
                pool_id VARCHAR(100) NOT NULL,
                target_lifecycle_stages JSON,
                priority INTEGER DEFAULT 50,
                steps JSON,
                on_complete_action VARCHAR(50) DEFAULT 'exit',
                on_complete_next_pool VARCHAR(100),
                on_complete_cooldown_days INTEGER DEFAULT 0,
                is_active BOOLEAN DEFAULT TRUE,
                created_at TIMESTAMP
            )""")
            execute_safe("""CREATE TABLE IF NOT EXISTS completed_sequences (
                id SERIAL PRIMARY KEY,
                organization_id INTEGER REFERENCES organizations(id),
                user_id INTEGER REFERENCES users(id),
                quiz_contact_id INTEGER REFERENCES quiz_contacts(id),
                sequence_id VARCHAR(100) NOT NULL,
                pool_id VARCHAR(100) NOT NULL,
                completed_at TIMESTAMP
            )""")

            # Organization new columns
            for col, typedef in [
                ("lifecycle_stage", "VARCHAR(50)"),
                ("current_sequence_id", "VARCHAR(100)"),
                ("current_step_index", "INTEGER DEFAULT 0"),
                ("sequence_entered_at", "TIMESTAMP"),
                ("last_email_sent_at", "TIMESTAMP"),
                ("sequence_cooldown_until", "TIMESTAMP"),
                ("emails_sent_today", "INTEGER DEFAULT 0"),
                ("emails_sent_this_week", "INTEGER DEFAULT 0"),
                ("last_freq_reset_daily", "TIMESTAMP"),
                ("last_freq_reset_weekly", "TIMESTAMP"),
                ("engagement_score", "FLOAT DEFAULT 50.0"),
                ("total_emails_sent", "INTEGER DEFAULT 0"),
                ("total_emails_opened", "INTEGER DEFAULT 0"),
            ]:
                result = session.execute(text(f"""
                    SELECT column_name FROM information_schema.columns
                    WHERE table_name = 'organizations' AND column_name = '{col}'
                """))
                if not result.fetchone():
                    execute_safe(f"ALTER TABLE organizations ADD COLUMN {col} {typedef}")

            # QuizContact new columns
            for col, typedef in [
                ("current_sequence_id", "VARCHAR(100)"),
                ("current_step_index", "INTEGER DEFAULT 0"),
                ("sequence_entered_at", "TIMESTAMP"),
                ("last_email_sent_at", "TIMESTAMP"),
                ("sequence_cooldown_until", "TIMESTAMP"),
                ("emails_sent_today", "INTEGER DEFAULT 0"),
                ("emails_sent_this_week", "INTEGER DEFAULT 0"),
                ("last_freq_reset_daily", "TIMESTAMP"),
                ("last_freq_reset_weekly", "TIMESTAMP"),
            ]:
                result = session.execute(text(f"""
                    SELECT column_name FROM information_schema.columns
                    WHERE table_name = 'quiz_contacts' AND column_name = '{col}'
                """))
                if not result.fetchone():
                    execute_safe(f"ALTER TABLE quiz_contacts ADD COLUMN {col} {typedef}")

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
