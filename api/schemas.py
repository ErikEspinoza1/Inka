from pydantic import BaseModel, EmailStr
from typing import Optional, List
from uuid import UUID
from datetime import datetime
from models import UserRole, BookingStatus

# --- AUTH & PROFILES ---
class UserCreate(BaseModel):
    email: EmailStr
    password: str
    full_name: str

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str

class UserResponse(BaseModel):
    id: UUID
    email: EmailStr
    full_name: str
    role: UserRole
    class Config:
        from_attributes = True

# --- ARTISTS ---
class ArtistCreate(BaseModel):
    shop_name: str
    bio: str
    styles: List[str]
    address: str

class ArtistResponse(BaseModel):
    id: UUID
    shop_name: str
    bio: str
    is_verified: bool
    class Config:
        from_attributes = True

# --- BOOKINGS ---
class BookingCreate(BaseModel):
    artist_id: UUID
    idea_description: str
    body_part: str
    size_cm: Optional[str] = None

class BookingUpdate(BaseModel):
    status: Optional[BookingStatus] = None
    price_quote: Optional[float] = None
    booking_date: Optional[datetime] = None

class BookingResponse(BaseModel):
    id: UUID
    status: BookingStatus
    idea_description: str
    price_quote: Optional[float]
    created_at: datetime
    class Config:
        from_attributes = True

# --- POSTS ---
class PostCreate(BaseModel):
    image_url: str
    description: Optional[str] = None
    style_tag: Optional[str] = None

class PostResponse(BaseModel):
    id: UUID
    artist_id: UUID
    image_url: str
    description: Optional[str]
    created_at: datetime
    class Config:
        from_attributes = True

# --- REVIEWS ---
class ReviewCreate(BaseModel):
    booking_id: UUID
    rating: int # Validar que sea 1-5 en frontend o con validator aquí
    comment: Optional[str] = None

class ReviewResponse(BaseModel):
    id: UUID
    reviewer_id: UUID
    artist_id: UUID
    rating: int
    comment: Optional[str]
    created_at: datetime
    class Config:
        from_attributes = True

# --- AI DESIGNS ---
class AIDesignCreate(BaseModel):
    prompt_text: str
    image_url: str # En la vida real, aquí la API generaría la imagen, pero por ahora guardamos la URL
    style_tag: Optional[str] = None

class AIDesignResponse(BaseModel):
    id: UUID
    prompt_text: str
    image_url: str
    created_at: datetime
    class Config:
        from_attributes = True