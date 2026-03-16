from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
import database, models, schemas, auth

router = APIRouter(prefix="/messages", tags=["Messages"])

@router.get("/", response_model=List[schemas.MessageResponse])
def get_messages_with_artist(
    artist_id: str,
    current_user: models.Profile = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db)
):
    # Devuelve mensajes entre el usuario actual y el artista especificado
    messages = db.query(models.Message).filter(
        ((models.Message.sender_id == current_user.id) & (models.Message.receiver_id == artist_id))
        | ((models.Message.sender_id == artist_id) & (models.Message.receiver_id == current_user.id))
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
