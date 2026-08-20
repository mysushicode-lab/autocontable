"""
Quota management for API usage limits per plan
"""
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from src.storage.models import Organization


# Quotas mensuels par plan
PLAN_QUOTAS = {
    'free': 80,        # 80 factures IA / mois
    'starter': 400,    # 400 factures IA / mois
    'pro': 1500,       # 1500 factures IA / mois
    'reseau': None,    # Illimité
}


def get_quota_for_plan(plan_type: str) -> int | None:
    """
    Retourne la limite mensuelle de factures IA pour un plan donné.
    None = illimité
    """
    return PLAN_QUOTAS.get(plan_type, PLAN_QUOTAS['free'])


def check_and_reset_quota(org: Organization, session: Session) -> None:
    """
    Vérifie si le quota mensuel doit être réinitialisé (1er du mois).
    Si oui, reset le compteur et update la date.
    """
    now = datetime.utcnow()

    # Si pas de date de reset, initialiser au 1er du mois prochain
    if not org.monthly_quota_reset_date:
        next_month = now.replace(day=1) + timedelta(days=32)
        org.monthly_quota_reset_date = next_month.replace(day=1)
        org.invoices_processed_this_month = 0
        session.commit()
        return

    # Si on a dépassé la date de reset, réinitialiser
    if now >= org.monthly_quota_reset_date:
        org.invoices_processed_this_month = 0
        # Calculer le 1er du mois suivant
        next_month = org.monthly_quota_reset_date + timedelta(days=32)
        org.monthly_quota_reset_date = next_month.replace(day=1)
        session.commit()


def can_process_invoice(org: Organization, session: Session) -> tuple[bool, str]:
    """
    Vérifie si l'org peut traiter une nouvelle facture IA.

    Returns:
        (True, "") si OK
        (False, "message d'erreur") si quota dépassé
    """
    # Reset quota si nécessaire
    check_and_reset_quota(org, session)

    # Vérifier la limite
    quota = get_quota_for_plan(org.plan_type)

    # Illimité
    if quota is None:
        return True, ""

    # Vérifier le compteur
    if org.invoices_processed_this_month >= quota:
        return False, f"Quota mensuel atteint ({quota} factures IA). Passez à un plan supérieur."

    return True, ""


def increment_invoice_count(org: Organization, session: Session) -> None:
    """
    Incrémente le compteur de factures traitées ce mois.
    Appeler APRÈS le traitement IA réussi.
    Déclenche l'email quota_80_percent quand le seuil 80% est franchi.
    """
    prev = org.invoices_processed_this_month or 0
    org.invoices_processed_this_month = prev + 1
    session.commit()

    # Fire quota_80_percent email once when crossing 80% threshold
    quota = get_quota_for_plan(org.plan_type)
    if quota and quota > 0:
        threshold = int(quota * 0.8)
        if prev < threshold <= org.invoices_processed_this_month:
            try:
                from src.scheduler.lifecycle_engine import on_quota_reached_80
                on_quota_reached_80(session, organization_id=org.id)
            except Exception as e:
                import logging
                logging.getLogger(__name__).error(f"[quota] on_quota_reached_80 failed: {e}")


def get_quota_status(org: Organization, session: Session) -> dict:
    """
    Retourne le statut du quota pour l'API frontend.
    """
    check_and_reset_quota(org, session)

    quota = get_quota_for_plan(org.plan_type)
    used = org.invoices_processed_this_month or 0

    return {
        "plan": org.plan_type,
        "quota": quota,  # None = illimité
        "used": used,
        "remaining": None if quota is None else max(0, quota - used),
        "reset_date": org.monthly_quota_reset_date.isoformat() if org.monthly_quota_reset_date else None,
    }
