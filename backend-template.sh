#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting Backend Project Setup...${NC}"

# Step 1: Install Rye
echo -e "${YELLOW}Step 1: Installing Rye...${NC}"
curl -sSf https://rye.astral.sh/get | bash
source "$HOME/.rye/env"

# Step 2: Create backend directory
echo -e "${YELLOW}Step 2: Creating backend directory structure...${NC}"
mkdir -p backend
cd backend

# Initialize rye project
echo -e "${YELLOW}Step 3: Initializing Rye project...${NC}"
rye init .

# Step 4: Add dependencies
echo -e "${YELLOW}Step 4: Installing dependencies...${NC}"
rye add fastapi uvicorn python-jose passlib bcrypt python-multipart sqlalchemy alembic pydantic pydantic-settings python-dotenv openai stripe redis celery pytest pytest-asyncio httpx

# Create directory structure
echo -e "${YELLOW}Step 5: Creating project structure...${NC}"
mkdir -p app/api app/models app/services app/utils app/schemas
mkdir -p config migrations/versions tests static/images templates

# Create .env file
cat > .env << 'EOF'
# Database
DATABASE_URL=postgresql://user:password@localhost/dbname
# Alternative for SQLite
# DATABASE_URL=sqlite:///./app.db

# Security
SECRET_KEY=your-secret-key-here-change-in-production
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# OpenAI
OPENAI_API_KEY=your-openai-api-key-here

# Redis (optional)
REDIS_URL=redis://localhost:6379

# Environment
ENVIRONMENT=development
DEBUG=True

# CORS
CORS_ORIGINS=["http://localhost:3000", "http://localhost:8000"]

# Stripe (optional)
STRIPE_API_KEY=your-stripe-api-key-here
STRIPE_WEBHOOK_SECRET=your-stripe-webhook-secret-here
EOF

# Create app/__init__.py
cat > app/__init__.py << 'EOF'
"""Main application package."""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from config.settings import settings
from app.api.routes import router


def create_app() -> FastAPI:
    """Application factory."""
    app = FastAPI(
        title=settings.APP_NAME,
        version=settings.APP_VERSION,
        debug=settings.DEBUG,
    )

    # Configure CORS
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Include routers
    app.include_router(router, prefix="/api/v1")

    @app.get("/")
    async def root():
        return {"message": "Welcome to the API", "version": settings.APP_VERSION}

    @app.get("/health")
    async def health_check():
        return {"status": "healthy"}

    return app
EOF

# Create app/api/__init__.py
cat > app/api/__init__.py << 'EOF'
"""API module for handling routes and controllers."""
EOF

# Create app/api/routes.py
cat > app/api/routes.py << 'EOF'
"""API routes configuration."""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from app.models import get_db
from app.api import controllers
from app.schemas.user_schema import UserCreate, UserResponse, UserLogin, Token
from app.services.user_service import UserService
from app.utils.auth import get_current_user

router = APIRouter()

