"""
Seed email sequence data — mirrors minimoes email architecture.
Same 7 pools, 7 sequences, 18 total steps.
Run once: python -m src.scheduler.seedData
"""
from src.storage.database import SessionLocal, engine, Base
from src.storage.models import SequencePool, SequenceDefinition


def seed_email_automation():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        # Clear existing
        db.query(SequenceDefinition).delete()
        db.query(SequencePool).delete()
        db.commit()

        pools = [
            SequencePool(pool_id='prospect_nurture_pool', name='Prospect Nurture — Drive First Account',
                         strategy='chronological', target_lifecycle_stages=['quiz_lead'],
                         cooldown_days=0, loop_when_exhausted=False, fallback_pool_id='activation_pool', is_active=True),
            SequencePool(pool_id='activation_pool', name='Trial Activation',
                         strategy='chronological', target_lifecycle_stages=['trial_day0', 'trial_active'],
                         cooldown_days=0, loop_when_exhausted=False, fallback_pool_id='paying_pool', is_active=True),
            SequencePool(pool_id='trial_ending_pool', name='Trial Ending Urgency',
                         strategy='chronological', target_lifecycle_stages=['trial_ending'],
                         cooldown_days=0, loop_when_exhausted=False, fallback_pool_id='trial_expired_pool', is_active=True),
            SequencePool(pool_id='trial_expired_pool', name='Trial Expired Winback',
                         strategy='chronological', target_lifecycle_stages=['trial_expired'],
                         cooldown_days=0, loop_when_exhausted=False, fallback_pool_id=None, is_active=True),
            SequencePool(pool_id='paying_pool', name='Paying Customer Onboarding',
                         strategy='chronological', target_lifecycle_stages=['paying'],
                         cooldown_days=0, loop_when_exhausted=False, fallback_pool_id=None, is_active=True),
            SequencePool(pool_id='churned_pool', name='Churn Winback',
                         strategy='chronological', target_lifecycle_stages=['churned'],
                         cooldown_days=0, loop_when_exhausted=False, fallback_pool_id=None, is_active=True),
            # 7. AT_RISK RE-ENGAGEMENT — paying orgs with low activity
            SequencePool(pool_id='at_risk_pool', name='At-Risk Re-engagement',
                         strategy='chronological', target_lifecycle_stages=['at_risk'],
                         cooldown_days=0, loop_when_exhausted=False, fallback_pool_id='churned_pool', is_active=True),
        ]
        db.add_all(pools)

        sequences = [
            # 1. PROSPECT NURTURE (4 emails — quiz_lead)
            SequenceDefinition(
                sequence_id='prospect_nurture_v1', name='Prospect Nurture — 4 Steps',
                pool_id='prospect_nurture_pool', target_lifecycle_stages=['quiz_lead'], priority=100,
                steps=[
                    {'step_index': 0, 'email_type': 'quiz_diagnostic',  'delay_days': 0, 'delay_hours': 0},
                    {'step_index': 1, 'email_type': 'quiz_marie',        'delay_days': 2, 'delay_hours': 0},
                    {'step_index': 2, 'email_type': 'quiz_integration',  'delay_days': 4, 'delay_hours': 0},
                    {'step_index': 3, 'email_type': 'quiz_breakup',      'delay_days': 7, 'delay_hours': 0},
                ],
                on_complete_action='next_in_pool', is_active=True
            ),
            # 2. ACTIVATION (4 emails — trial_welcome + trial_active)
            SequenceDefinition(
                sequence_id='activation_v1', name='Trial Activation — 4 Steps',
                pool_id='activation_pool', target_lifecycle_stages=['trial_day0', 'trial_active'], priority=100,
                steps=[
                    {'step_index': 0, 'email_type': 'trial_welcome',    'delay_days': 0, 'delay_hours': 0},
                    {'step_index': 1, 'email_type': 'trial_tip_1',      'delay_days': 1, 'delay_hours': 0},
                    {'step_index': 2, 'email_type': 'trial_tip_2',      'delay_days': 3, 'delay_hours': 0},
                    {'step_index': 3, 'email_type': 'trial_offer_help', 'delay_days': 5, 'delay_hours': 0},
                ],
                on_complete_action='exit', is_active=True
            ),
            # 3. TRIAL ENDING (2 emails)
            SequenceDefinition(
                sequence_id='trial_ending_v1', name='Trial Ending Urgency — 2 Steps',
                pool_id='trial_ending_pool', target_lifecycle_stages=['trial_ending'], priority=100,
                steps=[
                    {'step_index': 0, 'email_type': 'trial_urgency',     'delay_days': 0, 'delay_hours': 0},
                    {'step_index': 1, 'email_type': 'trial_last_chance', 'delay_days': 1, 'delay_hours': 0},
                ],
                on_complete_action='exit', is_active=True
            ),
            # 4. TRIAL EXPIRED (3 emails)
            SequenceDefinition(
                sequence_id='trial_expired_v1', name='Trial Expired — 3 Steps',
                pool_id='trial_expired_pool', target_lifecycle_stages=['trial_expired'], priority=100,
                steps=[
                    {'step_index': 0, 'email_type': 'expired_access_suspended', 'delay_days': 0,  'delay_hours': 0},
                    {'step_index': 1, 'email_type': 'expired_special_offer',    'delay_days': 7,  'delay_hours': 0},
                    {'step_index': 2, 'email_type': 'expired_final',            'delay_days': 23, 'delay_hours': 0},
                ],
                on_complete_action='exit', is_active=True
            ),
            # 5. PAYING ONBOARDING (3 emails)
            SequenceDefinition(
                sequence_id='paying_onboarding_v1', name='Paying Onboarding — 3 Steps',
                pool_id='paying_pool', target_lifecycle_stages=['paying'], priority=100,
                steps=[
                    {'step_index': 0, 'email_type': 'paying_confirmation', 'delay_days': 0,  'delay_hours': 0},
                    {'step_index': 1, 'email_type': 'paying_onboarding',   'delay_days': 3,  'delay_hours': 0},
                    {'step_index': 2, 'email_type': 'paying_review',       'delay_days': 30, 'delay_hours': 0},
                ],
                on_complete_action='cooldown_then_loop', on_complete_cooldown_days=45, is_active=True
            ),
            # 6. AT_RISK RE-ENGAGEMENT (2 emails)
            SequenceDefinition(
                sequence_id='at_risk_reengagement_v1', name='At-Risk Re-engagement — 2 Steps',
                pool_id='at_risk_pool', target_lifecycle_stages=['at_risk'], priority=100,
                steps=[
                    {'step_index': 0, 'email_type': 'low_engagement_re_spark',        'delay_days': 0, 'delay_hours': 0},
                    {'step_index': 1, 'email_type': 'paying_low_engagement_check_in', 'delay_days': 7, 'delay_hours': 0},
                ],
                on_complete_action='next_in_pool', is_active=True
            ),
            # 7. CHURN WINBACK (3 emails)
            SequenceDefinition(
                sequence_id='churn_winback_v1', name='Churn Winback — 3 Steps',
                pool_id='churned_pool', target_lifecycle_stages=['churned'], priority=100,
                steps=[
                    {'step_index': 0, 'email_type': 'churned_confirmation', 'delay_days': 0,  'delay_hours': 0},
                    {'step_index': 1, 'email_type': 'churned_feedback',     'delay_days': 3,  'delay_hours': 0},
                    {'step_index': 2, 'email_type': 'churned_winback',      'delay_days': 14, 'delay_hours': 0},
                ],
                on_complete_action='cooldown_then_loop', on_complete_cooldown_days=90, is_active=True
            ),
        ]
        db.add_all(sequences)
        db.commit()

        total_steps = sum(len(s.steps) for s in sequences)
        print(f"[Seed] Done! {len(pools)} pools | {len(sequences)} sequences | {total_steps} total steps")
    except Exception as e:
        db.rollback()
        print(f"[Seed] Error: {e}")
        raise
    finally:
        db.close()


if __name__ == '__main__':
    seed_email_automation()
