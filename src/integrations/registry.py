"""Integration registry — maps integration names to their implementations."""
from typing import Dict, Optional, List
from .base import BaseIntegration


_REGISTRY: Dict[str, type] = {}


def register(cls):
    """Decorator to register an integration class."""
    _REGISTRY[cls.name] = cls
    return cls


def get_integration(name: str, config: dict) -> Optional[BaseIntegration]:
    """Get an integration instance by name with the given config."""
    cls = _REGISTRY.get(name)
    if cls is None:
        return None
    return cls(config)


def list_integrations() -> List[dict]:
    """List all available integrations with their metadata."""
    return [
        {
            "name": cls.name,
            "display_name": cls.display_name,
            "description": cls.description,
            "supports_api": cls.supports_api,
            "config_fields": cls.config_fields,
        }
        for cls in _REGISTRY.values()
    ]
