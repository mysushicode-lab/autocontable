"""GetResponse email marketing automation integration"""
import requests
import logging
from typing import List, Dict, Optional
from datetime import datetime

logger = logging.getLogger(__name__)


class GetResponseClient:
    """Client for GetResponse API v3 with campaign management and automation"""

    def __init__(self, api_key: str):
        """
        Initialize GetResponse client

        Args:
            api_key: API key from https://app.getresponse.com/api
        """
        self.api_key = api_key
        self.base_url = "https://api.getresponse.com/v3"
        self.headers = {
            "X-Auth-Token": f"api-key {api_key}",
            "Content-Type": "application/json"
        }

    def _request(self, method: str, endpoint: str, **kwargs) -> Dict:
        """Make HTTP request to GetResponse API"""
        url = f"{self.base_url}{endpoint}"
        try:
            resp = requests.request(method, url, headers=self.headers, timeout=10, **kwargs)
            resp.raise_for_status()
            return resp.json() if resp.text else {}
        except requests.exceptions.RequestException as e:
            logger.error(f"GetResponse API error: {e}")
            raise

    def get_campaigns(self) -> List[Dict]:
        """Get all campaigns"""
        result = self._request("GET", "/campaigns?limit=100")
        return result if isinstance(result, list) else result.get('campaigns', [])

    def get_default_campaign_id(self) -> str:
        """Get first campaign ID (usually default)"""
        campaigns = self.get_campaigns()
        if campaigns:
            return campaigns[0].get('campaignId')
        raise ValueError("No campaigns found in GetResponse account")

    def add_contact(
        self,
        email: str,
        name: str = "",
        campaign_id: Optional[str] = None,
        tags: List[str] = None,
        custom_fields: Dict = None
    ) -> Dict:
        """
        Add contact to GetResponse

        Args:
            email: Contact email
            name: Contact name
            campaign_id: Campaign ID (uses default if not provided)
            tags: List of tag names to assign
            custom_fields: Dict of custom field values
        """
        if not campaign_id:
            campaign_id = self.get_default_campaign_id()

        payload = {
            "email": email,
            "name": name,
            "campaign": {"campaignId": campaign_id}
        }

        if tags:
            payload["tags"] = [{"name": tag} for tag in tags]

        if custom_fields:
            payload["customFieldValues"] = [
                {"customFieldId": k, "value": [v]}
                for k, v in custom_fields.items()
            ]

        result = self._request("POST", "/contacts", json=payload)
        logger.info(f"Added contact {email} to GetResponse")
        return result

    def update_contact(
        self,
        contact_id: str,
        name: Optional[str] = None,
        tags: List[str] = None,
        custom_fields: Dict = None
    ) -> Dict:
        """
        Update contact in GetResponse

        Args:
            contact_id: GetResponse contact ID
            name: Update contact name
            tags: Replace tags
            custom_fields: Update custom field values
        """
        payload = {}

        if name:
            payload["name"] = name

        if tags:
            payload["tags"] = [{"name": tag} for tag in tags]

        if custom_fields:
            payload["customFieldValues"] = [
                {"customFieldId": k, "value": [v]}
                for k, v in custom_fields.items()
            ]

        if not payload:
            return {"message": "No updates provided"}

        result = self._request("PATCH", f"/contacts/{contact_id}", json=payload)
        logger.info(f"Updated contact {contact_id} in GetResponse")
        return result

    def get_contact_by_email(self, email: str) -> Optional[Dict]:
        """Find contact by email"""
        result = self._request("GET", f"/contacts?query[email]={email}&limit=1")
        contacts = result if isinstance(result, list) else result.get('contacts', [])
        return contacts[0] if contacts else None

    def create_tag(self, name: str) -> Dict:
        """Create a new tag"""
        payload = {"name": name}
        result = self._request("POST", "/tags", json=payload)
        logger.info(f"Created tag {name}")
        return result

    def get_tags(self) -> List[Dict]:
        """Get all tags"""
        result = self._request("GET", "/tags?limit=100")
        return result if isinstance(result, list) else result.get('tags', [])

    def create_custom_field(self, name: str, field_type: str = "text") -> Dict:
        """
        Create custom field

        Args:
            name: Field name
            field_type: 'text', 'number', 'date', etc.
        """
        payload = {
            "name": name,
            "type": field_type
        }
        result = self._request("POST", "/custom-fields", json=payload)
        logger.info(f"Created custom field {name}")
        return result

    def get_custom_fields(self) -> List[Dict]:
        """Get all custom fields"""
        result = self._request("GET", "/custom-fields?limit=100")
        return result if isinstance(result, list) else result.get('customFields', [])

    def create_automation(
        self,
        name: str,
        campaign_id: Optional[str] = None,
        trigger_type: str = "contact_added"
    ) -> Dict:
        """
        Create automation/workflow

        Args:
            name: Automation name
            campaign_id: Campaign to attach to
            trigger_type: 'contact_added', 'tag_added', 'custom_event'
        """
        if not campaign_id:
            campaign_id = self.get_default_campaign_id()

        payload = {
            "name": name,
            "campaign": {"campaignId": campaign_id},
            "trigger": {"type": trigger_type}
        }

        result = self._request("POST", "/automations", json=payload)
        logger.info(f"Created automation {name}")
        return result

    def get_automations(self, campaign_id: Optional[str] = None) -> List[Dict]:
        """Get automations, optionally filtered by campaign"""
        query = ""
        if campaign_id:
            query = f"?query[campaign]={campaign_id}"

        result = self._request("GET", f"/automations{query}&limit=100")
        return result if isinstance(result, list) else result.get('automations', [])


