import uuid

import pytest
from jose import JWTError

from app.core.security import (
    create_access_token,
    decode_access_token,
    generate_refresh_token,
    hash_password,
    hash_token,
    validate_password_strength,
    verify_password,
)


def test_password_hash_roundtrip():
    hashed = hash_password("Sup3r$ecretPass")
    assert hashed != "Sup3r$ecretPass"
    assert verify_password("Sup3r$ecretPass", hashed)
    assert not verify_password("wrong", hashed)


def test_access_token_roundtrip():
    user_id = uuid.uuid4()
    token = create_access_token(user_id)
    assert decode_access_token(token) == user_id


def test_access_token_rejects_garbage():
    with pytest.raises(JWTError):
        decode_access_token("not-a-real-token")


def test_refresh_token_hash_is_deterministic_and_not_reversible():
    raw = generate_refresh_token()
    assert len(raw) > 32
    h1 = hash_token(raw)
    h2 = hash_token(raw)
    assert h1 == h2
    assert h1 != raw


@pytest.mark.parametrize(
    "password,should_pass",
    [
        ("short1A!", False),  # too short
        ("alllowercase123", False),  # only 2 classes (lower+digit)
        ("password123", False),  # common password (also only 2 classes)
        ("Str0ng&Secure!", True),
        ("Another$trongOne9", True),
    ],
)
def test_password_strength(password: str, should_pass: bool):
    problems = validate_password_strength(password)
    assert (len(problems) == 0) == should_pass, problems
