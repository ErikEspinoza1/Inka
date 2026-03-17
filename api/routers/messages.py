from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Set
import database, models, schemas, auth

router = APIRouter(prefix="/messages", tags=["Messages"])

@router.get("/contacts", response_model=List[dict])
def get_message_contacts(
    current_user: models.Profile = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db)
):
    # Obtiene todos los mensajes del usuario actual
    messages = db.query(models.Message).filter(
        (models.Message.sender_id == current_user.id) | (models.Message.receiver_id == current_user.id)
    ).all()
    
    # Extraer IDs únicos de contactos
    contact_ids: Set = set()
    for msg in messages:
        if msg.sender_id == current_user.id:
            contact_ids.add(msg.receiver_id)
        else:
            contact_ids.add(msg.sender_id)
    
    if not contact_ids:
        return []
    
    # Obtener los perfiles de los contactos
    contacts = db.query(models.Profile).filter(
        models.Profile.id.in_(list(contact_ids))
    ).all()
    
    result = []
    for profile in contacts:
        contact_dict = {
            "id": str(profile.id),
            "email": profile.email,
            "full_name": profile.full_name,
            "avatar_url": profile.avatar_url,
            "role": profile.role.value,
        }
        
        # Si es artista, agregar datos adicionales
        if profile.artist_profile:
            contact_dict.update({
                "shop_name": profile.artist_profile.shop_name,
                "styles": profile.artist_profile.styles,
                "is_verified": profile.artist_profile.is_verified,
            })
        
        result.append(contact_dict)
    
    return result

@router.get("/", response_model=List[schemas.MessageResponse])
def get_messages_with_artist(
    artist_id: str,
    current_user: models.Profile = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db)
):
    # Devuelve mensajes entre el usuario actual y el artista especificado
    # Incluyendo mensajes de sistema asociados a sus bookings
    from sqlalchemy import or_

    # Find total bookings between current_user and artist
    bookings = db.query(models.Booking.id).filter(
        or_(
            (models.Booking.client_id == current_user.id) & (models.Booking.artist_id == artist_id),
            (models.Booking.artist_id == current_user.id) & (models.Booking.client_id == artist_id)
        )
    ).all()
    booking_ids = [b[0] for b in bookings]

    messages = db.query(models.Message).filter(
        or_(
            (models.Message.sender_id == current_user.id) & (models.Message.receiver_id == artist_id),
            (models.Message.sender_id == artist_id) & (models.Message.receiver_id == current_user.id),
            models.Message.booking_id.in_(booking_ids) if booking_ids else False
        )
    ).order_by(models.Message.created_at.asc()).all()
    return messages

@router.post("/", response_model=schemas.MessageResponse)
def send_message(
    message_data: schemas.MessageCreate,
    current_user: models.Profile = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db)
):
    # Validación mínima: destino y contenido
    if not message_data.receiver_id or not message_data.content:
        raise HTTPException(status_code=400, detail="receiver_id and content are required")

    new_message = models.Message(
        booking_id=message_data.booking_id,
        sender_id=current_user.id,
        receiver_id=message_data.receiver_id,
        content=message_data.content,
    )

    db.add(new_message)
    db.commit()
    db.refresh(new_message)
    return new_message
