"""This is the encrypt API endpoint."""

import logging
from base64 import b64encode
from urllib.parse import urlencode

import functions_framework
from flask import jsonify
from flask.wrappers import Request, Response

from boonli_calendar.common import add_cors_headers, init_logging
from boonli_calendar.crypto import encrypt_symmetric

init_logging()


def _create_error(message: str) -> Response:
    data = {"error": {"message": message}}
    response = jsonify(data)
    response.status_code = 500
    return response


@functions_framework.http
@add_cors_headers(["GET"])
def encrypt(request: Request) -> Response:
    """Exposes an encryption function that encrypts the parameters to a string
    that can be understood by the `calendar` endpoint as the `eid`
    parameter."""

    # CORS Pre-flight handling
    if request.method == "OPTIONS":
        # Cache for 1 hour
        headers = {"Access-Control-Max-Age": "3600"}
        return Response("", status=204, headers=headers)

    args = request.form if request.method == "POST" else request.args
    data = {
        "username": args.get("username"),
        "password": args.get("password"),
        "customer_id": args.get("customer_id"),
    }

    for key in ["username", "password", "customer_id"]:
        if not data.get(key):
            logging.error("Missing a required parameter: %s", key)
            return _create_error(f"Missing a required parameter: {key}")

    url_string = urlencode(data)
    try:
        encrypted = encrypt_symmetric(url_string)
    except Exception as ex:
        logging.error("Encryption error: %s", ex, exc_info=ex)
        return _create_error(f"Encryption error: {ex}")

    ret = {"eid": b64encode(encrypted).decode("ascii")}

    return jsonify(ret)
