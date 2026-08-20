"""Email engagement scoring — port of minimoes engagementScoring.ts.

Score 0-100 based on opens, clicks and recency over the last 30 days.
The score adjusts frequency caps so low-engagement contacts receive fewer
emails while high-engagement contacts receive full cadence.
"""
from datetime import datetime, timedelta
from sqlalchemy.orm import Session

from src.storage.models import Organization, EmailEvent


_30_DAYS = timedelta(days=30)


def calculate_engagement_score(
    session: Session,
    *,
    organization_id: int = None,
    quiz_contact_id: int = None,
) -> float:
    """Return a 0-100 engagement score for an org or quiz contact.

    Algorithm mirrors minimoes:
      base            =  50
      recency bonus   =  0-20  (last open: <1d=+20, <3d=+15, <7d=+10, <14d=+5)
      open rate 30d   =  0-20  (rate × 20)
      click rate 30d  =  0-10  (rate × 10)
      new subscriber  = +15    (no sent yet — benefit of the doubt)
      hard bounce     = -10
      stale >30d      = -15
      stale >60d      = -25
      clamp           = [0, 100]
    """
    now = datetime.utcnow()
    since = now - _30_DAYS

    base_filter = []
    if organization_id:
        base_filter.append(EmailEvent.organization_id == organization_id)
    elif quiz_contact_id:
        base_filter.append(EmailEvent.quiz_contact_id == quiz_contact_id)
    else:
        return 50.0

    recent = session.query(EmailEvent).filter(
        *base_filter,
        EmailEvent.occurred_at >= since,
    ).all()

    sends   = sum(1 for e in recent if e.event == 'sent')
    opens   = sum(1 for e in recent if e.event == 'opened')
    clicks  = sum(1 for e in recent if e.event == 'clicked')
    bounces = sum(1 for e in recent if e.event == 'bounced')

    open_rate  = opens  / sends if sends > 0 else 0.0
    click_rate = clicks / sends if sends > 0 else 0.0

    score = 50.0

    # Recency bonus — time since last open
    last_open_event = session.query(EmailEvent).filter(
        *base_filter,
        EmailEvent.event == 'opened',
    ).order_by(EmailEvent.occurred_at.desc()).first()

    if last_open_event:
        days_since_open = (now - last_open_event.occurred_at).total_seconds() / 86400
        if   days_since_open <= 1:  score += 20
        elif days_since_open <= 3:  score += 15
        elif days_since_open <= 7:  score += 10
        elif days_since_open <= 14: score += 5
    elif sends == 0:
        score += 15  # New — benefit of the doubt

    # Activity ratio
    score += open_rate  * 20
    score += click_rate * 10

    # Negative signals
    if bounces > 0:
        score -= 10 * bounces
    if last_open_event:
        days = (now - last_open_event.occurred_at).total_seconds() / 86400
        if days > 60: score -= 25
        elif days > 30: score -= 15

    score = max(0.0, min(100.0, score))

    # Persist to Organization.engagement_score if applicable
    if organization_id:
        org = session.query(Organization).filter_by(id=organization_id).first()
        if org:
            org.engagement_score = round(score, 1)
            session.commit()

    return score


def get_adjusted_caps(score: float, base_day: int = 2, base_week: int = 5) -> dict:
    """Return adjusted max_per_day / max_per_week based on engagement score.

    High engagement  (≥80): full cadence
    Normal           (≥50): full cadence
    Low              (≥25): 60 % of base caps
    Very low         (<25):  30 % of base caps
    """
    if score >= 50:
        multiplier = 1.0
    elif score >= 25:
        multiplier = 0.6
    else:
        multiplier = 0.3

    return {
        'max_per_day':  max(1, int(base_day  * multiplier)),
        'max_per_week': max(1, int(base_week * multiplier)),
    }
