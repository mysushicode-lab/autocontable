"""Pydantic schemas for API requests and responses"""
from pydantic import BaseModel
from typing import Optional


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
    vehicle_registration: Optional[str] = None
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


class RegisterRequest(BaseModel):
    username: str
    password: str
    name: str
    email: str


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
