from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
import database, models, schemas, auth

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
def login(
    user_credentials: schemas.UserLogin, 
    db: Session = Depends(database.get_db)
):
    # 1. Buscar usuario
    user = db.query(models.Profile).filter(models.Profile.email == user_credentials.email).first()
    
    # 2. Verificar existencia y contraseña
    if not user or not auth.verify_password(user_credentials.password, user.password):
        raise HTTPException(status_code=403, detail="Invalid credentials")
    
    # 3. EXTRAER ROL DE FORMA SEGURA (Aquí es donde daba el 500)
    # Si user.role tiene .value (es un Enum), lo usamos. Si no, lo pasamos a string.
    try:
        role_name = user.role.value if hasattr(user.role, 'value') else str(user.role or "client")
    except:
        role_name = "client"

    # 4. Generar Token
    access_token = auth.create_access_token(
        data={"sub": user.email, "role": role_name}
    )
    
    return {"access_token": access_token, "token_type": "bearer"}