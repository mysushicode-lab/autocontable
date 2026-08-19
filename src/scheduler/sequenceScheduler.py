"""
Sequence scheduler — mirrors minimoes sequenceScheduler.ts
6 phases: reset_frequency_caps, lifecycle_transitions, assign_sequences, process_sequences
"""
from datetime import datetime, timedelta
from src.storage.database import SessionLocal
from src.storage.models import Organization, QuizContact, SequencePool, SequenceDefinition, CompletedSequence

MAX_PER_DAY = 2
MAX_PER_WEEK = 5


def run_sequence_scheduler():
    """Main entry point — run all phases."""
    db = SessionLocal()
    try:
        stats = {
            'resets': 0,
            'transitions': 0,
            'assigned': 0,
            'sent': 0,
            'skipped': 0,
            'errors': 0,
        }

        _phase_reset_frequency_caps(db, stats)
        _phase_lifecycle_transitions(db, stats)
        _phase_assign_sequences(db, stats)
        _phase_process_sequences(db, stats)

        db.commit()
        print(f"[Scheduler] {stats}")
        return stats
    except Exception as e:
        db.rollback()
        print(f"[Scheduler] Fatal error: {e}")
        raise
    finally:
        db.close()


def _phase_reset_frequency_caps(db, stats):
    """Phase 1: Reset daily/weekly email counters."""
    now = datetime.utcnow()
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    monday = now - timedelta(days=now.weekday())
    monday_start = monday.replace(hour=0, minute=0, second=0, microsecond=0)

    for Model in [Organization, QuizContact]:
        # Daily reset
        records = db.query(Model).filter(
            (Model.last_freq_reset_daily == None) |
            (Model.last_freq_reset_daily < today_start)
        ).all()
        for r in records:
            r.emails_sent_today = 0
            r.last_freq_reset_daily = now
            stats['resets'] += 1

        # Weekly reset
        records_w = db.query(Model).filter(
            (Model.last_freq_reset_weekly == None) |
            (Model.last_freq_reset_weekly < monday_start)
        ).all()
        for r in records_w:
            r.emails_sent_this_week = 0
            r.last_freq_reset_weekly = now


def _phase_lifecycle_transitions(db, stats):
    """Phase 2: Automatic time-based lifecycle transitions."""
    now = datetime.utcnow()

    # Trial ending: org with trial active, ends in <= 2 days
    ending = db.query(Organization).filter(
        Organization.is_trial_active == True,
        Organization.trial_end_date != None,
        Organization.trial_end_date <= now + timedelta(days=2),
        Organization.trial_end_date > now,
        Organization.lifecycle_stage != 'trial_ending',
    ).all()
    for org in ending:
        _transition_org(db, org, 'trial_ending')
        stats['transitions'] += 1

    # Trial expired
    expired = db.query(Organization).filter(
        Organization.is_trial_active == True,
        Organization.trial_end_date != None,
        Organization.trial_end_date <= now,
        Organization.lifecycle_stage.notin_(['trial_expired', 'paying', 'churned']),
    ).all()
    for org in expired:
        _transition_org(db, org, 'trial_expired')
        stats['transitions'] += 1


def _transition_org(db, org, new_stage):
    """Transition an org to a new lifecycle stage, clearing current sequence."""
    org.lifecycle_stage = new_stage
    org.current_sequence_id = None
    org.current_step_index = 0
    org.sequence_entered_at = None


def _phase_assign_sequences(db, stats):
    """Phase 3: Assign sequences to orgs/contacts with no current sequence."""
    now = datetime.utcnow()

    # Organizations
    orgs = db.query(Organization).filter(
        Organization.lifecycle_stage != None,
        Organization.current_sequence_id == None,
        (Organization.sequence_cooldown_until == None) | (Organization.sequence_cooldown_until <= now),
    ).all()
    for org in orgs:
        seq = _pick_sequence(db, org.lifecycle_stage, org.id, 'organization')
        if seq:
            org.current_sequence_id = seq.sequence_id
            org.current_step_index = 0
            org.sequence_entered_at = now
            stats['assigned'] += 1

    # QuizContacts
    contacts = db.query(QuizContact).filter(
        QuizContact.lifecycle_stage != None,
        QuizContact.current_sequence_id == None,
        (QuizContact.sequence_cooldown_until == None) | (QuizContact.sequence_cooldown_until <= now),
    ).all()
    for contact in contacts:
        stage_val = contact.lifecycle_stage.value if hasattr(contact.lifecycle_stage, 'value') else str(contact.lifecycle_stage)
        seq = _pick_sequence(db, stage_val, contact.id, 'quiz_contact')
        if seq:
            contact.current_sequence_id = seq.sequence_id
            contact.current_step_index = 0
            contact.sequence_entered_at = now
            stats['assigned'] += 1


