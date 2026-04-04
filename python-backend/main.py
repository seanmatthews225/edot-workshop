"""
EDOT Workshop - Python Backend
A simple FastAPI service providing user CRUD operations backed by PostgreSQL.
"""

import logging
from typing import List, Optional

from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError

from database import engine, get_db, Base
from models import User

# Create tables on startup
Base.metadata.create_all(bind=engine)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="EDOT Workshop - User API",
    description="Simple user management API for EDOT observability workshop",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Pydantic schemas ──────────────────────────────────────────────────────────

class UserCreate(BaseModel):
    name: str
    email: str


class UserResponse(BaseModel):
    id: int
    name: str
    email: str
    created_at: Optional[str] = None

    class Config:
        from_attributes = True

    @classmethod
    def from_orm(cls, obj):
        return cls(
            id=obj.id,
            name=obj.name,
            email=obj.email,
            created_at=str(obj.created_at) if obj.created_at else None,
        )


# ── Routes ────────────────────────────────────────────────────────────────────

@app.get("/health")
def health_check():
    return {"status": "UP", "service": "python-backend"}


@app.get("/api/users", response_model=List[UserResponse])
def get_users(db: Session = Depends(get_db)):
    logger.info("Fetching all users")
    users = db.query(User).order_by(User.id).all()
    return [UserResponse.from_orm(u) for u in users]


@app.get("/api/users/{user_id}", response_model=UserResponse)
def get_user(user_id: int, db: Session = Depends(get_db)):
    logger.info(f"Fetching user id={user_id}")
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail=f"User {user_id} not found")
    return UserResponse.from_orm(user)


@app.post("/api/users", response_model=UserResponse, status_code=201)
def create_user(user_data: UserCreate, db: Session = Depends(get_db)):
    logger.info(f"Creating user: {user_data.name} <{user_data.email}>")
    db_user = User(name=user_data.name, email=user_data.email)
    try:
        db.add(db_user)
        db.commit()
        db.refresh(db_user)
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail=f"A user with email '{user_data.email}' already exists"
        )
    return UserResponse.from_orm(db_user)


@app.delete("/api/users/{user_id}")
def delete_user(user_id: int, db: Session = Depends(get_db)):
    logger.info(f"Deleting user id={user_id}")
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail=f"User {user_id} not found")
    db.delete(user)
    db.commit()
    return {"message": f"User {user_id} deleted successfully"}
