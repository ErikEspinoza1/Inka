from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
import database, models, schemas, auth

router = APIRouter(prefix="/auth", tags=["Auth"])

@router.post("/register", response_model=schemas.UserResponse)
def register(user: schemas.UserCreate, db: Session = Depends(database.get_db)):
    # Check if exists
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
    user = db.query(models.Profile).filter(models.Profile.email == user_credentials.email).first()
    
    if not user or not auth.verify_password(user_credentials.password, user.password):
        raise HTTPException(status_code=403, detail="Invalid credentials")
    
    access_token = auth.create_access_token(data={"sub": user.email, "role": user.role.value})
    return {"access_token": access_token, "token_type": "bearer"}