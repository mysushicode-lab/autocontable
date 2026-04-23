"""
Database models for invoice processing and bank reconciliation
"""
from datetime import datetime
from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Text, Enum
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship
import enum

Base = declarative_base()


class InvoiceStatus(enum.Enum):
    PENDING = "pending"
    PROCESSED = "processed"
    MATCHED = "matched"
    UNMATCHED = "unmatched"


class Invoice(Base):
    __tablename__ = 'invoices'
    
    id = Column(Integer, primary_key=True)
    invoice_number = Column(String(100), unique=True, nullable=False)
    supplier_id = Column(Integer, ForeignKey('suppliers.id'), nullable=True)
    amount = Column(Float, nullable=False)
    amount_tax = Column(Float, nullable=True)
    date = Column(DateTime, nullable=False)
    due_date = Column(DateTime, nullable=True)
    category = Column(String(100), nullable=True)
    status = Column(Enum(InvoiceStatus), default=InvoiceStatus.PENDING)
    
    # Carrosserie specific fields
    purchase_order = Column(String(100), nullable=True)  # Numéro de commande
    delivery_note = Column(String(100), nullable=True)   # Numéro de BL
    vehicle_registration = Column(String(20), nullable=True)  # Immatriculation
    work_order_reference = Column(String(100), nullable=True)  # N° dossier/OT
    payment_method = Column(String(50), nullable=True)  # Mode de paiement
    
    file_path = Column(String(500), nullable=True)
    email_subject = Column(String(500), nullable=True)
    email_from = Column(String(500), nullable=True)
    email_date = Column(DateTime, nullable=True)
    message_id = Column(String(200), nullable=True)  # Email Message-ID for dedup
    content_hash = Column(String(32), nullable=True)  # MD5 hash for dedup
    extracted_data = Column(Text, nullable=True)  # JSON string
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    supplier = relationship("Supplier", back_populates="invoices")
    matches = relationship("ReconciliationMatch", back_populates="invoice")


class Supplier(Base):
    __tablename__ = 'suppliers'
    
    id = Column(Integer, primary_key=True)
    name = Column(String(200), unique=True, nullable=False)
    normalized_name = Column(String(200), unique=True, nullable=False)
    email = Column(String(200), nullable=True)  # Complete email address from sender
    email_domain = Column(String(100), nullable=True)
    category = Column(String(100), nullable=True)
    vat_number = Column(String(50), nullable=True)
    address = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    invoices = relationship("Invoice", back_populates="supplier")


class BankTransaction(Base):
    __tablename__ = 'bank_transactions'
    
    id = Column(Integer, primary_key=True)
    transaction_id = Column(String(100), unique=True, nullable=False)
    date = Column(DateTime, nullable=False)
    amount = Column(Float, nullable=False)
    description = Column(Text, nullable=False)
    reference = Column(String(200), nullable=True)
    account_number = Column(String(50), nullable=True)
    category = Column(String(100), nullable=True)
    source_file = Column(String(500), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    matches = relationship("ReconciliationMatch", back_populates="transaction")


class ReconciliationMatch(Base):
    __tablename__ = 'reconciliation_matches'
    
    id = Column(Integer, primary_key=True)
    invoice_id = Column(Integer, ForeignKey('invoices.id'), nullable=False)
    transaction_id = Column(Integer, ForeignKey('bank_transactions.id'), nullable=False)
    match_score = Column(Float, nullable=True)  # Confidence score 0-1
    match_type = Column(String(50), default='automatic')  # automatic, manual, review
    status = Column(String(50), default='pending')  # pending, confirmed, rejected
    notes = Column(Text, nullable=True)
    matched_at = Column(DateTime, default=datetime.utcnow)
    matched_by = Column(String(100), nullable=True)  # system or user
    
    # Relationships
    invoice = relationship("Invoice", back_populates="matches")
    transaction = relationship("BankTransaction", back_populates="matches")
