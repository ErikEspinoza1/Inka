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
    # Validar que el usuario sea cliente
    if current_user.role != models.UserRole.cliente:
        raise HTTPException(status_code=403, detail="Only clients can create bookings")
    
    # Validar que el artista existe y está verificado
    artist = db.query(models.Artist).filter(models.Artist.id == booking_data.artist_id).first()
    if not artist:
        raise HTTPException(status_code=404, detail="Artist not found")
    
    if not artist.is_verified:
        raise HTTPException(status_code=403, detail="Artist is not verified")
    
    booking = models.Booking(**booking_data.dict(), client_id=current_user.id, status=models.BookingStatus.pendiente)
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
    # NOTE: the UserRole values are lowercase strings in the DB
    if current_user.role == models.UserRole.artista:
        return db.query(models.Booking).filter(models.Booking.artist_id == current_user.id).all()
    return db.query(models.Booking).filter(models.Booking.client_id == current_user.id).all()

# Actualizar estado y aceptaciones (Cliente + Artista)
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
        
    # Solo el artista o el cliente de esta reserva pueden editarla
    is_artist = booking.artist_id == current_user.id
    is_client = booking.client_id == current_user.id
    if not (is_artist or is_client):
        raise HTTPException(status_code=403, detail="Not authorized")
        
    old_status = booking.status
    old_price = booking.price_quote
    old_client_accepted = booking.client_accepted
    old_artist_accepted = booking.artist_accepted

    for key, value in update_data.dict(exclude_unset=True).items():
        if key == "client_accepted":
            if is_client or (is_artist and value is False):
                setattr(booking, key, value)
            else:
                raise HTTPException(status_code=403, detail=f"Not allowed to update field: {key}")
        elif key == "artist_accepted":
            if is_artist or (is_client and value is False):
                setattr(booking, key, value)
            else:
                raise HTTPException(status_code=403, detail=f"Not allowed to update field: {key}")
        elif key in {"status", "price_quote", "booking_date"} and is_artist:
            setattr(booking, key, value)
        else:
            raise HTTPException(status_code=403, detail=f"Not allowed to update field: {key}")

    # Auto-transition to accepted when both sides have agreed
    if booking.client_accepted and booking.artist_accepted:
        booking.status = models.BookingStatus.aceptado

    # Generación de mensajes automáticos
    status_changed = old_status != booking.status
    price_changed = old_price != booking.price_quote
    client_accepted_changed = old_client_accepted != booking.client_accepted
    artist_accepted_changed = old_artist_accepted != booking.artist_accepted

    if status_changed or price_changed or client_accepted_changed or artist_accepted_changed:
        import json
        message_data = {
            "type": "booking_update",
            "booking_id": str(booking.id),
            "status": booking.status.value if hasattr(booking.status, 'value') else booking.status,
            "idea_description": booking.idea_description,
            "body_part": booking.body_part,
            "size_cm": booking.size_cm,
            "price_quote": float(booking.price_quote) if booking.price_quote is not None else None,
            "booking_date": booking.booking_date.isoformat() if booking.booking_date else None,
            "client_accepted": booking.client_accepted,
            "artist_accepted": booking.artist_accepted,
            "autor": "client" if is_client else "artist"
        }
        
        sender_id = current_user.id
        receiver_id = booking.artist_id if is_client else booking.client_id
        
        new_message = models.Message(
            booking_id=booking.id,
            sender_id=sender_id,
            receiver_id=receiver_id,
            content=json.dumps(message_data)
        )
        db.add(new_message)

    db.commit()
    db.refresh(booking)
    return booking