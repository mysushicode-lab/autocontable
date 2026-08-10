"""Client portal endpoints — read-only access for business owners."""
import os
import hashlib
import secrets
import logging
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from src.storage.database import db
from src.storage.models import Invoice, ClientFile, User, UserRole, InvoiceStatus, ProcessedFileHash
from src.api.auth import get_current_user, _hash_password
from src.api.client_portal_helpers import get_client_file_id, check_write_permission

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/summary")
def get_client_summary(client_file_id: int = None, current_user: dict = Depends(get_current_user)):
    """Get a simplified summary for the client portal."""
    session = db.get_session()
    try:
        org_id = current_user["organization_id"]
        cfid = get_client_file_id(current_user, session) or client_file_id
        if not cfid:
            raise HTTPException(400, "Aucun dossier sélectionné")

        # Verify access
        cf = session.query(ClientFile).filter(
            ClientFile.id == cfid,
            ClientFile.organization_id == org_id
        ).first()
        if not cf:
            raise HTTPException(404, "Dossier non trouvé")

        # Counts
        total_invoices = session.query(Invoice).filter(
            Invoice.organization_id == org_id,
            Invoice.client_file_id == cfid
        ).count()

        matched = session.query(Invoice).filter(
            Invoice.organization_id == org_id,
            Invoice.client_file_id == cfid,
            Invoice.status == InvoiceStatus.MATCHED
        ).count()

        unmatched = session.query(Invoice).filter(
            Invoice.organization_id == org_id,
            Invoice.client_file_id == cfid,
            Invoice.status == InvoiceStatus.UNMATCHED
        ).count()

        pending = session.query(Invoice).filter(
            Invoice.organization_id == org_id,
            Invoice.client_file_id == cfid,
            Invoice.status == InvoiceStatus.PENDING
        ).count()

        # Recent invoices (last 10)
        recent = session.query(Invoice).filter(
            Invoice.organization_id == org_id,
            Invoice.client_file_id == cfid
        ).order_by(Invoice.date.desc()).limit(10).all()

        return {
            "dossier": {"id": cf.id, "name": cf.name},
            "stats": {
                "total_invoices": total_invoices,
                "matched": matched,
                "unmatched": unmatched,
                "pending": pending,
                "match_rate": round(matched / total_invoices * 100, 1) if total_invoices > 0 else 0,
            },
            "recent_invoices": [
                {
                    "id": inv.id,
                    "invoice_number": inv.invoice_number,
                    "supplier": inv.supplier.name if inv.supplier else None,
                    "amount": inv.amount,
                    "date": inv.date.isoformat() if inv.date else None,
                    "status": inv.status.value if inv.status else None,
                }
                for inv in recent
            ],
        }
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


@router.get("/invoices")
def get_client_invoices(
    client_file_id: int = None,
    page: int = 1,
    per_page: int = 20,
    current_user: dict = Depends(get_current_user)
):
    """List invoices for the client portal (paginated)."""
    session = db.get_session()
    try:
        org_id = current_user["organization_id"]
        user_role = current_user.get("role")

        # Si admin : toutes les factures de l'org
        # Si client : uniquement son dossier
        if user_role == "admin":
            query = session.query(Invoice).filter(
                Invoice.organization_id == org_id
            )
            # Filtre optionnel par dossier
            if client_file_id:
                query = query.filter(Invoice.client_file_id == client_file_id)
        else:
            cfid = get_client_file_id(current_user, session) or client_file_id
            if not cfid:
                raise HTTPException(400, "Aucun dossier sélectionné")
            query = session.query(Invoice).filter(
                Invoice.organization_id == org_id,
                Invoice.client_file_id == cfid
            )

        query = query.order_by(Invoice.date.desc())

        total = query.count()
        invoices = query.offset((page - 1) * per_page).limit(per_page).all()

        return {
            "invoices": [
                {
                    "id": inv.id,
                    "invoice_number": inv.invoice_number,
                    "supplier": inv.supplier.name if inv.supplier else None,
                    "amount": inv.amount,
                    "amount_ht": inv.amount_ht,
                    "amount_tax": inv.amount_tax,
                    "date": inv.date.isoformat() if inv.date else None,
                    "due_date": inv.due_date.isoformat() if inv.due_date else None,
                    "category": inv.category,
                    "status": inv.status.value if inv.status else None,
                }
                for inv in invoices
            ],
            "total": total,
            "page": page,
            "total_pages": (total + per_page - 1) // per_page,
        }
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


