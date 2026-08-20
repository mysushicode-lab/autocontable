"""
Database models for invoice processing and bank reconciliation
"""
from datetime import datetime
from sqlalchemy import Column, Integer, String, Float, Numeric, DateTime, ForeignKey, Text, Enum, JSON, Boolean, UniqueConstraint
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship
import enum

Base = declarative_base()


class ClientFile(Base):
    """Dossier client géré par le cabinet comptable.

    Un cabinet (Organization) gère N dossiers.  Toutes les pièces comptables
    (factures, relevés bancaires, rapprochements) sont rattachées à un dossier.
    """
    __tablename__ = 'client_files'

    id = Column(Integer, primary_key=True)
    organization_id = Column(Integer, ForeignKey('organizations.id'), nullable=False, index=True)
    name = Column(String(200), nullable=False)           # "Boulangerie Martin"
    siret = Column(String(14), nullable=True)
    activity = Column(String(200), nullable=True)        # "Boulangerie-pâtisserie"
    contact_email = Column(String(200), nullable=True)   # email du client
    scheduler_email = Column(String(200), nullable=True)  # email surveillé par le scheduler pour import auto
    contact_phone = Column(String(30), nullable=True)    # mobile WhatsApp du client
    notes = Column(Text, nullable=True)
    color = Column(String(7), nullable=True, default='#3b82f6')  # Couleur hex pour différenciation visuelle
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class InvoiceStatus(enum.Enum):
    PENDING = "pending"
    PROCESSED = "processed"
    MATCHED = "matched"
    UNMATCHED = "unmatched"


class UserRole(enum.Enum):
    ADMIN = "admin"
    ACCOUNTANT = "accountant"
    CLIENT = "client"


class Organization(Base):
    __tablename__ = 'organizations'

    id = Column(Integer, primary_key=True)
    name = Column(String(200), nullable=False)
    plan_type = Column(String(50), default='free')  # 'free', 'starter', 'pro', 'cabinet', 'reseau'
    trial_start_date = Column(DateTime, nullable=True)
    trial_end_date = Column(DateTime, nullable=True)
    is_trial_active = Column(Boolean, default=True)
    stripe_customer_id = Column(String(255), nullable=True)  # Stripe customer ID for billing
    stripe_subscription_id = Column(String(255), nullable=True)  # Stripe subscription ID (pour upgrades/cancels)
    invoices_processed_this_month = Column(Integer, default=0)  # Compteur mensuel de factures IA
    monthly_quota_reset_date = Column(DateTime, nullable=True)  # Date de réinitialisation (1er du mois)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Sequence system fields
    lifecycle_stage = Column(String(50), nullable=True)
    current_sequence_id = Column(String(100), nullable=True)
    current_step_index = Column(Integer, default=0)
    sequence_entered_at = Column(DateTime, nullable=True)
    last_email_sent_at = Column(DateTime, nullable=True)
    sequence_cooldown_until = Column(DateTime, nullable=True)
    emails_sent_today = Column(Integer, default=0)
    emails_sent_this_week = Column(Integer, default=0)
    last_freq_reset_daily = Column(DateTime, nullable=True)
    last_freq_reset_weekly = Column(DateTime, nullable=True)
    engagement_score = Column(Float, default=50.0)
    total_emails_sent = Column(Integer, default=0)
    total_emails_opened = Column(Integer, default=0)

    users = relationship("User", back_populates="organization")


class UserToken(Base):
    __tablename__ = 'user_tokens'

    id = Column(Integer, primary_key=True)
    token = Column(String(64), unique=True, nullable=False, index=True)
    user_id = Column(Integer, ForeignKey('users.id'), nullable=False)
    expires_at = Column(DateTime, nullable=True, index=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="tokens")


class PasswordResetToken(Base):
    __tablename__ = 'password_reset_tokens'

    id = Column(Integer, primary_key=True)
    token = Column(String(64), unique=True, nullable=False, index=True)
    user_id = Column(Integer, ForeignKey('users.id'), nullable=False)
    expires_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User")


