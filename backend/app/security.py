"""Password hashing (bcrypt direct, no passlib) + JWT auth dependencies."""
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from .config import settings
from .db import get_db

bearer = HTTPBearer(auto_error=False)


def hash_password(password: str) -> str:
    rounds = max(10, settings.bcrypt_rounds)  # spec: cost >= 10
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt(rounds=rounds)).decode()


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode("utf-8"), password_hash.encode("utf-8"))
    except ValueError:
        # daot/placeholder hash -> dili valid login
        return False


def create_access_token(user_id: int, role: str) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user_id),
        "role": role,
        "iat": now,
        "exp": now + timedelta(minutes=settings.jwt_expire_minutes),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def unauthorized(detail: str = "Invalid or missing token") -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=detail,
        headers={"WWW-Authenticate": "Bearer"},
    )


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    conn=Depends(get_db),
) -> dict:
    if credentials is None:
        raise unauthorized("Login first")
    try:
        payload = jwt.decode(
            credentials.credentials,
            settings.jwt_secret,
            algorithms=[settings.jwt_algorithm],
        )
        user_id = int(payload["sub"])
    except (jwt.PyJWTError, KeyError, ValueError):
        raise unauthorized()

    user = conn.execute(
        "SELECT id, email, full_name, role, is_active FROM users WHERE id = %s",
        (user_id,),
    ).fetchone()
    if user is None or not user["is_active"]:
        raise unauthorized("Account not found or inactive")
    return user


def require_roles(*roles: str):
    """Dependency factory: role check sa server, dili lang sa UI."""

    def checker(user: dict = Depends(get_current_user)) -> dict:
        if user["role"] not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Requires role: {', '.join(roles)}",
            )
        return user

    return checker
