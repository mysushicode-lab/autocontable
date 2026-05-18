"""Database startup and migrations"""
from sqlalchemy import text
from src.storage.database import db
from src.storage.models import Base, Settings, User, UserRole, Organization
import os


def startup_event():
    """Create database tables on startup and run migrations"""
    Base.metadata.create_all(bind=db.engine)

    conn = db.engine.connect()

    # Recreate settings table without UNIQUE(key) constraint if needed
    try:
        idx_info = conn.execute(text("SELECT sql FROM sqlite_master WHERE type='index' AND tbl_name='settings' AND sql LIKE '%UNIQUE%key%'")).fetchall()
        if idx_info:
            conn.execute(text("ALTER TABLE settings RENAME TO settings_old"))
            conn.execute(text("""CREATE TABLE settings (
                id INTEGER PRIMARY KEY,
                key VARCHAR(100) NOT NULL,
                value TEXT,
                category VARCHAR(50) NOT NULL DEFAULT 'general',
                description TEXT,
                organization_id INTEGER REFERENCES organizations(id),
                updated_at DATETIME
            )"""))
            conn.execute(text("INSERT INTO settings SELECT id,key,value,category,description,NULL,updated_at FROM settings_old"))
            conn.execute(text("DROP TABLE settings_old"))
            conn.commit()
    except Exception as e:
        print(f"Settings migration: {e}")

    # Recreate suppliers table without global UNIQUE constraints if needed
    try:
        sup_sql = conn.execute(text("SELECT sql FROM sqlite_master WHERE type='table' AND name='suppliers'")).fetchone()
        if sup_sql and 'UNIQUE' in (sup_sql[0] or ''):
            conn.execute(text("ALTER TABLE suppliers RENAME TO suppliers_old"))
            conn.execute(text("""CREATE TABLE suppliers (
                id INTEGER PRIMARY KEY,
                name VARCHAR(200) NOT NULL,
                normalized_name VARCHAR(200) NOT NULL,
                organization_id INTEGER REFERENCES organizations(id),
                email VARCHAR(200),
                email_domain VARCHAR(100),
                category VARCHAR(100),
                vat_number VARCHAR(50),
                address TEXT,
                created_at DATETIME,
                updated_at DATETIME
            )"""))
            conn.execute(text("INSERT INTO suppliers SELECT id,name,normalized_name,NULL,email,email_domain,category,vat_number,address,created_at,updated_at FROM suppliers_old"))
            conn.execute(text("DROP TABLE suppliers_old"))
            conn.commit()
    except Exception as e:
        print(f"Suppliers migration: {e}")

    # Recreate invoices table without global UNIQUE on invoice_number if needed
    try:
        inv_sql = conn.execute(text("SELECT sql FROM sqlite_master WHERE type='index' AND tbl_name='invoices' AND sql LIKE '%UNIQUE%invoice_number%'")).fetchall()
        if inv_sql:
            conn.execute(text("ALTER TABLE invoices RENAME TO invoices_old"))
            conn.execute(text("""CREATE TABLE invoices (
                id INTEGER PRIMARY KEY,
                invoice_number VARCHAR(100) NOT NULL,
                supplier_id INTEGER REFERENCES suppliers(id),
                organization_id INTEGER REFERENCES organizations(id),
                amount FLOAT NOT NULL,
                amount_ht FLOAT,
                amount_tax FLOAT,
                date DATETIME NOT NULL,
                due_date DATETIME,
                category VARCHAR(100),
                status VARCHAR(50),
                purchase_order VARCHAR(100),
                delivery_note VARCHAR(100),
                vehicle_registration VARCHAR(20),
                work_order_reference VARCHAR(100),
                payment_method VARCHAR(50),
                file_path VARCHAR(500),
                email_subject VARCHAR(500),
                email_from VARCHAR(500),
                email_date DATETIME,
                message_id VARCHAR(200),
                content_hash VARCHAR(32),
                extracted_data TEXT,
                created_at DATETIME,
                updated_at DATETIME
            )"""))
            conn.execute(text("INSERT INTO invoices SELECT id,invoice_number,supplier_id,NULL,amount,amount_ht,amount_tax,date,due_date,category,status,purchase_order,delivery_note,vehicle_registration,work_order_reference,payment_method,file_path,email_subject,email_from,email_date,message_id,content_hash,extracted_data,created_at,updated_at FROM invoices_old"))
            conn.execute(text("DROP TABLE invoices_old"))
            conn.commit()
    except Exception as e:
        print(f"Invoices migration: {e}")

    # Recreate bank_transactions without global UNIQUE on transaction_id if needed
    try:
        bt_sql = conn.execute(text("SELECT sql FROM sqlite_master WHERE type='index' AND tbl_name='bank_transactions' AND sql LIKE '%UNIQUE%transaction_id%'")).fetchall()
        if bt_sql:
            conn.execute(text("ALTER TABLE bank_transactions RENAME TO bank_transactions_old"))
            conn.execute(text("""CREATE TABLE bank_transactions (
                id INTEGER PRIMARY KEY,
                transaction_id VARCHAR(100) NOT NULL,
                organization_id INTEGER REFERENCES organizations(id),
                date DATETIME NOT NULL,
                amount FLOAT NOT NULL,
                description TEXT NOT NULL,
                reference VARCHAR(200),
                account_number VARCHAR(50),
                category VARCHAR(100),
                source_file VARCHAR(500),
                created_at DATETIME
            )"""))
            conn.execute(text("INSERT INTO bank_transactions SELECT id,transaction_id,NULL,date,amount,description,reference,account_number,category,source_file,created_at FROM bank_transactions_old"))
            conn.execute(text("DROP TABLE bank_transactions_old"))
            conn.commit()
    except Exception as e:
        print(f"BankTransactions migration: {e}")

    # Add file_hash column to bank_transactions table
    try:
        result = conn.execute(text("PRAGMA table_info(bank_transactions)"))
        columns = [row[1] for row in result.fetchall()]
        if 'file_hash' not in columns:
            conn.execute(text("ALTER TABLE bank_transactions ADD COLUMN file_hash VARCHAR(64)"))
            conn.commit()
            print("Added file_hash column to bank_transactions table")
    except Exception as e:
        print(f"file_hash column migration: {e}")

    # Add organization_id columns to remaining tables
    add_col_migrations = [
        "ALTER TABLE users ADD COLUMN organization_id INTEGER REFERENCES organizations(id)",
        "ALTER TABLE reconciliation_matches ADD COLUMN organization_id INTEGER REFERENCES organizations(id)",
        "ALTER TABLE processed_file_hashes ADD COLUMN organization_id INTEGER REFERENCES organizations(id)",
    ]
    for stmt in add_col_migrations:
        try:
            conn.execute(text(stmt))
            conn.commit()
        except Exception:
            pass

    # Recreate processed_file_hashes without the GLOBAL UNIQUE(content_hash) constraint.
    # The new schema enforces uniqueness per organisation so the same invoice PDF
    # can be ingested independently by different tenants.
    try:
        pfh_sql = conn.execute(text(
            "SELECT sql FROM sqlite_master WHERE type='table' AND name='processed_file_hashes'"
        )).fetchone()
        needs_rebuild = False
        if pfh_sql and pfh_sql[0]:
            schema_sql = pfh_sql[0]
            # Old schema had `content_hash VARCHAR(32) UNIQUE` (column-level UNIQUE)
            # New schema uses table-level UNIQUE(organization_id, content_hash)
            if 'UNIQUE' in schema_sql and 'uq_processed_hash_per_org' not in schema_sql:
                needs_rebuild = True
        if needs_rebuild:
            conn.execute(text("ALTER TABLE processed_file_hashes RENAME TO processed_file_hashes_old"))
            conn.execute(text("""CREATE TABLE processed_file_hashes (
                id INTEGER PRIMARY KEY,
                content_hash VARCHAR(32) NOT NULL,
                organization_id INTEGER REFERENCES organizations(id),
                filename VARCHAR(500),
                processed_at DATETIME,
                CONSTRAINT uq_processed_hash_per_org UNIQUE (organization_id, content_hash)
            )"""))
            # Copy rows, deduplicating any (org, hash) pairs that may have collided
            conn.execute(text(
                "INSERT OR IGNORE INTO processed_file_hashes "
                "(id, content_hash, organization_id, filename, processed_at) "
                "SELECT id, content_hash, organization_id, filename, processed_at "
                "FROM processed_file_hashes_old"
            ))
            conn.execute(text("DROP TABLE processed_file_hashes_old"))
            conn.execute(text("CREATE INDEX IF NOT EXISTS ix_processed_file_hashes_content_hash ON processed_file_hashes(content_hash)"))
            conn.commit()
            print("Rebuilt processed_file_hashes with per-organisation uniqueness")
    except Exception as e:
        print(f"processed_file_hashes migration: {e}")

    # Add unique index on email (global uniqueness)
    try:
        conn.execute(text("CREATE UNIQUE INDEX IF NOT EXISTS ix_users_email ON users(email)"))
        conn.commit()
    except Exception as e:
        print(f"Email unique index migration: {e}")

    # Add plan tracking columns to organizations table
    add_org_col_migrations = [
        "ALTER TABLE organizations ADD COLUMN plan_type VARCHAR(50) DEFAULT 'trial'",
        "ALTER TABLE organizations ADD COLUMN trial_start_date DATETIME",
        "ALTER TABLE organizations ADD COLUMN trial_end_date DATETIME",
        "ALTER TABLE organizations ADD COLUMN is_trial_active BOOLEAN DEFAULT 1",
        "ALTER TABLE organizations ADD COLUMN stripe_customer_id VARCHAR(255)",
    ]
    for stmt in add_org_col_migrations:
        try:
            conn.execute(text(stmt))
            conn.commit()
        except Exception as e:
            # "duplicate column name" is expected on subsequent startups (idempotent migration)
            if "duplicate column name" not in str(e).lower():
                print(f"Organization column migration: {e}")

    # Set default plan values for existing organizations that don't have them
    from datetime import datetime, timedelta
    orgs_without_plan = conn.execute(text("SELECT id FROM organizations WHERE plan_type IS NULL")).fetchall()
    if orgs_without_plan:
        trial_start = datetime.utcnow()
        trial_end = trial_start + timedelta(days=7)
        conn.execute(text("""
            UPDATE organizations 
            SET plan_type = 'trial', 
                trial_start_date = :trial_start, 
                trial_end_date = :trial_end, 
                is_trial_active = 1 
            WHERE plan_type IS NULL
        """), {"trial_start": trial_start, "trial_end": trial_end})
        print(f"Initialized trial plan for {len(orgs_without_plan)} existing organizations")
        conn.commit()

    # Create password_reset_tokens table if not exists
    try:
        conn.execute(text("""CREATE TABLE IF NOT EXISTS password_reset_tokens (
            id INTEGER PRIMARY KEY,
            token VARCHAR(64) NOT NULL UNIQUE,
            user_id INTEGER NOT NULL REFERENCES users(id),
            expires_at DATETIME NOT NULL,
            created_at DATETIME
        )"""))
        conn.commit()
    except Exception as e:
        print(f"Password reset tokens migration: {e}")

    # Add expires_at column to user_tokens table (for token expiration)
    try:
        conn.execute(text("ALTER TABLE user_tokens ADD COLUMN expires_at DATETIME"))
        conn.commit()
    except Exception:
        pass  # Column already exists

    # Create index on user_tokens.expires_at for cleanup queries
    try:
        conn.execute(text("CREATE INDEX IF NOT EXISTS ix_user_tokens_expires_at ON user_tokens(expires_at)"))
        conn.commit()
    except Exception as e:
        print(f"user_tokens expires_at index migration: {e}")

    # Cleanup expired tokens at startup
    try:
        from datetime import datetime
        conn.execute(text("DELETE FROM user_tokens WHERE expires_at IS NOT NULL AND expires_at < :now"), {"now": datetime.utcnow()})
        conn.commit()
    except Exception as e:
        print(f"Expired token cleanup: {e}")

    conn.close()

    session = db.get_session()
    try:
        # Create default organization for existing data
        default_org = session.query(Organization).filter(Organization.id == 1).first()
        if not default_org:
            default_org = Organization(name="Organisation par défaut")
            session.add(default_org)
            session.flush()
            default_org_id = default_org.id
            session.commit()
        else:
            default_org_id = default_org.id

        # Assign existing users without org to default org
        session.execute(text(f"UPDATE users SET organization_id = {default_org_id} WHERE organization_id IS NULL"))
        session.execute(text(f"UPDATE invoices SET organization_id = {default_org_id} WHERE organization_id IS NULL"))
        session.execute(text(f"UPDATE suppliers SET organization_id = {default_org_id} WHERE organization_id IS NULL"))
        session.execute(text(f"UPDATE bank_transactions SET organization_id = {default_org_id} WHERE organization_id IS NULL"))
        session.execute(text(f"UPDATE reconciliation_matches SET organization_id = {default_org_id} WHERE organization_id IS NULL"))
        session.execute(text(f"UPDATE settings SET organization_id = {default_org_id} WHERE organization_id IS NULL"))
        session.execute(text(f"UPDATE processed_file_hashes SET organization_id = {default_org_id} WHERE organization_id IS NULL"))
        session.commit()

        # Create default admin user if not exists
        try:
            default_admin_username = os.environ.get('ADMIN_USERNAME', 'admin')
            default_admin_password = os.environ.get('ADMIN_PASSWORD', 'admin123')
            default_admin_email = os.environ.get('ADMIN_EMAIL', '')
            admin_exists = session.query(User).filter(User.username == default_admin_username).first()
            if not admin_exists:
                # Import locally to avoid circular dependency
                from src.api.auth import _hash_password
                password_hash = _hash_password(default_admin_password)
                admin = User(
                    username=default_admin_username,
                    password_hash=password_hash,
                    role=UserRole.ADMIN,
                    name='Administrateur',
                    email=default_admin_email or None,
                    organization_id=default_org_id
                )
                session.add(admin)
                session.commit()
        except Exception as e:
            print(f"Warning: Could not check/create admin user: {e}")
            session.rollback()

        # Insert default settings if not already set
        try:
            default_settings = [
                ('imap_server', 'imap.gmail.com', 'email', 'Serveur IMAP'),
                ('imap_port', '993', 'email', 'Port IMAP'),
                ('email_folder', 'INBOX', 'email', 'Dossier IMAP'),
                ('scheduler_interval', '1', 'scheduler', 'Intervalle en minutes (1 = toutes les 1 minute)'),
                ('auto_reconciliation', 'true', 'scheduler', 'Rapprochement automatique'),
                ('company_name', '', 'general', 'Nom de votre entreprise (ignoré comme fournisseur par l\'IA)'),
            ]
            for key, value, category, description in default_settings:
                exists = session.query(Settings).filter(
                    Settings.key == key, Settings.organization_id == default_org_id
                ).first()
                if not exists:
                    session.add(Settings(key=key, value=value, category=category, description=description, organization_id=default_org_id))
            session.commit()
        except Exception as e:
            print(f"Warning: Could not insert default settings: {e}")
            session.rollback()
    finally:
        session.close()
