from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
import database, models, schemas, auth

router = APIRouter(prefix="/artists", tags=["Artists"])

@router.get("/", response_model=List[schemas.ArtistResponse])
def get_all_artists(db: Session = Depends(database.get_db)):
    return db.query(models.Artist).all()

@router.post("/become-artist", response_model=schemas.ArtistResponse)
def create_artist_profile(
    artist_data: schemas.ArtistCreate, 
    current_user: models.Profile = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db)
):
    if current_user.artist_profile:
        raise HTTPException(status_code=400, detail="User is already an artist")
    
    new_artist = models.Artist(id=current_user.id, **artist_data.dict())
    
    # Update role
    current_user.role = models.UserRole.ARTISTA
    
    db.add(new_artist)
    db.commit()
    db.refresh(new_artist)
    return new_artist