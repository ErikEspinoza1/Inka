import uuid
from sqlalchemy import Column, String, Boolean, ForeignKey, Integer, Float, Text, DateTime, Enum, Numeric, ARRAY
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import enum
from database import Base

# Enums basados en tu SQL
class UserRole(str, enum.Enum):
    cliente = "cliente"
    artista = "artista"
    admin = "admin"

class BookingStatus(str, enum.Enum):
    pendiente = "pendiente"
    aceptado = "aceptado"
    rechazado = "rechazado"
    finalizado = "finalizado"

class Profile(Base):
    __tablename__ = "profiles"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String, unique=True, index=True)
    full_name = Column(String)
    avatar_url = Column(String, nullable=True)
    role = Column(Enum(UserRole), default=UserRole.cliente)
    password = Column(String) # Hash
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relaciones
    artist_profile = relationship("Artist", back_populates="profile", uselist=False)
    bookings_as_client = relationship("Booking", back_populates="client", foreign_keys="Booking.client_id")

class Artist(Base):
    __tablename__ = "artists"
    id = Column(UUID(as_uuid=True), ForeignKey("profiles.id"), primary_key=True)
    shop_name = Column(String)
    bio = Column(Text)
    styles = Column(ARRAY(String)) # Requiere Postgres
    address = Column(String)
    latitude = Column(Float)
    longitude = Column(Float)
    is_verified = Column(Boolean, default=False)

    profile = relationship("Profile", back_populates="artist_profile")
    posts = relationship("Post", back_populates="artist")
    bookings = relationship("Booking", back_populates="artist", foreign_keys="Booking.artist_id")

class Post(Base):
    __tablename__ = "posts"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    artist_id = Column(UUID(as_uuid=True), ForeignKey("artists.id"), nullable=False)
    image_url = Column(String, nullable=False)
    description = Column(Text)
    style_tag = Column(String)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    artist = relationship("Artist", back_populates="posts")

class Booking(Base):
    __tablename__ = "bookings"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    client_id = Column(UUID(as_uuid=True), ForeignKey("profiles.id"), nullable=False)
    artist_id = Column(UUID(as_uuid=True), ForeignKey("artists.id"), nullable=False)
    status = Column(Enum(BookingStatus), default=BookingStatus.pendiente)
    idea_description = Column(Text, nullable=False)
    body_part = Column(String, nullable=False)
    size_cm = Column(String)
    price_quote = Column(Numeric, nullable=True)
    booking_date = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    client = relationship("Profile", foreign_keys=[client_id])
    artist = relationship("Artist", foreign_keys=[artist_id])
    messages = relationship("Message", back_populates="booking")

class Message(Base):
    __tablename__ = "messages"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    booking_id = Column(UUID(as_uuid=True), ForeignKey("bookings.id"))
    sender_id = Column(UUID(as_uuid=True), ForeignKey("profiles.id"))
    content = Column(Text, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    booking = relationship("Booking", back_populates="messages")

# ... Agrega AI_Designs, Reviews, SavedPosts siguiendo este patrón ...