class User(Base):
    __tablename__ = 'users'

    id = Column(Integer, primary_key=True)
    username = Column(String(50), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=True)
    role = Column(Enum(UserRole), default=UserRole.ACCOUNTANT)
    name = Column(String(100), nullable=True)
    email = Column(String(100), nullable=True, index=True)
    profile_photo = Column(String(255), nullable=True)
    organization_id = Column(Integer, ForeignKey('organizations.id'), nullable=False, index=True)
    client_file_id = Column(Integer, ForeignKey('client_files.id'), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    organization = relationship("Organization", back_populates="users")
    tokens = relationship("UserToken", back_populates="user")

    __table_args__ = (
        UniqueConstraint('email', 'organization_id', name='uq_user_email_org'),
    )


class Settings(Base):
    __tablename__ = 'settings'

    id = Column(Integer, primary_key=True)
    key = Column(String(100), nullable=False, index=True)
    value = Column(Text, nullable=True)
    category = Column(String(50), nullable=False, default='general')
    description = Column(Text, nullable=True)
    organization_id = Column(Integer, ForeignKey('organizations.id'), nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class Invoice(Base):
    __tablename__ = 'invoices'
    
    id = Column(Integer, primary_key=True)
    invoice_number = Column(String(100), nullable=False)
    supplier_id = Column(Integer, ForeignKey('suppliers.id'), nullable=True)
    organization_id = Column(Integer, ForeignKey('organizations.id'), nullable=False, index=True)
    amount = Column(Numeric(12, 2), nullable=False)
    amount_ht = Column(Numeric(12, 2), nullable=True)
    amount_tax = Column(Numeric(12, 2), nullable=True)
    date = Column(DateTime, nullable=False)
    due_date = Column(DateTime, nullable=True)
    category = Column(String(100), nullable=True)
    status = Column(Enum(InvoiceStatus), default=InvoiceStatus.PENDING)

    client_file_id = Column(Integer, ForeignKey('client_files.id'), nullable=True, index=True)

    purchase_order = Column(String(100), nullable=True)
    delivery_note = Column(String(100), nullable=True)
    reference_number = Column(String(50), nullable=True)
    work_order_reference = Column(String(100), nullable=True)
    payment_method = Column(String(50), nullable=True)
    
    file_path = Column(String(500), nullable=True)
    email_subject = Column(String(500), nullable=True)
    email_from = Column(String(500), nullable=True)
    email_date = Column(DateTime, nullable=True)
    message_id = Column(String(200), nullable=True)
    content_hash = Column(String(32), nullable=True)
    extracted_data = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    supplier = relationship("Supplier", back_populates="invoices")
    matches = relationship("ReconciliationMatch", back_populates="invoice")


class Supplier(Base):
    __tablename__ = 'suppliers'
    
    id = Column(Integer, primary_key=True)
    name = Column(String(200), nullable=False)
    normalized_name = Column(String(200), nullable=False)
    organization_id = Column(Integer, ForeignKey('organizations.id'), nullable=False)
    email = Column(String(200), nullable=True)
    email_domain = Column(String(100), nullable=True)
    category = Column(String(100), nullable=True)
    vat_number = Column(String(50), nullable=True)
    address = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    invoices = relationship("Invoice", back_populates="supplier")


class ProcessedFileHash(Base):
    """Permanent registry of all file hashes ever processed by AI.

    Uniqueness is per-organisation so the same invoice PDF can be ingested
    independently by different tenants.
    """
    __tablename__ = 'processed_file_hashes'

    id = Column(Integer, primary_key=True)
    content_hash = Column(String(32), nullable=False, index=True)
    organization_id = Column(Integer, ForeignKey('organizations.id'), nullable=False)
    filename = Column(String(500), nullable=True)
    processed_at = Column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        UniqueConstraint('organization_id', 'content_hash', name='uq_processed_hash_per_org'),
    )


class BankTransaction(Base):
    __tablename__ = 'bank_transactions'

    id = Column(Integer, primary_key=True)
    transaction_id = Column(String(100), nullable=False)
    organization_id = Column(Integer, ForeignKey('organizations.id'), nullable=False, index=True)
    client_file_id = Column(Integer, ForeignKey('client_files.id'), nullable=True, index=True)
    date = Column(DateTime, nullable=False)
    amount = Column(Numeric(12, 2), nullable=False)
    description = Column(Text, nullable=False)
    reference = Column(String(200), nullable=True)
    account_number = Column(String(50), nullable=True)
    category = Column(String(100), nullable=True)
    source_file = Column(String(500), nullable=True)
    file_hash = Column(String(64), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    matches = relationship("ReconciliationMatch", back_populates="transaction")


class ReconciliationMatch(Base):
    __tablename__ = 'reconciliation_matches'

    id = Column(Integer, primary_key=True)
    invoice_id = Column(Integer, ForeignKey('invoices.id'), nullable=False, index=True)
    transaction_id = Column(Integer, ForeignKey('bank_transactions.id'), nullable=False, index=True)
    organization_id = Column(Integer, ForeignKey('organizations.id'), nullable=False, index=True)
    client_file_id = Column(Integer, ForeignKey('client_files.id'), nullable=True, index=True)
    match_score = Column(Float, nullable=True)
    match_type = Column(String(50), default='automatic')
    status = Column(String(50), default='confirmed')
    notes = Column(Text, nullable=True)
    matched_at = Column(DateTime, default=datetime.utcnow)
    matched_by = Column(String(100), nullable=True)

    invoice = relationship("Invoice", back_populates="matches")
    transaction = relationship("BankTransaction", back_populates="matches")


class DossierPermission(Base):
    """Links users to specific dossiers they can access."""
    __tablename__ = 'dossier_permissions'

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey('users.id'), nullable=False, index=True)
    client_file_id = Column(Integer, ForeignKey('client_files.id'), nullable=False, index=True)
    permission_level = Column(String(20), default='read_write')  # 'read_only', 'read_write', 'admin'
    created_at = Column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        UniqueConstraint('user_id', 'client_file_id', name='uq_user_dossier_perm'),
    )


