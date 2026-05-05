import os
from dotenv import load_dotenv
from datetime import timedelta

load_dotenv()


class Config:
    # Mongo
    MONGO_URI = os.getenv("MONGO_URL")
