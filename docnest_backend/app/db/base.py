from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import registry

mapper_registry = registry()
Base = declarative_base()

# Import all models here for Alembic
from app.models.user import User
from app.models.document import Document