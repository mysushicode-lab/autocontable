"""Tests for SIRET validation utilities."""
import pytest
from src.utils.siret import validate_siret, validate_siren, format_siret


def test_validate_siret_valid():
    """Test valid SIRET numbers."""
    # Valid SIRET: 73282932000074 (Apple France)
    result = validate_siret("73282932000074")
    assert result["valid"] is True
    assert result["siren"] == "732829320"
    assert result["nic"] == "00074"
    assert result["error"] is None


def test_validate_siret_with_spaces():
    """Test SIRET with spaces."""
    result = validate_siret("732 829 320 00074")
    assert result["valid"] is True
    assert result["siren"] == "732829320"


def test_validate_siret_invalid_length():
    """Test SIRET with wrong length."""
    result = validate_siret("12345")
    assert result["valid"] is False
    assert "14 chiffres" in result["error"]


def test_validate_siret_non_numeric():
    """Test SIRET with non-numeric characters."""
    result = validate_siret("7328293200007A")
    assert result["valid"] is False
    assert "chiffres" in result["error"]


def test_validate_siret_invalid_checksum():
    """Test SIRET with invalid checksum."""
    result = validate_siret("73282932000075")
    assert result["valid"] is False
    assert "Clé de contrôle" in result["error"]


def test_validate_siret_empty():
    """Test empty SIRET."""
    result = validate_siret("")
    assert result["valid"] is False
    assert "requis" in result["error"]


def test_validate_siren_valid():
    """Test valid SIREN format."""
    result = validate_siren("732829320")
    assert result["valid"] is True
    assert result["error"] is None


def test_validate_siren_invalid_length():
    """Test invalid SIREN length."""
    result = validate_siren("12345")
    assert result["valid"] is False
    assert "9 chiffres" in result["error"]


def test_format_siret():
    """Test SIRET formatting."""
    formatted = format_siret("73282932000074")
    assert formatted == "732 829 320 00074"

    formatted = format_siret("732 829 320 00074")
    assert formatted == "732 829 320 00074"

    # Invalid length should return as-is
    formatted = format_siret("123")
    assert formatted == "123"
