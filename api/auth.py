import os
from datetime import datetime, timedelta
from typing import Optional
from jose import jwt, JWTError
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
import database, models

# --- CONFIGURACIÓN ---
# Lee la variable de Railway. Si no existe (en local), usa la de texto.
SECRET_KEY = os.getenv("SECRET_KEY", "inka_dev_secret_key_12345")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 43200  # 30 días

# Configuración de cifrado (Recuerda: bcrypt==4.0.1 en requirements.txt)
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

def verify_password(plain_password, hashed_password):
    """Compara texto plano con el hash de la base de datos"""
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    """Convierte contraseña en un hash seguro"""
    return pwd_context.hash(password)

def create_access_token(data: dict):
    """Genera el Token JWT"""
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(database.get_db)):
    """Validador para rutas protegidas (ej: /users/me)"""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    user = db.query(models.Profile).filter(models.Profile.email == email).first()
    if user is None:
        raise credentials_exception
    return user