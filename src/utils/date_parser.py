"""
Shared date parsing utility for handling various date formats.
"""
from datetime import datetime
from typing import Optional


def parse_date(value: str) -> Optional[datetime]:
    """
    Parse date string into datetime object.

    Handles multiple common formats:
    - DD/MM/YYYY
    - DD/MM/YY
    - DD-MM-YYYY
    - YYYY-MM-DD
    - DD.MM.YYYY

    Args:
        value: Date string to parse

    Returns:
        datetime object or None if parsing fails
    """
    if not value:
        return None

    formats = ('%d/%m/%Y', '%d/%m/%y', '%d-%m-%Y', '%Y-%m-%d', '%d.%m.%Y')
    for fmt in formats:
        try:
            return datetime.strptime(value.strip(), fmt)
        except ValueError:
            continue

    return None
