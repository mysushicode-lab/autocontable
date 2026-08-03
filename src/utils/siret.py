"""SIRET/SIREN validation utilities for French business identification."""


def validate_siret(siret: str) -> dict:
    """Validate a SIRET number (14 digits) using the Luhn algorithm.

    Returns:
        dict with keys: valid (bool), siren (str|None), nic (str|None), error (str|None)
    """
    if not siret:
        return {"valid": False, "siren": None, "nic": None, "error": "SIRET requis"}

    # Remove spaces and dashes
    cleaned = siret.replace(" ", "").replace("-", "")

    if not cleaned.isdigit():
        return {"valid": False, "siren": None, "nic": None, "error": "Le SIRET ne doit contenir que des chiffres"}

    if len(cleaned) != 14:
        return {"valid": False, "siren": None, "nic": None, "error": f"Le SIRET doit contenir 14 chiffres (reçu: {len(cleaned)})"}

    # Luhn algorithm check
    siren = cleaned[:9]
    nic = cleaned[9:]

    # Standard Luhn algorithm (double odd positions, 1-indexed)
    total = 0
    for i, digit in enumerate(cleaned):
        n = int(digit)
        if i % 2 == 0:  # Odd position (1-indexed), even index (0-indexed)
            n *= 2
            if n > 9:
                n -= 9
        total += n

    if total % 10 != 0:
        return {"valid": False, "siren": siren, "nic": nic, "error": "Clé de contrôle SIRET invalide (algorithme de Luhn)"}

    return {"valid": True, "siren": siren, "nic": nic, "error": None}


def validate_siren(siren: str) -> dict:
    """Validate a SIREN number (9 digits) - format check only.

    Note: The full Luhn validation is done at the SIRET level.
    SIREN validation here only checks format.
    """
    if not siren:
        return {"valid": False, "error": "SIREN requis"}

    cleaned = siren.replace(" ", "").replace("-", "")

    if not cleaned.isdigit():
        return {"valid": False, "error": "Le SIREN ne doit contenir que des chiffres"}

    if len(cleaned) != 9:
        return {"valid": False, "error": f"Le SIREN doit contenir 9 chiffres (reçu: {len(cleaned)})"}

    return {"valid": True, "error": None}


def format_siret(siret: str) -> str:
    """Format a SIRET number as XXX XXX XXX XXXXX."""
    cleaned = siret.replace(" ", "").replace("-", "")
    if len(cleaned) != 14:
        return siret
    return f"{cleaned[:3]} {cleaned[3:6]} {cleaned[6:9]} {cleaned[9:]}"