class InvitationToken(Base):
    """Invitation links for PME/clients to join cabinet's organization and access dossiers"""
    __tablename__ = 'invitation_tokens'

    id = Column(Integer, primary_key=True)
    token = Column(String(64), unique=True, nullable=False, index=True)
    organization_id = Column(Integer, ForeignKey('organizations.id'), nullable=False, index=True)
    client_file_id = Column(Integer, ForeignKey('client_files.id'), nullable=True, index=True)
    invited_email = Column(String(255), nullable=False)
    permission_level = Column(String(20), default='read_write')
    expires_at = Column(DateTime, nullable=False)
    used_by_user_id = Column(Integer, ForeignKey('users.id'), nullable=True)
    used_at = Column(DateTime, nullable=True)
    created_by_user_id = Column(Integer, ForeignKey('users.id'), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)


class AuditLog(Base):
    __tablename__ = 'audit_logs'

    id = Column(Integer, primary_key=True)
    organization_id = Column(Integer, ForeignKey('organizations.id'), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey('users.id'), nullable=True, index=True)
    action = Column(String(50), nullable=False)
    entity_type = Column(String(50), nullable=False)
    entity_id = Column(Integer, nullable=True)
    details = Column(Text, nullable=True)
    ip_address = Column(String(45), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class ReferralStatus(enum.Enum):
    PENDING = "pending"
    CONVERTED = "converted"
    PAID = "paid"


class Affiliate(Base):
    __tablename__ = 'affiliates'

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey('users.id'), nullable=False, unique=True)
    code = Column(String(30), unique=True, nullable=False, index=True)
    commission_rate = Column(Float, default=0.20)
    is_active = Column(Boolean, default=True)
    total_earned = Column(Numeric(12, 2), default=0)
    total_paid = Column(Numeric(12, 2), default=0)
    stripe_account_id = Column(String(100), nullable=True)
    stripe_onboarding_complete = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    referrals = relationship("Referral", back_populates="affiliate")


class Referral(Base):
    __tablename__ = 'referrals'

    id = Column(Integer, primary_key=True)
    affiliate_id = Column(Integer, ForeignKey('affiliates.id'), nullable=False, index=True)
    referred_user_id = Column(Integer, ForeignKey('users.id'), nullable=False)
    referred_org_id = Column(Integer, ForeignKey('organizations.id'), nullable=False)
    status = Column(Enum(ReferralStatus), default=ReferralStatus.PENDING)
    commission_amount = Column(Numeric(12, 2), default=0)
    created_at = Column(DateTime, default=datetime.utcnow)
    converted_at = Column(DateTime, nullable=True)

    affiliate = relationship("Affiliate", back_populates="referrals")


class LifecycleStage(enum.Enum):
    QUIZ_LEAD = "quiz_lead"
    TRIAL_DAY0 = "trial_day0"
    TRIAL_ACTIVE = "trial_active"
    TRIAL_ENDING = "trial_ending"
    TRIAL_EXPIRED = "trial_expired"
    PAYING = "paying"
    CHURNED = "churned"


class QuizContact(Base):
    __tablename__ = 'quiz_contacts'

    id = Column(Integer, primary_key=True)
    email = Column(String(255), unique=True, nullable=False, index=True)
    getresponse_id = Column(String(100), nullable=True)  # deprecated
    state = Column(String(50), default='quiz_pending')
    lifecycle_stage = Column(Enum(LifecycleStage), default=LifecycleStage.QUIZ_LEAD)
    first_name = Column(String(100), nullable=True)
    client_count = Column(Integer, nullable=True)
    time_lost_week = Column(Integer, nullable=True)
    time_lost_month = Column(Integer, nullable=True)
    time_lost_year = Column(Integer, nullable=True)
    quiz_completed_at = Column(DateTime, nullable=True)
    account_created_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Sequence system fields
    current_sequence_id = Column(String(100), nullable=True)
    current_step_index = Column(Integer, default=0)
    sequence_entered_at = Column(DateTime, nullable=True)
    last_email_sent_at = Column(DateTime, nullable=True)
    sequence_cooldown_until = Column(DateTime, nullable=True)
    emails_sent_today = Column(Integer, default=0)
    emails_sent_this_week = Column(Integer, default=0)
    last_freq_reset_daily = Column(DateTime, nullable=True)
    last_freq_reset_weekly = Column(DateTime, nullable=True)

    email_jobs = relationship("EmailJob", back_populates="quiz_contact")


