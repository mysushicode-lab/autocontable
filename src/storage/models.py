"""
Database models for invoice processing and bank reconciliation
"""
from datetime import datetime
from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Text, Enum, JSON, Boolean
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship
import enum

Base = declarative_base()


class InvoiceStatus(enum.Enum):
    PENDING = "pending"
    PROCESSED = "processed"
    MATCHED = "matched"
    UNMATCHED = "unmatched"


class UserRole(enum.Enum):
    ADMIN = "admin"
    ACCOUNTANT = "accountant"


class Organization(Base):
    __tablename__ = 'organizations'

    id = Column(Integer, primary_key=True)
    name = Column(String(200), nullable=False)
    plan_type = Column(String(50), default='trial')  # 'trial', 'free', 'paid'
    trial_start_date = Column(DateTime, nullable=True)
    trial_end_date = Column(DateTime, nullable=True)
    is_trial_active = Column(Boolean, default=True)
    stripe_customer_id = Column(String(255), nullable=True)  # Stripe customer ID for billing
    created_at = Column(DateTime, default=datetime.utcnow)

    users = relationship("User", back_populates="organization")


class UserToken(Base):
    __tablename__ = 'user_tokens'

    id = Column(Integer, primary_key=True)
    token = Column(String(64), unique=True, nullable=False, index=True)
    user_id = Column(Integer, ForeignKey('users.id'), nullable=False)
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
    password_hash = Column(String(255), nullable=False)
    role = Column(Enum(UserRole), default=UserRole.ACCOUNTANT)
    name = Column(String(100), nullable=True)
    email = Column(String(100), nullable=True, unique=True, index=True)
    profile_photo = Column(String(255), nullable=True)
    organization_id = Column(Integer, ForeignKey('organizations.id'), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    organization = relationship("Organization", back_populates="users")
    tokens = relationship("UserToken", back_populates="user")


class Settings(Base):
    __tablename__ = 'settings'

    id = Column(Integer, primary_key=True)
    key = Column(String(100), nullable=False, index=True)
    value = Column(Text, nullable=True)
    category = Column(String(50), nullable=False, default='general')
    description = Column(Text, nullable=True)
    organization_id = Column(Integer, ForeignKey('organizations.id'), nullable=True)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class Invoice(Base):
    __tablename__ = 'invoices'
    
    id = Column(Integer, primary_key=True)
    invoice_number = Column(String(100), nullable=False)
    supplier_id = Column(Integer, ForeignKey('suppliers.id'), nullable=True)
    organization_id = Column(Integer, ForeignKey('organizations.id'), nullable=True)
    amount = Column(Float, nullable=False)
    amount_ht = Column(Float, nullable=True)
    amount_tax = Column(Float, nullable=True)
    date = Column(DateTime, nullable=False)
    due_date = Column(DateTime, nullable=True)
    category = Column(String(100), nullable=True)
    status = Column(Enum(InvoiceStatus), default=InvoiceStatus.PENDING)
    
    purchase_order = Column(String(100), nullable=True)
    delivery_note = Column(String(100), nullable=True)
    vehicle_registration = Column(String(20), nullable=True)
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
    organization_id = Column(Integer, ForeignKey('organizations.id'), nullable=True)
    email = Column(String(200), nullable=True)
    email_domain = Column(String(100), nullable=True)
    category = Column(String(100), nullable=True)
    vat_number = Column(String(50), nullable=True)
    address = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    invoices = relationship("Invoice", back_populates="supplier")


class ProcessedFileHash(Base):
    """Permanent registry of all file hashes ever processed by AI."""
    __tablename__ = 'processed_file_hashes'

    id = Column(Integer, primary_key=True)
    content_hash = Column(String(32), unique=True, nullable=False, index=True)
    organization_id = Column(Integer, ForeignKey('organizations.id'), nullable=True)
    filename = Column(String(500), nullable=True)
    processed_at = Column(DateTime, default=datetime.utcnow)


class BankTransaction(Base):
    __tablename__ = 'bank_transactions'
    
    id = Column(Integer, primary_key=True)
    transaction_id = Column(String(100), nullable=False)
    organization_id = Column(Integer, ForeignKey('organizations.id'), nullable=True)
    date = Column(DateTime, nullable=False)
    amount = Column(Float, nullable=False)
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
    invoice_id = Column(Integer, ForeignKey('invoices.id'), nullable=False)
    transaction_id = Column(Integer, ForeignKey('bank_transactions.id'), nullable=False)
    organization_id = Column(Integer, ForeignKey('organizations.id'), nullable=True)
    match_score = Column(Float, nullable=True)
    match_type = Column(String(50), default='automatic')
    status = Column(String(50), default='confirmed')
    notes = Column(Text, nullable=True)
    matched_at = Column(DateTime, default=datetime.utcnow)
    matched_by = Column(String(100), nullable=True)
    
    invoice = relationship("Invoice", back_populates="matches")
    transaction = relationship("BankTransaction", back_populates="matches")
