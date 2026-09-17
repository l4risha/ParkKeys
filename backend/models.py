from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    full_name = Column(String(120), nullable=False)
    email = Column(String(150), unique=True, index=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    role = Column(String(20), nullable=False, default="passenger")  # passenger | driver | admin
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    driver_profile = relationship("Driver", back_populates="user", uselist=False)


class Driver(Base):
    __tablename__ = "drivers"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), unique=True, nullable=False)
    vehicle_plate_number = Column(String(20), nullable=True)
    route_name = Column(String(120), nullable=True)
    status = Column(String(20), nullable=False, default="offline")  # offline | queued | driving
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="driver_profile")