def _pick_sequence(db, lifecycle_stage, entity_id, entity_type):
    """Find the best sequence for a given lifecycle stage."""
    # JSON contains() is not universal; filter in Python for compatibility
    pools = db.query(SequencePool).filter(
        SequencePool.is_active == True,
    ).all()
    pool = None
    for p in pools:
        stages = p.target_lifecycle_stages or []
        if lifecycle_stage in stages:
            pool = p
            break
    if not pool:
        return None

    # Get completed sequences for this entity
    if entity_type == 'organization':
        completed_filter = CompletedSequence.organization_id == entity_id
    else:
        completed_filter = CompletedSequence.quiz_contact_id == entity_id
    completed_ids = {c.sequence_id for c in db.query(CompletedSequence).filter(completed_filter).all()}

    sequences = db.query(SequenceDefinition).filter(
        SequenceDefinition.pool_id == pool.pool_id,
        SequenceDefinition.is_active == True,
    ).order_by(SequenceDefinition.priority.desc()).all()

    for seq in sequences:
        if seq.sequence_id not in completed_ids:
            return seq
        if pool.loop_when_exhausted:
            return seq  # loop: re-use even if completed

    # Try fallback pool
    if pool.fallback_pool_id:
        fallback = db.query(SequencePool).filter(
            SequencePool.pool_id == pool.fallback_pool_id,
            SequencePool.is_active == True,
        ).first()
        if fallback:
            return db.query(SequenceDefinition).filter(
                SequenceDefinition.pool_id == fallback.pool_id,
                SequenceDefinition.is_active == True,
            ).order_by(SequenceDefinition.priority.desc()).first()

    return None


def _phase_process_sequences(db, stats):
    """Phase 4: Send due emails and advance step indexes."""
    now = datetime.utcnow()

    # Process organizations
    orgs = db.query(Organization).filter(
        Organization.current_sequence_id != None,
    ).all()
    for org in orgs:
        _process_entity_sequence(db, org, 'organization', stats, now)

    # Process quiz contacts
    contacts = db.query(QuizContact).filter(
        QuizContact.current_sequence_id != None,
    ).all()
    for contact in contacts:
        _process_entity_sequence(db, contact, 'quiz_contact', stats, now)


def _process_entity_sequence(db, entity, entity_type, stats, now):
    """Process one step for a single entity."""
    seq = db.query(SequenceDefinition).filter(
        SequenceDefinition.sequence_id == entity.current_sequence_id,
        SequenceDefinition.is_active == True,
    ).first()
    if not seq:
        entity.current_sequence_id = None
        return

    steps = seq.steps or []
    step_index = entity.current_step_index or 0

    if step_index >= len(steps):
        # Sequence complete
        _handle_completion(db, entity, entity_type, seq, now)
        stats['skipped'] += 1
        return

    step = steps[step_index]
    delay_seconds = step.get('delay_days', 0) * 86400 + step.get('delay_hours', 0) * 3600
    reference_time = entity.last_email_sent_at or entity.sequence_entered_at or now
    due_at = reference_time + timedelta(seconds=delay_seconds)

    if due_at > now:
        stats['skipped'] += 1
        return

    # Frequency cap
    if not _can_send(entity):
        stats['skipped'] += 1
        return

    # Resolve send info
    info = _get_info(entity, entity_type)
    if not info.get('email'):
        stats['skipped'] += 1
        return

    try:
        from src.scheduler.email_sender import send_lifecycle_email
        ok = send_lifecycle_email(info['email'], info.get('first_name', 'there'), step['email_type'], info)
        if ok:
            entity.current_step_index = step_index + 1
            entity.last_email_sent_at = now
            entity.emails_sent_today = (entity.emails_sent_today or 0) + 1
            entity.emails_sent_this_week = (entity.emails_sent_this_week or 0) + 1
            if entity_type == 'organization':
                entity.total_emails_sent = (entity.total_emails_sent or 0) + 1
            stats['sent'] += 1
        else:
            stats['errors'] += 1
    except Exception as e:
        print(f"[Scheduler] Error sending to {entity_type} {entity.id}: {e}")
        stats['errors'] += 1


def _can_send(entity):
    """Check frequency cap."""
    if (entity.emails_sent_today or 0) >= MAX_PER_DAY:
        return False
    if (entity.emails_sent_this_week or 0) >= MAX_PER_WEEK:
        return False
    return True


def _get_info(entity, entity_type):
    """Extract send info from entity."""
    if entity_type == 'organization':
        trial_days_left = 0
        if entity.trial_end_date:
            delta = (entity.trial_end_date - datetime.utcnow()).days
            trial_days_left = max(0, delta)
        return {
            'email': getattr(entity, 'contact_email', None) or getattr(entity, 'email', None),
            'first_name': entity.name or 'there',
            'plan_name': (entity.plan_type or 'starter').capitalize(),
            'days_left': trial_days_left,
            'invoices_count': entity.invoices_processed_this_month or 0,
        }
    else:
        return {
            'email': entity.email,
            'first_name': entity.first_name or 'there',
            'client_count': entity.client_count or 0,
            'time_lost_week': entity.time_lost_week or 0,
            'time_lost_year': entity.time_lost_year or 0,
            'annual_loss': int((entity.time_lost_year or 0) * 50),
        }


def _handle_completion(db, entity, entity_type, seq, now):
    """Handle sequence completion — record + apply onComplete action."""
    kwargs = {'sequence_id': seq.sequence_id, 'pool_id': seq.pool_id}
    if entity_type == 'organization':
        kwargs['organization_id'] = entity.id
    else:
        kwargs['quiz_contact_id'] = entity.id
    db.add(CompletedSequence(**kwargs))

    entity.current_sequence_id = None
    entity.current_step_index = 0

    action = seq.on_complete_action or 'exit'
    if action == 'cooldown_then_loop':
        days = seq.on_complete_cooldown_days or 90
        entity.sequence_cooldown_until = now + timedelta(days=days)
