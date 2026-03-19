from pydantic import BaseModel, EmailStr
from typing import Optional, List
from uuid import UUID
from datetime import datetime
from models import UserRole, BookingStatus, StudioType # Importamos el Enum

# --- USERS ---
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
    
    # Ubicación y Geolocalización
    address: str
    latitude: float
    longitude: float
    workspace_type: StudioType 
    show_exact_location: bool
    
    # Contacto
    instagram_handle: str
    whatsapp_number: Optional[str] = None
    website_url: Optional[str] = None
    
    # Documentación
    business_license_id: str 
    business_document_url: Optional[str] = None 

class ArtistUpdate(BaseModel):
    shop_name: Optional[str] = None
    bio: Optional[str] = None
    styles: Optional[List[str]] = None
    instagram_handle: Optional[str] = None
    address: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    workspace_type: Optional[StudioType] = None
    business_document_url: Optional[str] = None

# VERSIÓN ÚNICA Y CORRECTA DE ARTIST RESPONSE
class ArtistResponse(BaseModel):
    id: UUID
    shop_name: str
    bio: Optional[str] = None
    styles: Optional[List[str]] = []
    
    # Ubicación
    latitude: float  
    longitude: float 
    address: Optional[str] = None
    workspace_type: Optional[StudioType] = None 
    
    # Contacto e Imágenes
    instagram_handle: Optional[str] = None
    avatar_url: Optional[str] = None 
    
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
    rating: int
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
    image_url: str
    style_tag: Optional[str] = None

class AIDesignResponse(BaseModel):
    id: UUID
    prompt_text: str
    image_url: str
    created_at: datetime
    class Config:
        from_attributes = True

# --- MESSAGES ---
class MessageCreate(BaseModel):
    receiver_id: UUID
    content: str
    booking_id: Optional[UUID] = None

class MessageResponse(BaseModel):
    id: UUID
    booking_id: Optional[UUID]
    sender_id: UUID
    receiver_id: UUID
    content: str
    is_read: bool
    created_at: datetime
    class Config:
        from_attributes = True