# User routes
@router.post("/users/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def register_user(user: UserCreate, db: Session = Depends(get_db)):
    """Register a new user."""
    return await controllers.create_user(user, db)

@router.post("/users/login", response_model=Token)
async def login(user: UserLogin, db: Session = Depends(get_db)):
    """Login user and return access token."""
    return await controllers.login_user(user, db)

@router.get("/users/me", response_model=UserResponse)
async def get_me(current_user: dict = Depends(get_current_user)):
    """Get current user information."""
    return current_user

@router.get("/users", response_model=List[UserResponse])
async def get_users(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Get all users (protected route)."""
    return await controllers.get_all_users(skip, limit, db)

# Product routes
@router.get("/products")
async def get_products(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    """Get all products."""
    return await controllers.get_products(skip, limit, db)

@router.post("/products")
async def create_product(
    product: dict,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Create a new product (protected route)."""
    return await controllers.create_product(product, db)

# OpenAI integration example
@router.post("/ai/generate")
async def generate_content(
    prompt: dict,
    current_user: dict = Depends(get_current_user)
):
    """Generate content using OpenAI."""
    return await controllers.generate_ai_content(prompt)
EOF

# Create app/api/controllers.py
cat > app/api/controllers.py << 'EOF'
"""Controllers for handling business logic."""
from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from datetime import timedelta
import openai
from config.settings import settings
from app.services.user_service import UserService
from app.services.payment_service import PaymentService
from app.schemas.user_schema import UserCreate, UserLogin
from app.utils.auth import create_access_token, verify_password


async def create_user(user: UserCreate, db: Session):
    """Create a new user."""
    user_service = UserService(db)
    
    # Check if user exists
    if user_service.get_user_by_email(user.email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    return user_service.create_user(user)


async def login_user(user: UserLogin, db: Session):
    """Authenticate user and return token."""
    user_service = UserService(db)
    db_user = user_service.get_user_by_email(user.email)
    
    if not db_user or not verify_password(user.password, db_user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    access_token = create_access_token(
        data={"sub": db_user.email},
        expires_delta=timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    
    return {"access_token": access_token, "token_type": "bearer"}


async def get_all_users(skip: int, limit: int, db: Session):
    """Get all users from database."""
    user_service = UserService(db)
    return user_service.get_users(skip, limit)


async def get_products(skip: int, limit: int, db: Session):
    """Get all products."""
    # Implement product logic here
    return {"products": [], "total": 0}


async def create_product(product: dict, db: Session):
    """Create a new product."""
    # Implement product creation logic here
    return {"message": "Product created", "product": product}


async def generate_ai_content(prompt: dict):
    """Generate content using OpenAI."""
    try:
        openai.api_key = settings.OPENAI_API_KEY
        response = openai.ChatCompletion.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "user", "content": prompt.get("text", "")}
            ]
        )
        return {"generated_content": response.choices[0].message.content}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"AI generation failed: {str(e)}"
        )
EOF

# Create app/models/__init__.py
cat > app/models/__init__.py << 'EOF'
"""Database models and configuration."""
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from config.settings import settings

engine = create_engine(settings.DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    """Database dependency."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# Import models here to ensure they're registered
from app.models.user import User
from app.models.product import Product
EOF

# Create app/models/user.py
cat > app/models/user.py << 'EOF'
"""User model definition."""
from sqlalchemy import Column, Integer, String, Boolean, DateTime
from sqlalchemy.sql import func
from app.models import Base


class User(Base):
    """User database model."""
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    username = Column(String, unique=True, index=True, nullable=False)
    full_name = Column(String)
    hashed_password = Column(String, nullable=False)
    is_active = Column(Boolean, default=True)
    is_superuser = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    def __repr__(self):
        return f"<User(email={self.email}, username={self.username})>"
EOF

# Create app/models/product.py
cat > app/models/product.py << 'EOF'
"""Product model definition."""
from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.models import Base


class Product(Base):
    """Product database model."""
    __tablename__ = "products"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False, index=True)
    description = Column(String)
    price = Column(Float, nullable=False)
    quantity = Column(Integer, default=0)
    is_available = Column(Boolean, default=True)
    category = Column(String, index=True)
    created_by = Column(Integer, ForeignKey("users.id"))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    def __repr__(self):
        return f"<Product(name={self.name}, price={self.price})>"
EOF

# Create app/services/__init__.py
cat > app/services/__init__.py << 'EOF'
"""Business logic services."""
EOF

# Create app/services/user_service.py
cat > app/services/user_service.py << 'EOF'
"""User service for business logic."""
from typing import Optional, List
from sqlalchemy.orm import Session
from app.models.user import User
from app.schemas.user_schema import UserCreate
from app.utils.auth import get_password_hash


class UserService:
    """Service class for user operations."""
    
    def __init__(self, db: Session):
        self.db = db
    
    def get_user(self, user_id: int) -> Optional[User]:
        """Get user by ID."""
        return self.db.query(User).filter(User.id == user_id).first()
    
    def get_user_by_email(self, email: str) -> Optional[User]:
        """Get user by email."""
        return self.db.query(User).filter(User.email == email).first()
    
    def get_user_by_username(self, username: str) -> Optional[User]:
        """Get user by username."""
        return self.db.query(User).filter(User.username == username).first()
    
    def get_users(self, skip: int = 0, limit: int = 100) -> List[User]:
        """Get list of users."""
        return self.db.query(User).offset(skip).limit(limit).all()
    
    def create_user(self, user: UserCreate) -> User:
        """Create a new user."""
        hashed_password = get_password_hash(user.password)
        db_user = User(
            email=user.email,
            username=user.username,
            full_name=user.full_name,
            hashed_password=hashed_password
        )
        self.db.add(db_user)
        self.db.commit()
        self.db.refresh(db_user)
        return db_user
    
    def update_user(self, user_id: int, user_data: dict) -> Optional[User]:
        """Update user information."""
        db_user = self.get_user(user_id)
        if db_user:
            for key, value in user_data.items():
                if hasattr(db_user, key) and key != "id":
                    setattr(db_user, key, value)
            self.db.commit()
            self.db.refresh(db_user)
        return db_user
    
    def delete_user(self, user_id: int) -> bool:
        """Delete a user."""
        db_user = self.get_user(user_id)
        if db_user:
            self.db.delete(db_user)
            self.db.commit()
            return True
        return False
EOF

# Create app/services/payment_service.py
cat > app/services/payment_service.py << 'EOF'
"""Payment service for handling transactions."""
import stripe
from typing import Optional, Dict
from config.settings import settings


class PaymentService:
    """Service class for payment operations."""
    
    def __init__(self):
        stripe.api_key = settings.STRIPE_API_KEY
    
    def create_payment_intent(self, amount: int, currency: str = "usd") -> Dict:
        """Create a payment intent."""
        try:
            intent = stripe.PaymentIntent.create(
                amount=amount,
                currency=currency,
                automatic_payment_methods={"enabled": True}
            )
            return {
                "client_secret": intent.client_secret,
                "payment_intent_id": intent.id
            }
        except stripe.error.StripeError as e:
            raise Exception(f"Payment failed: {str(e)}")
    
    def confirm_payment(self, payment_intent_id: str) -> Dict:
        """Confirm a payment."""
        try:
            intent = stripe.PaymentIntent.retrieve(payment_intent_id)
            return {
                "status": intent.status,
                "amount": intent.amount,
                "currency": intent.currency
            }
        except stripe.error.StripeError as e:
            raise Exception(f"Payment confirmation failed: {str(e)}")
    
    def create_customer(self, email: str, name: Optional[str] = None) -> str:
        """Create a Stripe customer."""
        try:
            customer = stripe.Customer.create(
                email=email,
                name=name
            )
            return customer.id
        except stripe.error.StripeError as e:
            raise Exception(f"Customer creation failed: {str(e)}")
    
    def create_subscription(self, customer_id: str, price_id: str) -> Dict:
        """Create a subscription."""
        try:
            subscription = stripe.Subscription.create(
                customer=customer_id,
                items=[{"price": price_id}],
                payment_behavior="default_incomplete",
                expand=["latest_invoice.payment_intent"]
            )
            return {
                "subscription_id": subscription.id,
                "status": subscription.status,
                "client_secret": subscription.latest_invoice.payment_intent.client_secret
            }
        except stripe.error.StripeError as e:
            raise Exception(f"Subscription creation failed: {str(e)}")
EOF

# Create app/utils/__init__.py
cat > app/utils/__init__.py << 'EOF'
"""Utility functions and helpers."""
EOF

# Create app/utils/helpers.py
cat > app/utils/helpers.py << 'EOF'
"""Helper functions."""
import re
from typing import Any, Dict, Optional
from datetime import datetime, timezone
import json


def validate_email(email: str) -> bool:
    """Validate email format."""
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return re.match(pattern, email) is not None


def validate_password_strength(password: str) -> bool:
    """
    Validate password strength.
    Requirements: At least 8 characters, one uppercase, one lowercase, one digit.
    """
    if len(password) < 8:
        return False
    if not re.search(r'[A-Z]', password):
        return False
    if not re.search(r'[a-z]', password):
        return False
    if not re.search(r'\d', password):
        return False
    return True


def serialize_datetime(obj: Any) -> str:
    """Serialize datetime objects to ISO format."""
    if isinstance(obj, datetime):
        return obj.isoformat()
    raise TypeError(f"Type {type(obj)} not serializable")


def get_current_timestamp() -> datetime:
    """Get current UTC timestamp."""
    return datetime.now(timezone.utc)


def paginate(query, page: int = 1, per_page: int = 20) -> Dict:
    """
    Paginate a SQLAlchemy query.
    Returns dict with items, total, page, and pages.
    """
    paginated = query.paginate(page=page, per_page=per_page, error_out=False)
    return {
        "items": paginated.items,
        "total": paginated.total,
        "page": page,
        "pages": paginated.pages,
        "per_page": per_page
    }


def sanitize_input(text: str) -> str:
    """Sanitize user input to prevent XSS attacks."""
    # Remove HTML tags
    clean = re.sub(r'<[^>]*>', '', text)
    # Remove script tags specifically
    clean = re.sub(r'<script[^>]*>.*?</script>', '', clean, flags=re.IGNORECASE | re.DOTALL)
    return clean.strip()


def format_response(
    data: Any = None,
    message: str = "Success",
    success: bool = True,
    status_code: int = 200
) -> Dict:
    """Format API response."""
    return {
        "success": success,
        "message": message,
        "data": data,
        "timestamp": get_current_timestamp().isoformat(),
        "status_code": status_code
    }


def parse_json_safe(json_string: str) -> Optional[Dict]:
    """Safely parse JSON string."""
    try:
        return json.loads(json_string)
    except (json.JSONDecodeError, TypeError):
        return None
EOF

# Create app/utils/auth.py
cat > app/utils/auth.py << 'EOF'
"""Authentication utilities."""
from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from config.settings import settings
from app.models import get_db
from app.models.user import User

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/users/login")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash."""
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    """Hash a password."""
    return pwd_context.hash(password)


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    """Create a JWT access token."""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt


def verify_token(token: str, credentials_exception):
    """Verify a JWT token."""
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            raise credentials_exception
        return email
    except JWTError:
        raise credentials_exception


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db)
):
    """Get the current authenticated user."""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    email = verify_token(token, credentials_exception)
    user = db.query(User).filter(User.email == email).first()
    if user is None:
        raise credentials_exception
    return user


