
import os
from dotenv import load_dotenv
from pydantic import BaseSettings

load_dotenv()

class Settings(BaseSettings):

    # POSTGRES_USER : str = os.getenv("POSTGRES_USER")
    # POSTGRES_PASSWORD: str = os.getenv("POSTGRES_PASSWORD")
    # POSTGRES_SERVER: str = os.getenv("POSTGRES_SERVER")
    # POSTGRES_DATABASE: str = os.getenv("POSTGRES_DATABASE")
    # POSTGRES_PORT: str = os.getenv("POSTGRES_PORT")
    DATABASE_URL = f"postgresql+asyncpg://{POSTGRES_USER}:{POSTGRES_PASSWORD}@{POSTGRES_SERVER}:{POSTGRES_PORT}/{POSTGRES_DATABASE}"

    class Config():
        env_file = ".env"

settings = Settings()     