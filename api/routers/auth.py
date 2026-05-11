from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
import database, models, schemas, auth
import traceback

router = APIRouter(prefix="/auth", tags=["Auth"])

@router.post("/register", response_model=schemas.UserResponse)
def register(user: schemas.UserCreate, db: Session = Depends(database.get_db)):
    # Comprobar si el usuario ya existe
    db_user = db.query(models.Profile).filter(models.Profile.email == user.email).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    
    hashed_pwd = auth.get_password_hash(user.password)
    new_user = models.Profile(email=user.email, password=hashed_pwd, full_name=user.full_name)
    
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user

@router.post("/login", response_model=schemas.Token)
def login(user_credentials: schemas.UserLogin, db: Session = Depends(database.get_db)):
    try:
        # 1. Buscar usuario
        user = db.query(models.Profile).filter(models.Profile.email == user_credentials.email).first()
        
        # 2. Verificar existencia y contraseña
        if not user or not auth.verify_password(user_credentials.password, user.password):
            raise HTTPException(status_code=403, detail="Invalid credentials")
        
        # 3. Extraer rol de forma segura (Solución definitiva al Error 500)
        try:
            # Intentamos sacar el valor del Enum, si no, lo tratamos como String
            role_name = user.role.value if hasattr(user.role, 'value') else str(user.role or "client")
        except:
            role_name = "client"

        # 4. Generar Token usando la utilidad de auth.py
        access_token = auth.create_access_token(
            data={"sub": user.email, "role": role_name}
        )
        
        return {"access_token": access_token, "token_type": "bearer"}

    except Exception as e:
        # Si esto sale en los logs de Railway, sabremos exactamente qué falló
        print("!!! ERROR CRÍTICO EN LOGIN !!!")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail="Internal Server Error")