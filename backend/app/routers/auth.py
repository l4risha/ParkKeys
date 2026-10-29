"""Auth: passenger self-register, login, me. JWT + bcrypt."""
import psycopg
from fastapi import APIRouter, Depends, HTTPException, status

from ..audit import write_audit
from ..db import get_db
from ..schemas import LoginIn, RegisterIn, TokenOut, UserOut
from ..security import (
    create_access_token,
    get_current_user,
    hash_password,
    verify_password,
)

router = APIRouter(prefix="/api/auth", tags=["auth"])

USER_COLS = "id, email, full_name, role, is_active"


@router.post("/register", response_model=TokenOut, status_code=status.HTTP_201_CREATED)
def register(payload: RegisterIn, conn=Depends(get_db)):
    email = payload.email.lower().strip()
    try:
        with conn.transaction():
            user = conn.execute(
                f"""INSERT INTO users (email, password_hash, full_name, role)
                    VALUES (%s, %s, %s, 'passenger')
                    RETURNING {USER_COLS}""",
                (email, hash_password(payload.password), payload.full_name.strip()),
            ).fetchone()
            write_audit(conn, user["id"], "user_register", {"email": email, "role": "passenger"})
    except psycopg.errors.UniqueViolation:
        raise HTTPException(status_code=409, detail="Email already registered")

    token = create_access_token(user["id"], user["role"])
    return {"access_token": token, "token_type": "bearer", "user": user}


@router.post("/login", response_model=TokenOut)
def login(payload: LoginIn, conn=Depends(get_db)):
    user = conn.execute(
        f"SELECT {USER_COLS}, password_hash FROM users WHERE email = %s",
        (payload.email.lower().strip(),),
    ).fetchone()
    if user is None or not verify_password(payload.password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    if not user["is_active"]:
        raise HTTPException(status_code=403, detail="Account is inactive")

    token = create_access_token(user["id"], user["role"])
    user.pop("password_hash")
    return {"access_token": token, "token_type": "bearer", "user": user}


@router.get("/me", response_model=UserOut)
def me(user=Depends(get_current_user)):
    return user