class EmailJob(Base):
    __tablename__ = 'email_jobs'

    id = Column(Integer, primary_key=True)
    quiz_contact_id = Column(Integer, ForeignKey('quiz_contacts.id'), nullable=True, index=True)
    organization_id = Column(Integer, ForeignKey('organizations.id'), nullable=True, index=True)
    user_id = Column(Integer, ForeignKey('users.id'), nullable=True, index=True)
    lifecycle_stage = Column(Enum(LifecycleStage), nullable=True)
    email_type = Column(String(50), nullable=False)
    scheduled_for = Column(DateTime, nullable=False, index=True)
    sent_at = Column(DateTime, nullable=True)
    status = Column(String(20), default='pending')  # pending, sent, cancelled, failed
    error_message = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    quiz_contact = relationship("QuizContact", back_populates="email_jobs")


class SequencePool(Base):
    __tablename__ = 'sequence_pools'

    id = Column(Integer, primary_key=True)
    pool_id = Column(String(100), unique=True, nullable=False, index=True)
    name = Column(String(200), nullable=False)
    strategy = Column(String(50), default='chronological')  # chronological, round_robin, priority
    target_lifecycle_stages = Column(JSON, default=list)  # list of LifecycleStage values
    cooldown_days = Column(Integer, default=0)
    loop_when_exhausted = Column(Boolean, default=False)
    loop_cooldown_days = Column(Integer, default=90)
    fallback_pool_id = Column(String(100), nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class SequenceDefinition(Base):
    __tablename__ = 'sequence_definitions'

    id = Column(Integer, primary_key=True)
    sequence_id = Column(String(100), unique=True, nullable=False, index=True)
    name = Column(String(200), nullable=False)
    pool_id = Column(String(100), nullable=False, index=True)
    target_lifecycle_stages = Column(JSON, default=list)
    priority = Column(Integer, default=50)
    steps = Column(JSON, default=list)  # list of {step_index, email_type, delay_days, delay_hours}
    on_complete_action = Column(String(50), default='exit')  # exit, next_in_pool, move_to_pool, cooldown_then_loop
    on_complete_next_pool = Column(String(100), nullable=True)
    on_complete_cooldown_days = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class EmailEvent(Base):
    """Per-email event log — powers engagement scoring.
    New table: create_all() adds it automatically, no migration required.
    """
    __tablename__ = 'email_events'

    id = Column(Integer, primary_key=True)
    organization_id  = Column(Integer, ForeignKey('organizations.id'),  nullable=True, index=True)
    quiz_contact_id  = Column(Integer, ForeignKey('quiz_contacts.id'),  nullable=True, index=True)
    user_id          = Column(Integer, ForeignKey('users.id'),          nullable=True, index=True)
    email_type       = Column(String(80),  nullable=False)
    event            = Column(String(30),  nullable=False)  # sent|opened|clicked|bounced|unsubscribed|complained
    bounce_type      = Column(String(20),  nullable=True)   # hard|soft
    occurred_at      = Column(DateTime, default=datetime.utcnow, index=True)


class EmailSuppression(Base):
    """Email suppression list — unsubscribed, hard bounce, spam complaint.
    New table: create_all() adds it automatically, no migration required.
    """
    __tablename__ = 'email_suppressions'

    id = Column(Integer, primary_key=True)
    email = Column(String(200), nullable=False, unique=True, index=True)
    reason = Column(String(50), nullable=True)  # 'unsubscribed' | 'hard_bounce' | 'spam_complaint'
    created_at = Column(DateTime, default=datetime.utcnow)


class CompletedSequence(Base):
    __tablename__ = 'completed_sequences'

    id = Column(Integer, primary_key=True)
    organization_id = Column(Integer, ForeignKey('organizations.id'), nullable=True, index=True)
    user_id = Column(Integer, ForeignKey('users.id'), nullable=True, index=True)
    quiz_contact_id = Column(Integer, ForeignKey('quiz_contacts.id'), nullable=True, index=True)
    sequence_id = Column(String(100), nullable=False)
    pool_id = Column(String(100), nullable=False)
    completed_at = Column(DateTime, default=datetime.utcnow)
