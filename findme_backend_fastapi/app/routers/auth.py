"""
/auth -- signup, login, refresh, logout, me, phone verification. The complete
replacement for supabase.auth.{signUp,signInWithPassword,refreshSession,signOut,
getUser,updateUser,verifyOtp}.
"""
from fastapi import APIRouter, HTTPException, status

from app.core.security import validate_password_strength
from app.deps import CurrentUser, DbSession
from app.schemas.auth import (
    ChangePasswordRequest,
    ConfirmPhoneOtpRequest,
    GoogleSignInRequest,
    LoginRequest,
    ProfileLookupOut,
    RefreshRequest,
    SendPhoneOtpRequest,
    SignupRequest,
    TokenResponse,
    UpdateProfileRequest,
    UserOut,
)
from app.services import auth as auth_service
from app.services import phone_verification
from app.services.phone import normalize_phone
from sqlalchemy import func, or_, select

from app.models.user import User

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/signup", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def signup(payload: SignupRequest, db: DbSession) -> TokenResponse:
    problems = validate_password_strength(payload.password)
    if problems:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, {"password_issues": problems})

    phone = normalize_phone(payload.phone) if payload.phone else None
    try:
        user = await auth_service.signup(
            db,
            email=payload.email,
            password=payload.password,
            username=payload.username,
            phone=phone,
            display_name=payload.display_name,
            referral_code=payload.referral_code,
        )
        access, refresh = await auth_service.issue_token_pair(db, user)
        await db.commit()
    except auth_service.AuthError as exc:
        await db.rollback()
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc))

    return TokenResponse(access_token=access, refresh_token=refresh)


@router.post("/login", response_model=TokenResponse)
async def login(payload: LoginRequest, db: DbSession) -> TokenResponse:
    try:
        user = await auth_service.authenticate(db, payload.identifier, payload.password)
        access, refresh = await auth_service.issue_token_pair(db, user)
        await db.commit()
    except auth_service.AuthError as exc:
        await db.rollback()
        # Same generic message/status regardless of which part was wrong -- see
        # auth_service.authenticate()'s docstring.
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, str(exc))

    return TokenResponse(access_token=access, refresh_token=refresh)


@router.post("/google", response_model=TokenResponse)
async def google_sign_in(payload: GoogleSignInRequest, db: DbSession) -> TokenResponse:
    try:
        user = await auth_service.google_sign_in(db, payload.id_token)
        access, refresh = await auth_service.issue_token_pair(db, user)
        await db.commit()
    except auth_service.AuthError as exc:
        await db.rollback()
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, str(exc))

    return TokenResponse(access_token=access, refresh_token=refresh)


@router.post("/refresh", response_model=TokenResponse)
async def refresh(payload: RefreshRequest, db: DbSession) -> TokenResponse:
    try:
        access, refresh_token = await auth_service.rotate_refresh_token(db, payload.refresh_token)
        await db.commit()
    except auth_service.AuthError as exc:
        await db.rollback()
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, str(exc))

    return TokenResponse(access_token=access, refresh_token=refresh_token)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(payload: RefreshRequest, db: DbSession) -> None:
    await auth_service.revoke_refresh_token(db, payload.refresh_token)
    await db.commit()


@router.get("/me", response_model=UserOut)
async def me(current_user: CurrentUser) -> UserOut:
    return UserOut.model_validate(current_user)


@router.patch("/me", response_model=UserOut)
async def update_me(payload: UpdateProfileRequest, current_user: CurrentUser, db: DbSession) -> UserOut:
    try:
        await auth_service.update_profile(
            db,
            current_user,
            display_name=payload.display_name,
            avatar_url=payload.avatar_url,
            username=payload.username,
            email=payload.email,
        )
        await db.commit()
    except auth_service.AuthError as exc:
        await db.rollback()
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc))
    await db.refresh(current_user)
    return UserOut.model_validate(current_user)


@router.post("/change-password", status_code=status.HTTP_204_NO_CONTENT)
async def change_password(payload: ChangePasswordRequest, current_user: CurrentUser, db: DbSession) -> None:
    try:
        await auth_service.change_password(
            db, current_user, current_password=payload.current_password, new_password=payload.new_password
        )
        await db.commit()
    except auth_service.AuthError as exc:
        await db.rollback()
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc))


@router.post("/phone/send-otp", status_code=status.HTTP_204_NO_CONTENT)
async def send_phone_otp(payload: SendPhoneOtpRequest, current_user: CurrentUser, db: DbSession) -> None:
    phone = normalize_phone(payload.phone)
    try:
        await phone_verification.send_phone_otp(db, current_user, phone)
        await db.commit()
    except phone_verification.PhoneVerificationError as exc:
        await db.rollback()
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc))


@router.post("/phone/confirm-otp", response_model=UserOut)
async def confirm_phone_otp(
    payload: ConfirmPhoneOtpRequest, current_user: CurrentUser, db: DbSession
) -> UserOut:
    phone = normalize_phone(payload.phone)
    try:
        await phone_verification.confirm_phone_otp(db, current_user, phone, payload.code)
        await db.commit()
        await db.refresh(current_user)
    except phone_verification.PhoneVerificationError as exc:
        await db.rollback()
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc))

    return UserOut.model_validate(current_user)


@router.get("/lookup", response_model=ProfileLookupOut | None)
async def lookup_profile(contact: str, current_user: CurrentUser, db: DbSession) -> ProfileLookupOut | None:
    """Ports find_profile_for_invite() -- narrow lookup for the 'add someone' flow.
    Requires a signed-in caller (find_profile_for_invite was granted to `authenticated`
    only, unlike resolve_login_email)."""
    contact_lower = contact.strip().lower()
    user = await db.scalar(
        select(User).where(
            or_(
                func.lower(User.username) == contact_lower,
                User.phone == contact.strip(),
                func.lower(User.email) == contact_lower,
            )
        )
    )
    if user is None:
        return None
    return ProfileLookupOut(id=user.id, username=user.username, display_name=user.display_name)
