from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
import database, models, schemas, auth

router = APIRouter(prefix="/bookings", tags=["Bookings"])

# Crear una reserva (Cliente)
@router.post("/", response_model=schemas.BookingResponse)
def create_booking(
    booking_data: schemas.BookingCreate,
    current_user: models.Profile = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db)
):
    booking = models.Booking(**booking_data.dict(), client_id=current_user.id)
    db.add(booking)
    db.commit()
    db.refresh(booking)
    return booking

# Ver mis reservas (Como cliente o artista)
@router.get("/me", response_model=List[schemas.BookingResponse])
def get_my_bookings(
    current_user: models.Profile = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db)
):
    if current_user.role == models.UserRole.ARTISTA:
        return db.query(models.Booking).filter(models.Booking.artist_id == current_user.id).all()
    return db.query(models.Booking).filter(models.Booking.client_id == current_user.id).all()

# Actualizar estado (Solo Artista)
@router.patch("/{booking_id}", response_model=schemas.BookingResponse)
def update_booking(
    booking_id: str,
    update_data: schemas.BookingUpdate,
    current_user: models.Profile = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db)
):
    booking = db.query(models.Booking).filter(models.Booking.id == booking_id).first()
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")
        
    # Validar que el usuario sea el artista de esa reserva
    if booking.artist_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")
        
    for key, value in update_data.dict(exclude_unset=True).items():
        setattr(booking, key, value)
        
    db.commit()
    db.refresh(booking)
    return booking