@router.post("/upload")
async def portal_upload_invoice(
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user)
):
    """Allow client users to upload invoices from their portal.

    Only users with role 'client' and an assigned client_file_id can use this.
    Clients must have write permission (not read_only).
    Processes the file through InvoiceProcessor like normal uploads.
    """
    role = current_user.get("role", "")
    client_file_id = current_user.get("client_file_id")
    org_id = current_user["organization_id"]

    # Accountants and admins can also upload via portal if they have context
    if role == "client" and not client_file_id:
        raise HTTPException(400, "Aucun dossier associé à votre compte")

    # Check write permission (blocks read_only users)
    session = db.get_session()
    try:
        check_write_permission(current_user, session)
    finally:
        session.close()

    # Validate file
    if not file.filename:
        raise HTTPException(400, "Fichier requis")

    allowed_extensions = {'.pdf', '.png', '.jpg', '.jpeg'}
    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in allowed_extensions:
        raise HTTPException(400, f"Format non supporté. Formats acceptés : PDF, PNG, JPG")

    # Save file
    from src.utils.paths import INVOICES_DIR
    os.makedirs(INVOICES_DIR, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S%f")
    safe_filename = f"{timestamp}_{file.filename.replace(' ', '_')}"
    file_path = os.path.join(INVOICES_DIR, safe_filename)

    content = await file.read()
    _max_upload = int(os.getenv("MAX_UPLOAD_SIZE_MB", 10)) * 1024 * 1024
    if len(content) > _max_upload:
        raise HTTPException(400, "Fichier trop volumineux (max 10 Mo)")

    with open(file_path, "wb") as f:
        f.write(content)

    # Compute hash for dedup
    content_hash = hashlib.md5(content).hexdigest()

    session = db.get_session()
    try:
        # Check duplicate
        existing = session.query(ProcessedFileHash).filter(
            ProcessedFileHash.content_hash == content_hash,
            ProcessedFileHash.organization_id == org_id,
        ).first()
        if existing:
            os.remove(file_path)
            raise HTTPException(409, "Ce document a déjà été importé")

        # Process through AI
        from src.invoice_processor import InvoiceProcessor
        processor = InvoiceProcessor()
        invoice_data = processor.process_invoice(file_path, email_metadata={
            "email_from": f"portal:{current_user.get('username', 'client')}",
            "email_subject": f"Upload portail — {file.filename}",
        })

        if invoice_data.get("not_an_invoice"):
            os.remove(file_path)
            raise HTTPException(400, "Ce document ne semble pas être une facture")

        # Create invoice
        invoice = Invoice(
            invoice_number=invoice_data.get("invoice_number") or f"PTL-{timestamp[:14]}",
            supplier_id=invoice_data.get("supplier_id"),
            amount=invoice_data.get("amount") or 0,
            amount_ht=invoice_data.get("amount_ht"),
            amount_tax=invoice_data.get("amount_tax"),
            date=invoice_data.get("date") or datetime.now(),
            due_date=invoice_data.get("due_date"),
            category=invoice_data.get("category"),
            reference_number=invoice_data.get("reference_number"),
            organization_id=org_id,
            client_file_id=client_file_id,
            file_path=file_path,
            email_from=f"portal:{current_user.get('username', 'client')}",
            content_hash=content_hash,
            status=InvoiceStatus.PROCESSED,
        )
        session.add(invoice)

        # Register hash
        session.add(ProcessedFileHash(
            content_hash=content_hash,
            filename=file.filename,
            organization_id=org_id,
        ))
        session.commit()

        return {
            "success": True,
            "invoice_id": invoice.id,
            "invoice_number": invoice.invoice_number,
            "supplier": invoice_data.get("supplier_name"),
            "amount": invoice.amount,
            "message": "Facture importée avec succès"
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[portal-upload] Error: {e}")
        session.rollback()
        raise HTTPException(500, "Erreur lors du traitement")
    finally:
        session.close()


@router.post("/invite")
def invite_client(payload: dict, current_user: dict = Depends(get_current_user)):
    """Invite a client user. Only accountants/admins can invite.

    payload: {"email": "...", "client_file_id": 123, "name": "Jean Martin"}
    """
    if current_user.get("role") == "client":
        raise HTTPException(403, "Les clients ne peuvent pas inviter d'autres utilisateurs")

    session = db.get_session()
    try:
        org_id = current_user["organization_id"]
        email = payload.get("email")
        cfid = payload.get("client_file_id")
        name = payload.get("name", "")

        if not email or not cfid:
            raise HTTPException(400, "Email et dossier requis")

        # Verify dossier belongs to org
        cf = session.query(ClientFile).filter(
            ClientFile.id == cfid,
            ClientFile.organization_id == org_id
        ).first()
        if not cf:
            raise HTTPException(404, "Dossier non trouvé")

        # Check if user already exists
        existing = session.query(User).filter(User.email == email).first()
        if existing:
            raise HTTPException(400, "Un compte existe déjà avec cet email")

        # Create client user with temporary password
        temp_password = secrets.token_urlsafe(12)

        user = User(
            username=email,
            email=email,
            name=name,
            password_hash=_hash_password(temp_password),
            role=UserRole.CLIENT,
            organization_id=org_id,
            client_file_id=cfid,
        )
        session.add(user)
        session.commit()

        # Send invitation email
        try:
            from src.notifications.email_sender import send_email
            send_email(
                to=email,
                subject=f"[FactPilot] Accès à votre espace — {cf.name}",
                body_html=f"""
                <html>
                <body style="font-family: -apple-system, sans-serif; color: #181818; max-width: 600px; margin: 0 auto;">
                <h2 style="font-size: 18px; margin-bottom: 16px;">Bienvenue sur FactPilot</h2>
                <p style="color: #374151;">Bonjour {name},</p>
                <p style="color: #374151;">Votre comptable vous a donné accès à votre espace FactPilot.</p>
                <p style="color: #374151;">Connectez-vous avec :</p>
                <ul style="color: #374151;">
                    <li>Email : <strong>{email}</strong></li>
                    <li>Mot de passe temporaire : <strong>{temp_password}</strong></li>
                </ul>
                <p style="color: #374151;">Vous pourrez consulter vos factures et l'état de vos rapprochements.</p>
                <hr style="border: none; border-top: 1px solid #e5e7eb; margin: 20px 0;">
                <p style="font-size: 11px; color: #9ca3af;">FactPilot — Comptabilité automatisée</p>
                </body>
                </html>
                """
            )
        except Exception:
            pass  # Email failure shouldn't block user creation

        return {
            "success": True,
            "user_id": user.id,
            "message": f"Invitation envoyée à {email}",
            "temp_password": temp_password,  # Show once for the accountant to share manually if email fails
        }
    finally:
        session.close()
