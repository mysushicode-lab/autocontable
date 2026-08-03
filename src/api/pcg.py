"""Per-dossier PCG (Plan Comptable Général) mapping management."""
import json
import logging
from fastapi import APIRouter, Depends, HTTPException

from src.storage.database import db
from src.storage.models import Settings, ClientFile
from src.api.auth import get_current_user
from src.api.billing import require_feature
from src.constants import PCG_COMPTES, DEFAULT_COMPTE, TVA_COMPTE, FOURN_COMPTE

logger = logging.getLogger(__name__)
router = APIRouter()


def get_pcg_for_dossier(session, org_id: int, client_file_id: int) -> dict:
    """Get the PCG mapping for a specific dossier.

    Falls back to the global PCG_COMPTES if no custom mapping exists.
    Returns: {"comptes": {...}, "default": (...), "tva": (...), "fournisseur": (...)}
    """
    setting = session.query(Settings).filter(
        Settings.organization_id == org_id,
        Settings.key == f"pcg_mapping_{client_file_id}",
        Settings.category == "pcg",
    ).first()

    if setting and setting.value:
        try:
            custom = json.loads(setting.value)
            return {
                "comptes": custom.get("comptes", PCG_COMPTES),
                "default": tuple(custom.get("default", DEFAULT_COMPTE)),
                "tva": tuple(custom.get("tva", TVA_COMPTE)),
                "fournisseur": tuple(custom.get("fournisseur", FOURN_COMPTE)),
            }
        except (json.JSONDecodeError, TypeError):
            pass

    return {
        "comptes": PCG_COMPTES,
        "default": DEFAULT_COMPTE,
        "tva": TVA_COMPTE,
        "fournisseur": FOURN_COMPTE,
    }


@router.get("/default")
def get_default_pcg(current_user: dict = Depends(get_current_user)):
    """Get the default (global) PCG mapping."""
    return {
        "comptes": PCG_COMPTES,
        "default": DEFAULT_COMPTE,
        "tva": TVA_COMPTE,
        "fournisseur": FOURN_COMPTE,
    }


@router.get("/{client_file_id}")
def get_dossier_pcg(client_file_id: int, current_user: dict = Depends(get_current_user)):
    """Get the PCG mapping for a specific dossier."""
    session = db.get_session()
    try:
        org_id = current_user["organization_id"]
        pcg = get_pcg_for_dossier(session, org_id, client_file_id)
        return pcg
    finally:
        session.close()


@router.put("/{client_file_id}")
def update_dossier_pcg(client_file_id: int, payload: dict, current_user: dict = Depends(require_feature("custom_pcg"))):
    """Update the PCG mapping for a specific dossier.

    payload: {
        "comptes": {"Achats de marchandises": ["601000", "Achats de marchandises"], ...},
        "default": ["607000", "Achats non classés"],
        "tva": ["445660", "TVA déductible"],
        "fournisseur": ["401000", "Fournisseurs"]
    }
    """
    session = db.get_session()
    try:
        org_id = current_user["organization_id"]

        # Verify dossier
        cf = session.query(ClientFile).filter(
            ClientFile.id == client_file_id,
            ClientFile.organization_id == org_id
        ).first()
        if not cf:
            raise HTTPException(404, "Dossier non trouvé")

        key = f"pcg_mapping_{client_file_id}"
        existing = session.query(Settings).filter(
            Settings.organization_id == org_id,
            Settings.key == key,
            Settings.category == "pcg",
        ).first()

        value = json.dumps(payload)

        if existing:
            existing.value = value
        else:
            session.add(Settings(
                organization_id=org_id,
                key=key,
                value=value,
                category="pcg",
            ))
        session.commit()
        return {"success": True}
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


@router.delete("/{client_file_id}")
def reset_dossier_pcg(client_file_id: int, current_user: dict = Depends(require_feature("custom_pcg"))):
    """Reset a dossier's PCG to the global default."""
    session = db.get_session()
    try:
        org_id = current_user["organization_id"]
        setting = session.query(Settings).filter(
            Settings.organization_id == org_id,
            Settings.key == f"pcg_mapping_{client_file_id}",
            Settings.category == "pcg",
        ).first()
        if setting:
            session.delete(setting)
            session.commit()
        return {"success": True}
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()
