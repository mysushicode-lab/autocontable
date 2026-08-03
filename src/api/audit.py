"""Audit logging endpoints and utilities"""
from fastapi import APIRouter, Depends, HTTPException
from typing import Optional
from datetime import datetime
import json
import logging

from src.storage.database import db
from src.storage.models import AuditLog, User, UserRole

from src.api.auth import get_current_user
from src.api.billing import require_feature

logger = logging.getLogger(__name__)
router = APIRouter()


def log_action(
    session,
    organization_id: int,
    user_id: Optional[int],
    action: str,
    entity_type: str,
    entity_id: Optional[int] = None,
    details: Optional[dict] = None,
    ip_address: Optional[str] = None
):
    """Create an audit log entry.

    Args:
        session: Database session
        organization_id: Organization ID
        user_id: User ID (can be None for system actions)
        action: Action type ('create', 'update', 'delete', 'confirm', 'reject', 'export', 'login')
        entity_type: Entity type ('invoice', 'transaction', 'match', 'client_file', 'settings')
        entity_id: ID of the entity affected (optional)
        details: Additional details as dict (will be serialized to JSON)
        ip_address: IP address of the client
    """
    try:
        audit_log = AuditLog(
            organization_id=organization_id,
            user_id=user_id,
            action=action,
            entity_type=entity_type,
            entity_id=entity_id,
            details=json.dumps(details) if details else None,
            ip_address=ip_address,
            created_at=datetime.utcnow()
        )
        session.add(audit_log)
        session.commit()
    except Exception as e:
        logger.error(f"Failed to create audit log: {e}")
        session.rollback()


@router.get("/")
def get_audit_logs(
    page: int = 1,
    per_page: int = 50,
    entity_type: Optional[str] = None,
    action: Optional[str] = None,
    user_id: Optional[int] = None,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    current_user: dict = Depends(require_feature("audit_log"))
):
    """Get audit logs for the organization.

    Only admin users can access audit logs.
    """
    # Check if user is admin
    if current_user.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Only administrators can view audit logs")

    session = db.get_session()
    org_id = current_user["organization_id"]

    try:
        query = session.query(AuditLog).filter(AuditLog.organization_id == org_id)

        # Apply filters
        if entity_type:
            query = query.filter(AuditLog.entity_type == entity_type)
        if action:
            query = query.filter(AuditLog.action == action)
        if user_id:
            query = query.filter(AuditLog.user_id == user_id)
        if date_from:
            try:
                date_from_dt = datetime.fromisoformat(date_from.replace('Z', '+00:00'))
                query = query.filter(AuditLog.created_at >= date_from_dt)
            except ValueError:
                pass
        if date_to:
            try:
                date_to_dt = datetime.fromisoformat(date_to.replace('Z', '+00:00'))
                query = query.filter(AuditLog.created_at <= date_to_dt)
            except ValueError:
                pass

        # Count total
        total = query.count()

        # Paginate
        query = query.order_by(AuditLog.created_at.desc())
        query = query.offset((page - 1) * per_page).limit(per_page)

        logs = query.all()

        # Fetch user names for display
        user_ids = list(set([log.user_id for log in logs if log.user_id]))
        users_map = {}
        if user_ids:
            users = session.query(User).filter(User.id.in_(user_ids)).all()
            users_map = {user.id: user.name or user.username for user in users}

        # Serialize logs
        serialized_logs = []
        for log in logs:
            serialized_logs.append({
                "id": log.id,
                "user_id": log.user_id,
                "user_name": users_map.get(log.user_id, "Système") if log.user_id else "Système",
                "action": log.action,
                "entity_type": log.entity_type,
                "entity_id": log.entity_id,
                "details": log.details,
                "ip_address": log.ip_address,
                "created_at": log.created_at.isoformat() if log.created_at else None,
            })

        return {
            "logs": serialized_logs,
            "total": total,
            "page": page,
            "per_page": per_page,
            "total_pages": (total + per_page - 1) // per_page
        }
    finally:
        session.close()
