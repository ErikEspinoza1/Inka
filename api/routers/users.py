from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
import database, models, schemas, auth

router = APIRouter(prefix="/users", tags=["Users"])

# Obtener mi perfil (datos privados incluidos)
@router.get("/me", response_model=schemas.UserResponse)
def read_users_me(current_user: models.Profile = Depends(auth.get_current_user)):
    return current_user

@router.get("/me/favorites", response_model=List[schemas.PostResponse])
def get_my_favorites(
    current_user: models.Profile = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db)
):
    # Join explícito para obtener los Posts que el usuario ha guardado
    favorites = db.query(models.Post).join(
        models.Favorite, 
        models.Favorite.post_id == models.Post.id
    ).filter(models.Favorite.user_id == current_user.id).all()
    return favorites

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
    update_data: schemas.UserUpdate,
    current_user: models.Profile = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db)
):
    if update_data.full_name:
        current_user.full_name = update_data.full_name
    if update_data.email:
        # Verificar que el email no esté en uso por otro usuario
        existing_user = db.query(models.Profile).filter(
            models.Profile.email == update_data.email,
            models.Profile.id != current_user.id
        ).first()
        if existing_user:
            raise HTTPException(status_code=400, detail="Email already in use")
        current_user.email = update_data.email
    if update_data.avatar_url:
        current_user.avatar_url = update_data.avatar_url
    
    if update_data.new_password:
        if not update_data.current_password:
            raise HTTPException(status_code=400, detail="Current password is required to set a new one")
        if not auth.verify_password(update_data.current_password, current_user.password):
            raise HTTPException(status_code=403, detail="Incorrect current password")
        current_user.password = auth.get_password_hash(update_data.new_password)
    
    db.commit()
    db.refresh(current_user)
    return current_user