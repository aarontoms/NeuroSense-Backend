from datetime import datetime, timezone
from app.extensions import mongo
from typing import cast
from pymongo.database import Database

def revoke_token(jti: str, token_type: str, exp: int):
    db = cast(Database, mongo.db)
    db.revoked_tokens.insert_one({
        "jti": jti,
        "type": token_type,
        "expires_at": datetime.fromtimestamp(exp, tz=timezone.utc)
    })
