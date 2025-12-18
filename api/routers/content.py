from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
import database, models, schemas, auth

router = APIRouter(prefix="/content", tags=["Content"])

# ================= POSTS (Solo Artistas) =================
@router.post("/posts", response_model=schemas.PostResponse)
def create_post(
    post: schemas.PostCreate,
    current_user: models.Profile = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db)
):
    # Verificar si es artista
    if current_user.role != models.UserRole.ARTISTA:
        raise HTTPException(status_code=403, detail="Only artists can create posts")
    
    # Buscamos el ID del artista asociado al perfil
    if not current_user.artist_profile:
        raise HTTPException(status_code=400, detail="Artist profile not configured")

    new_post = models.Post(
        artist_id=current_user.artist_profile.id,
        **post.dict()
    )
    db.add(new_post)
    db.commit()
    db.refresh(new_post)
    return new_post

@router.get("/posts", response_model=List[schemas.PostResponse])
def get_feed(skip: int = 0, limit: int = 20, db: Session = Depends(database.get_db)):
    return db.query(models.Post).offset(skip).limit(limit).all()

# ================= REVIEWS (Clientes) =================
@router.post("/reviews", response_model=schemas.ReviewResponse)
def create_review(
    review: schemas.ReviewCreate,
    current_user: models.Profile = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db)
):
    # Verificar que la reserva existe
    booking = db.query(models.Booking).filter(models.Booking.id == review.booking_id).first()
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")
    
    # Verificar que el usuario es el cliente de esa reserva
    if booking.client_id != current_user.id:
        raise HTTPException(status_code=403, detail="You can only review your own bookings")

    new_review = models.Review(
        booking_id=booking.id,
        reviewer_id=current_user.id,
        artist_id=booking.artist_id,
        rating=review.rating,
        comment=review.comment
    )
    db.add(new_review)
    db.commit()
    db.refresh(new_review)
    return new_review

# ================= AI DESIGNS =================
@router.post("/ai-designs", response_model=schemas.AIDesignResponse)
def save_ai_design(
    design: schemas.AIDesignCreate,
    current_user: models.Profile = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db)
):
    # Aquí es donde guardarías el resultado de una generación por IA
    new_design = models.AIDesign(
        user_id=current_user.id,
        **design.dict()
    )
    db.add(new_design)
    db.commit()
    db.refresh(new_design)
    return new_design

@router.get("/ai-designs/me", response_model=List[schemas.AIDesignResponse])
def get_my_ai_designs(
    current_user: models.Profile = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db)
):
    return db.query(models.AIDesign).filter(models.AIDesign.user_id == current_user.id).all()