async def get_current_active_user(current_user: User = Depends(get_current_user)):
    """Get the current active user."""
    if not current_user.is_active:
        raise HTTPException(status_code=400, detail="Inactive user")
    return current_user
EOF

# Create app/schemas/__init__.py
cat > app/schemas/__init__.py << 'EOF'
"""Pydantic schemas for data validation."""
EOF

# Create app/schemas/user_schema.py
cat > app/schemas/user_schema.py << 'EOF'
"""User validation schemas."""
from pydantic import BaseModel, EmailStr, Field, validator
from typing import Optional
from datetime import datetime
from app.utils.helpers import validate_password_strength


class UserBase(BaseModel):
    """Base user schema."""
    email: EmailStr
    username: str = Field(..., min_length=3, max_length=50)
    full_name: Optional[str] = None


class UserCreate(UserBase):
    """Schema for user creation."""
    password: str = Field(..., min_length=8)
    
    @validator('password')
    def validate_password(cls, v):
        if not validate_password_strength(v):
            raise ValueError('Password must be at least 8 characters with uppercase, lowercase, and digit')
        return v


class UserLogin(BaseModel):
    """Schema for user login."""
    email: EmailStr
    password: str


class UserUpdate(BaseModel):
    """Schema for user update."""
    full_name: Optional[str] = None
    username: Optional[str] = None
    email: Optional[EmailStr] = None


