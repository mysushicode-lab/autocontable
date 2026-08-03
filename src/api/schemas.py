"""Pydantic schemas for API requests and responses"""
from pydantic import BaseModel, field_validator
from typing import Optional


def _validate_password(password: str) -> str:
    """Shared password validation: min 8 chars, 1 uppercase, 1 lowercase, 1 digit, 1 special char."""
    if len(password) < 8:
        raise ValueError('Le mot de passe doit contenir au moins 8 caractères')
    if not any(c.isupper() for c in password):
        raise ValueError('Le mot de passe doit contenir au moins une majuscule')
    if not any(c.islower() for c in password):
        raise ValueError('Le mot de passe doit contenir au moins une minuscule')
    if not any(c.isdigit() for c in password):
        raise ValueError('Le mot de passe doit contenir au moins un chiffre')
    if not any(c in '!@#$%^&*()_+-=[]{}|;:,.<>?' for c in password):
        raise ValueError('Le mot de passe doit contenir au moins un caractère spécial')
    return password


class ManualLinkPayload(BaseModel):
    invoice_id: int
    transaction_id: int
    notes: Optional[str] = None


class UpdateInvoiceRequest(BaseModel):
    invoice_number: Optional[str] = None
    supplier_name: Optional[str] = None
    amount: Optional[float] = None
    amount_ht: Optional[float] = None
    amount_tax: Optional[float] = None
    date: Optional[str] = None
    due_date: Optional[str] = None
    category: Optional[str] = None
    reference_number: Optional[str] = None
    work_order_reference: Optional[str] = None
    purchase_order: Optional[str] = None
    payment_method: Optional[str] = None
    status: Optional[str] = None


class SettingUpdate(BaseModel):
    value: str


class TestImapRequest(BaseModel):
    server: str
    port: int
    email: str
    password: str


class LoginRequest(BaseModel):
    username: str
    password: str


class CreateUserRequest(BaseModel):
    username: str
    password: str
    name: str
    email: Optional[str] = None
    role: str = "accountant"

    @field_validator('password')
    @classmethod
    def validate_password(cls, v):
        return _validate_password(v)


class RegisterRequest(BaseModel):
    username: str
    password: str
    name: str
    email: str

    @field_validator('password')
    @classmethod
    def validate_password(cls, v):
        return _validate_password(v)


class UpdateUserRequest(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None


class ForgotPasswordRequest(BaseModel):
    email: str


class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str


class ChangeUsernameRequest(BaseModel):
    new_username: str


class ChangeEmailRequest(BaseModel):
    new_email: str
