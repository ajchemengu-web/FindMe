import pytest

from app.services.phone import normalize_kenyan_msisdn, normalize_phone


def test_normalize_phone_strips_formatting_chars():
    assert normalize_phone("+1 (555) 010-1234") == normalize_phone("+15550101234")
    assert normalize_phone("+15550101234") == "+15550101234"


@pytest.mark.parametrize(
    "raw,expected",
    [
        ("0712345678", "254712345678"),
        ("+254712345678", "254712345678"),
        ("254712345678", "254712345678"),
        ("712345678", "254712345678"),
        ("0112345678", "254112345678"),
        ("not-a-phone", None),
        ("12345", None),
    ],
)
def test_normalize_kenyan_msisdn(raw: str, expected: str | None):
    assert normalize_kenyan_msisdn(raw) == expected