class UserResponse(UserBase):
    """Schema for user response."""
    id: int
    is_active: bool
    is_superuser: bool
    created_at: datetime
    updated_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True


class Token(BaseModel):
    """Token schema."""
    access_token: str
    token_type: str


class TokenData(BaseModel):
    """Token data schema."""
    email: Optional[str] = None
EOF

# Create app/schemas/product_schema.py
cat > app/schemas/product_schema.py << 'EOF'
"""Product validation schemas."""
from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


class ProductBase(BaseModel):
    """Base product schema."""
    name: str = Field(..., min_length=1, max_length=200)
    description: Optional[str] = None
    price: float = Field(..., gt=0)
    quantity: int = Field(default=0, ge=0)
    category: Optional[str] = None


class ProductCreate(ProductBase):
    """Schema for product creation."""
    pass


class ProductUpdate(BaseModel):
    """Schema for product update."""
    name: Optional[str] = None
    description: Optional[str] = None
    price: Optional[float] = Field(None, gt=0)
    quantity: Optional[int] = Field(None, ge=0)
    category: Optional[str] = None
    is_available: Optional[bool] = None


class ProductResponse(ProductBase):
    """Schema for product response."""
    id: int
    is_available: bool
    created_by: Optional[int] = None
    created_at: datetime
    updated_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True
EOF

# Create config/__init__.py
cat > config/__init__.py << 'EOF'
"""Configuration module."""
EOF

# Create config/settings.py
cat > config/settings.py << 'EOF'
"""Application settings."""
from pydantic_settings import BaseSettings
from typing import List
import os
from dotenv import load_dotenv

