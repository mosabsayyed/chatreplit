# backend/app/db/sqlalchemy_session.py
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from app.config import settings

# Create SQLAlchemy engine (synchronous for ORM operations)
SQLALCHEMY_DATABASE_URL = f"postgresql://{settings.PGUSER}:{settings.PGPASSWORD}@{settings.PGHOST}:{settings.PGPORT}/{settings.PGDATABASE}"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    pool_pre_ping=True,
    pool_size=5,
    max_overflow=10
)

# Create session factory
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def get_db() -> Session:
    """
    Dependency function to get database session
    Used in FastAPI endpoints with Depends()
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
