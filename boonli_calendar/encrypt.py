"""This is the encrypt API endpoint."""

from base64 import b64encode
from urllib.parse import urlencode

import functions_framework
from flask import jsonify
from flask.wrappers import Request, Response

from boonli_calendar.crypto import encrypt_symmetric


@functions_framework.http
def encrypt(request: Request) -> Response:
    """Exposes an encryption function that encrypts the parameters to a string
    that can be understood by the `calendar` endpoint as the `eid`
    parameter."""
    args = request.form if request.method == "POST" else request.args
    data = {
        "username": args.get("username"),
        "password": args.get("password"),
        "customer_id": args.get("customer_id"),
    }

    for key in ["username", "password", "customer_id"]:
        if not data.get(key):
            raise Exception(f"Missing a required parameter: {key}")

    url_string = urlencode(data)
    encrypted = encrypt_symmetric(url_string)
    ret = {"eid": b64encode(encrypted).decode("ascii")}

    return jsonify(ret)