load_dotenv()


class Settings(BaseSettings):
    """Application settings."""
    # App
    APP_NAME: str = "FastAPI Backend"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = os.getenv("DEBUG", "False").lower() == "true"
    ENVIRONMENT: str = os.getenv("ENVIRONMENT", "development")
    
    # Database
    DATABASE_URL: str = os.getenv(
        "DATABASE_URL",
        "sqlite:///./app.db"
    )
    
    # Security
    SECRET_KEY: str = os.getenv("SECRET_KEY", "your-secret-key-change-in-production")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    
    # CORS
    CORS_ORIGINS: List[str] = [
        "http://localhost:3000",
        "http://localhost:8000",
        "http://localhost:5173",
    ]
    
    # OpenAI
    OPENAI_API_KEY: str = os.getenv("OPENAI_API_KEY", "")
    
    # Redis
    REDIS_URL: str = os.getenv("REDIS_URL", "redis://localhost:6379")
    
    # Stripe
    STRIPE_API_KEY: str = os.getenv("STRIPE_API_KEY", "")
    STRIPE_WEBHOOK_SECRET: str = os.getenv("STRIPE_WEBHOOK_SECRET", "")
    
    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
EOF

# Create config/logging.py
cat > config/logging.py << 'EOF'
"""Logging configuration."""
import logging
import sys
from pathlib import Path
from logging.handlers import RotatingFileHandler
from config.settings import settings

# Create logs directory
Path("logs").mkdir(exist_ok=True)


