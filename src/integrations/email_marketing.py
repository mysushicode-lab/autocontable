"""Email marketing integration (deprecated - now using SendGrid via lifecycle engine)"""
import logging
from typing import List, Dict, Optional

logger = logging.getLogger(__name__)


class EmailMarketingClient:
    """Deprecated - kept for interface compatibility. All email is handled by SendGrid."""

    def __init__(self, api_key: str = ""):
        self.api_key = api_key

    def _request(self, method: str, endpoint: str, **kwargs) -> Dict:
        logger.debug(f"[DEPRECATED] EmailMarketingClient call skipped: {method} {endpoint}")
        return {}

    def get_campaigns(self) -> List[Dict]:
        return []

    def get_default_campaign_id(self) -> str:
        return ""

    def add_contact(self, email: str, name: str = "", campaign_id: Optional[str] = None, tags: List[str] = None, custom_fields: Dict = None) -> Dict:
        logger.debug(f"[DEPRECATED] add_contact skipped for {email}")
        return {}

    def update_contact(self, contact_id: str, name: Optional[str] = None, tags: List[str] = None, custom_fields: Dict = None) -> Dict:
        logger.debug(f"[DEPRECATED] update_contact skipped for {contact_id}")
        return {}

    def get_contact_by_email(self, email: str) -> Optional[Dict]:
        return None

    def create_tag(self, name: str) -> Dict:
        return {}

    def get_tags(self) -> List[Dict]:
        return []

    def create_custom_field(self, name: str, field_type: str = "text") -> Dict:
        return {}

    def get_custom_fields(self) -> List[Dict]:
        return []

    def create_automation(self, name: str, campaign_id: Optional[str] = None, trigger_type: str = "contact_added") -> Dict:
        return {}

    def get_automations(self, campaign_id: Optional[str] = None) -> List[Dict]:
        return []


class EmailSegmentation:
    """Deprecated - segmentation is now handled by lifecycle_engine + SendGrid."""

    def __init__(self, client: EmailMarketingClient):
        self.client = client

    def ensure_tags_exist(self, tag_names: List[str]) -> None:
        pass

    def get_user_tags(self, oauth_provider: Optional[str] = None, plan_type: str = "free", lifecycle_stage: str = "new") -> List[str]:
        tags = []
        if oauth_provider == "google":
            tags.append("signup_google")
        elif oauth_provider == "linkedin":
            tags.append("signup_linkedin")
        else:
            tags.append("signup_manual")
        tags.append(f"plan_{plan_type}")
        tags.append(f"lifecycle_{lifecycle_stage}")
        return tags

    def add_user_contact(self, email: str, name: str = "", oauth_provider: Optional[str] = None, plan_type: str = "free", campaign_id: Optional[str] = None) -> Dict:
        logger.debug(f"[DEPRECATED] add_user_contact skipped for {email}")
        return {}

    def update_user_plan(self, email: str, new_plan: str) -> Dict:
        logger.debug(f"[DEPRECATED] update_user_plan skipped for {email}")
        return {}

    def update_user_lifecycle(self, email: str, stage: str) -> Dict:
        logger.debug(f"[DEPRECATED] update_user_lifecycle skipped for {email}")
        return {}
