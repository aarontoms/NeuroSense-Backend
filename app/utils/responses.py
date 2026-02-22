from flask import jsonify
from typing import Any


def success(message: Any | None = None, code: int = 200):

    body = {"Status": "OK"}
    if message:
        if isinstance(message, dict):
            body.update(message)
        else:
            body["data"] = message

    return jsonify(body), 200


def error(message: str, code: int = 400):
    return jsonify({
        "Status": "Error",
        "Message": message,
    }), code