def setup_logging():
    """Configure application logging."""
    log_level = logging.DEBUG if settings.DEBUG else logging.INFO
    
    # Create formatter
    formatter = logging.Formatter(
        fmt='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    
    # Console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(formatter)
    console_handler.setLevel(log_level)
    
    # File handler
    file_handler = RotatingFileHandler(
        'logs/app.log',
        maxBytes=10485760,  # 10MB
        backupCount=5
    )
    file_handler.setFormatter(formatter)
    file_handler.setLevel(log_level)
    
    # Configure root logger
    logging.basicConfig(
        level=log_level,
        handlers=[console_handler, file_handler]
    )
    
    # Configure specific loggers
    logging.getLogger("uvicorn").setLevel(log_level)
    logging.getLogger("sqlalchemy").setLevel(logging.WARNING)
    
    return logging.getLogger(__name__)


logger = setup_logging()
EOF

# Create manage.py
cat > manage.py << 'EOF'
#!/usr/bin/env python
"""Command line interface for app management."""
import click
import uvicorn
from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine
from app.models import Base
from config.settings import settings


@click.group()
def cli():
    """Management CLI for the FastAPI application."""
    pass


@cli.command()
@click.option('--host', default='0.0.0.0', help='Host to bind')
@click.option('--port', default=8000, help='Port to bind')
@click.option('--reload', is_flag=True, help='Enable auto-reload')
def run(host, port, reload):
    """Run the development server."""
    uvicorn.run(
        "app:create_app",
        host=host,
        port=port,
        reload=reload,
        factory=True
    )


@cli.command()
def init_db():
    """Initialize the database."""
    engine = create_engine(settings.DATABASE_URL)
    Base.metadata.create_all(bind=engine)
    click.echo("Database initialized successfully!")


@cli.command()
def drop_db():
    """Drop all database tables."""
    if click.confirm("Are you sure you want to drop all tables?"):
        engine = create_engine(settings.DATABASE_URL)
        Base.metadata.drop_all(bind=engine)
        click.echo("Database tables dropped!")


@cli.command()
@click.argument('message')
def make_migration(message):
    """Create a new migration."""
    alembic_cfg = Config("alembic.ini")
    command.revision(alembic_cfg, message=message, autogenerate=True)
    click.echo(f"Migration '{message}' created!")


@cli.command()
def migrate():
    """Apply migrations."""
    alembic_cfg = Config("alembic.ini")
    command.upgrade(alembic_cfg, "head")
    click.echo("Migrations applied successfully!")


@cli.command()
def rollback():
    """Rollback the last migration."""
    alembic_cfg = Config("alembic.ini")
    command.downgrade(alembic_cfg, "-1")
    click.echo("Rolled back one migration!")


@cli.command()
def test():
    """Run tests."""
    import pytest
    pytest.main(["-v", "tests/"])


if __name__ == "__main__":
    cli()
EOF

# Create tests/__init__.py
cat > tests/__init__.py << 'EOF'
"""Test module."""
EOF

# Create tests/test_routes.py
cat > tests/test_routes.py << 'EOF'
"""Tests for API routes."""
import pytest
from fastapi.testclient import TestClient
from app import create_app
from app.models import Base, engine


@pytest.fixture
def client():
    """Create test client."""
    app = create_app()
    
    # Create test database
    Base.metadata.create_all(bind=engine)
    
    with TestClient(app) as test_client:
        yield test_client
    
    # Clean up
    Base.metadata.drop_all(bind=engine)


def test_root_endpoint(client):
    """Test root endpoint."""
    response = client.get("/")
    assert response.status_code == 200
    assert "message" in response.json()


def test_health_check(client):
    """Test health check endpoint."""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"


def test_user_registration(client):
    """Test user registration."""
    user_data = {
        "email": "test@example.com",
        "username": "testuser",
        "password": "TestPass123!",
        "full_name": "Test User"
    }
    response = client.post("/api/v1/users/register", json=user_data)
    assert response.status_code == 201
    data = response.json()
    assert data["email"] == user_data["email"]
    assert data["username"] == user_data["username"]
    assert "id" in data


def test_user_login(client):
    """Test user login."""
    # First register a user
    user_data = {
        "email": "test@example.com",
        "username": "testuser",
        "password": "TestPass123!",
        "full_name": "Test User"
    }
    client.post("/api/v1/users/register", json=user_data)
    
    # Then login
    login_data = {
        "email": "test@example.com",
        "password": "TestPass123!"
    }
    response = client.post("/api/v1/users/login", json=login_data)
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"


def test_protected_route_without_auth(client):
    """Test accessing protected route without authentication."""
    response = client.get("/api/v1/users/me")
    assert response.status_code == 401
EOF

# Create tests/test_services.py
cat > tests/test_services.py << 'EOF'
"""Tests for services."""
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.models import Base
from app.services.user_service import UserService
from app.schemas.user_schema import UserCreate


@pytest.fixture
def db_session():
    """Create test database session."""
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    SessionLocal = sessionmaker(bind=engine)
    session = SessionLocal()
    yield session
    session.close()


def test_create_user(db_session):
    """Test user creation service."""
    user_service = UserService(db_session)
    user_data = UserCreate(
        email="test@example.com",
        username="testuser",
        password="TestPass123!",
        full_name="Test User"
    )
    
    user = user_service.create_user(user_data)
    assert user.email == "test@example.com"
    assert user.username == "testuser"
    assert user.hashed_password != "TestPass123!"  # Password should be hashed


def test_get_user_by_email(db_session):
    """Test getting user by email."""
    user_service = UserService(db_session)
    user_data = UserCreate(
        email="test@example.com",
        username="testuser",
        password="TestPass123!",
        full_name="Test User"
    )
    
    created_user = user_service.create_user(user_data)
    found_user = user_service.get_user_by_email("test@example.com")
    
    assert found_user is not None
    assert found_user.id == created_user.id
EOF

# Create tests/test_models.py
cat > tests/test_models.py << 'EOF'
"""Tests for ORM models."""
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.models import Base
from app.models.user import User
from app.models.product import Product


@pytest.fixture
def db_session():
    """Create test database session."""
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    SessionLocal = sessionmaker(bind=engine)
    session = SessionLocal()
    yield session
    session.close()


def test_user_model(db_session):
    """Test User model."""
    user = User(
        email="test@example.com",
        username="testuser",
        hashed_password="hashedpass",
        full_name="Test User"
    )
    db_session.add(user)
    db_session.commit()
    
    assert user.id is not None
    assert user.email == "test@example.com"
    assert user.is_active is True
    assert user.is_superuser is False


def test_product_model(db_session):
    """Test Product model."""
    product = Product(
        name="Test Product",
        description="A test product",
        price=99.99,
        quantity=10,
        category="Test Category"
    )
    db_session.add(product)
    db_session.commit()
    
    assert product.id is not None
    assert product.name == "Test Product"
    assert product.price == 99.99
    assert product.is_available is True
EOF

# Create Dockerfile
cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 8000

# Run the application
CMD ["uvicorn", "app:create_app", "--host", "0.0.0.0", "--port", "8000", "--factory"]
EOF

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  web:
    build: .
    ports:
      - "8000:8000"
    volumes:
      - .:/app
    environment:
      - DATABASE_URL=postgresql://user:password@db:5432/dbname
      - REDIS_URL=redis://redis:6379
    depends_on:
      - db
      - redis
    command: uvicorn app:create_app --host 0.0.0.0 --port 8000 --reload --factory

  db:
    image: postgres:15
    environment:
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=password
      - POSTGRES_DB=dbname
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  pgadmin:
    image: dpage/pgadmin4
    environment:
      - PGADMIN_DEFAULT_EMAIL=admin@example.com
      - PGADMIN_DEFAULT_PASSWORD=admin
    ports:
      - "8080:80"
    depends_on:
      - db

volumes:
  postgres_data:
EOF

# Create README.md
cat > README.md << 'EOF'
# FastAPI Backend

A modern, scalable FastAPI backend with authentication, database integration, and AI capabilities.

## Features

- 🚀 **FastAPI** - Modern, fast web framework for building APIs
- 🔐 **JWT Authentication** - Secure token-based authentication
- 🗄️ **SQLAlchemy ORM** - Database abstraction with migrations
- 🎯 **Pydantic Validation** - Automatic request/response validation
- 🤖 **OpenAI Integration** - AI-powered features
- 💳 **Stripe Payments** - Payment processing capabilities
- 🐳 **Docker Support** - Containerized deployment
- ✅ **Testing** - Comprehensive test suite with pytest
- 📝 **Type Hints** - Full type annotation support

## Installation

### Using Rye (Recommended)

```bash
# Install dependencies
rye sync

# Run the application
rye run python manage.py run
```

### Using pip

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Run the application
python manage.py run
```

### Using Docker

```bash
# Build and run with Docker Compose
docker-compose up --build
```

## Project Structure

```
backend/
├── app/                    # Main application
│   ├── api/               # API routes and controllers
│   ├── models/            # Database models
│   ├── services/          # Business logic
│   ├── schemas/           # Pydantic schemas
│   └── utils/             # Utility functions
├── config/                # Configuration
├── migrations/            # Database migrations
├── tests/                 # Test suite
├── static/                # Static files
├── templates/             # HTML templates
└── manage.py              # CLI management tool
```

## Environment Variables

Create a `.env` file in the root directory:

```env
DATABASE_URL=postgresql://user:password@localhost/dbname
SECRET_KEY=your-secret-key-here
OPENAI_API_KEY=your-openai-api-key
STRIPE_API_KEY=your-stripe-api-key
```

## Database Setup

```bash
# Initialize database
python manage.py init_db

# Create migration
python manage.py make_migration "Initial migration"

# Apply migrations
python manage.py migrate
```

## API Documentation

Once running, visit:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## Testing

```bash
# Run all tests
python manage.py test

# Run with coverage
pytest --cov=app tests/
```

## Management Commands

```bash
# Run development server
python manage.py run

# Initialize database
python manage.py init_db

# Create migration
python manage.py make_migration "Description"

# Apply migrations
python manage.py migrate

# Rollback migration
python manage.py rollback

# Run tests
python manage.py test
```

## API Endpoints

### Authentication
- `POST /api/v1/users/register` - Register new user
- `POST /api/v1/users/login` - Login user
- `GET /api/v1/users/me` - Get current user

### Products
- `GET /api/v1/products` - List products
- `POST /api/v1/products` - Create product

### AI
- `POST /api/v1/ai/generate` - Generate AI content

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License.
EOF

# Create alembic.ini
cat > alembic.ini << 'EOF'
# A generic, single database configuration.

[alembic]
# path to migration scripts
script_location = migrations

# template used to generate migration files
# file_template = %%(rev)s_%%(slug)s

# sys.path path, will be prepended to sys.path if present.
# defaults to the current working directory.
prepend_sys_path = .

# timezone to use when rendering the date within the migration file
# as well as the filename.
# If specified, requires the python-dateutil library
# one of: postgresql, mysql, sqlite, oracle, mssql
# timezone =

# max length of characters to apply to the
# "slug" field
# truncate_slug_length = 40

# set to 'true' to run the environment during
# the 'revision' command, regardless of autogenerate
# revision_environment = false

# set to 'true' to allow .pyc and .pyo files without
# a source .py file to be detected as revisions in the
# versions/ directory
# sourceless = false

# version location specification; This defaults
# to migrations/versions.  When using multiple version
# directories, initial revisions must be specified with --version-path
# version_locations = %(here)s/bar:%(here)s/bat:migrations/versions

# version path separator; As mentioned above, this is the character used to split
# version_locations. The default within new alembic.ini files is "os", which uses os.pathsep.
# If this key is omitted entirely, it falls back to the legacy behavior of splitting on spaces and/or commas.
# Valid values for version_path_separator are:
#
# version_path_separator = :
# version_path_separator = ;
# version_path_separator = space
version_path_separator = os  # Use os.pathsep.
# the output encoding used when revision files
# are written from script.py.mako
# output_encoding = utf-8

sqlalchemy.url = sqlite:///./app.db


[post_write_hooks]
# post_write_hooks defines scripts or Python functions that are run
# on newly generated revision scripts.  See the documentation for further
# detail and examples

# format using "black" - use the console_scripts runner, against the "black" entrypoint
# hooks = black
# black.type = console_scripts
# black.entrypoint = black
# black.options = -l 79 REVISION_SCRIPT_FILENAME

# Logging configuration
[loggers]
keys = root,sqlalchemy,alembic

[handlers]
keys = console

[formatters]
keys = generic

[logger_root]
level = WARN
handlers = console
qualname =

[logger_sqlalchemy]
level = WARN
handlers =
qualname = sqlalchemy.engine

[logger_alembic]
level = INFO
handlers =
qualname = alembic

[handler_console]
class = StreamHandler
args = (sys.stderr,)
level = NOTSET
formatter = generic

[formatter_generic]
format = %(levelname)-5.5s [%(name)s] %(message)s
datefmt = %H:%M:%S
EOF

# Create migrations/env.py
cat > migrations/env.py << 'EOF'
from logging.config import fileConfig
from sqlalchemy import engine_from_config
from sqlalchemy import pool
from alembic import context
import sys
from pathlib import Path

# Add parent directory to path
sys.path.append(str(Path(__file__).parent.parent))

from app.models import Base
from config.settings import settings

# this is the Alembic Config object, which provides
# access to the values within the .ini file in use.
config = context.config

# Set the database URL from settings
config.set_main_option("sqlalchemy.url", settings.DATABASE_URL)

# Interpret the config file for Python logging.
# This line sets up loggers basically.
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# add your model's MetaData object here
# for 'autogenerate' support
target_metadata = Base.metadata

def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode."""
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """Run migrations in 'online' mode."""
    connectable = engine_from_config(
        config.get_section(config.config_ini_section),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection, target_metadata=target_metadata
        )

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
EOF

# Create migrations/README.md
cat > migrations/README.md << 'EOF'
# Database Migrations

This directory contains database migration scripts managed by Alembic.

## Creating a Migration

```bash
python manage.py make_migration "Description of changes"
```

## Applying Migrations

```bash
python manage.py migrate
```

## Rolling Back

```bash
python manage.py rollback
```

## Migration Best Practices

1. Always review auto-generated migrations before applying
2. Test migrations on a development database first
3. Keep migrations atomic and focused
4. Include both upgrade and downgrade operations
5. Use descriptive messages for migrations
EOF

# Step 6: Sync dependencies with rye
echo -e "${YELLOW}Step 6: Syncing dependencies...${NC}"
rye sync

# Step 7: Initialize database
echo -e "${YELLOW}Step 7: Initializing database...${NC}"
rye run python manage.py init_db

echo -e "${GREEN}✅ Backend setup complete!${NC}"
echo -e "${GREEN}📁 Project created in: ./backend${NC}"
echo -e ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Update the .env file with your configuration"
echo -e "2. Run the development server: ${GREEN}rye run python manage.py run${NC}"
echo -e "3. Visit API docs at: ${GREEN}http://localhost:8000/docs${NC}"
echo -e ""
echo -e "${YELLOW}Useful commands:${NC}"
echo -e "  Run server:        ${GREEN}rye run python manage.py run${NC}"
echo -e "  Run tests:         ${GREEN}rye run python manage.py test${NC}"
echo -e "  Create migration:  ${GREEN}rye run python manage.py make_migration 'description'${NC}"
echo -e "  Apply migrations:  ${GREEN}rye run python manage.py migrate${NC}"
echo -e "  Docker compose:    ${GREEN}docker-compose up --build${NC}"
