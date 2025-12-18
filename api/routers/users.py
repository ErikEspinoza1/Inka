from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
import database, models, schemas, auth

router = APIRouter(prefix="/users", tags=["Users"])

# Obtener mi perfil (datos privados incluidos)
@router.get("/me", response_model=schemas.UserResponse)
def read_users_me(current_user: models.Profile = Depends(auth.get_current_user)):
    return current_user

# Obtener perfil público de otro usuario/artista por ID
@router.get("/{user_id}", response_model=schemas.UserResponse)
def read_user(user_id: str, db: Session = Depends(database.get_db)):
    user = db.query(models.Profile).filter(models.Profile.id == user_id).first()
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    return user

# Actualizar mi avatar o nombre
@router.patch("/me", response_model=schemas.UserResponse)
def update_user_me(
    full_name: str = None, 
    avatar_url: str = None,
    current_user: models.Profile = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db)
):
    if full_name:
        current_user.full_name = full_name
    if avatar_url:
        current_user.avatar_url = avatar_url
    
    db.commit()
    db.refresh(current_user)
    return current_user