class GetResponseSegmentation:
    """Helper for intelligent contact segmentation"""

    def __init__(self, client: GetResponseClient):
        self.client = client

    def ensure_tags_exist(self, tag_names: List[str]) -> None:
        """Create tags if they don't exist"""
        existing_tags = {t['name'] for t in self.client.get_tags()}

        for tag_name in tag_names:
            if tag_name not in existing_tags:
                self.client.create_tag(tag_name)
                logger.info(f"Created missing tag: {tag_name}")

    def get_user_tags(
        self,
        oauth_provider: Optional[str] = None,
        plan_type: str = "free",
        lifecycle_stage: str = "new"
    ) -> List[str]:
        """
        Generate tags for a user based on attributes

        Args:
            oauth_provider: 'google', 'linkedin', or None for manual signup
            plan_type: 'free', 'pro', 'cabinet', 'reseau'
            lifecycle_stage: 'new', 'onboarding', 'trial_active', 'paying', 'churned'
        """
        tags = []

        # Source tags
        if oauth_provider == "google":
            tags.append("signup_google")
        elif oauth_provider == "linkedin":
            tags.append("signup_linkedin")
        else:
            tags.append("signup_manual")

        # Plan tags
        tags.append(f"plan_{plan_type}")

        # Lifecycle tags
        tags.append(f"lifecycle_{lifecycle_stage}")

        return tags

    def add_user_contact(
        self,
        email: str,
        name: str = "",
        oauth_provider: Optional[str] = None,
        plan_type: str = "free",
        campaign_id: Optional[str] = None
    ) -> Dict:
        """
        Add user contact with intelligent segmentation

        Args:
            email: User email
            name: User name
            oauth_provider: 'google', 'linkedin', or None
            plan_type: Current plan
            campaign_id: Campaign ID (uses default if not provided)
        """
        tags = self.get_user_tags(oauth_provider, plan_type, "new")
        self.ensure_tags_exist(tags)

        return self.client.add_contact(
            email=email,
            name=name,
            campaign_id=campaign_id,
            tags=tags
        )

    def update_user_plan(self, email: str, new_plan: str) -> Dict:
        """Update user contact when plan changes"""
        contact = self.client.get_contact_by_email(email)
        if not contact:
            logger.warning(f"Contact {email} not found for plan update")
            return {}

        contact_id = contact['contactId']
        tags = self.get_user_tags(
            oauth_provider=None,
            plan_type=new_plan,
            lifecycle_stage="paying" if new_plan != "free" else "trial_active"
        )
        self.ensure_tags_exist(tags)

        return self.client.update_contact(contact_id, tags=tags)

    def update_user_lifecycle(self, email: str, stage: str) -> Dict:
        """Update contact lifecycle stage"""
        contact = self.client.get_contact_by_email(email)
        if not contact:
            logger.warning(f"Contact {email} not found for lifecycle update")
            return {}

        contact_id = contact['contactId']
        existing_tags = [t.get('name', '') for t in contact.get('tags', [])]

        # Remove old lifecycle tags
        new_tags = [
            t for t in existing_tags
            if not t.startswith('lifecycle_')
        ]

        # Add new lifecycle tag
        new_tags.append(f"lifecycle_{stage}")

        return self.client.update_contact(contact_id, tags=new_tags)
