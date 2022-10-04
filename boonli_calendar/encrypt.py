"""This is the encrypt API endpoint."""

from base64 import b64encode
from urllib.parse import urlencode

import functions_framework
from flask import jsonify
from flask.wrappers import Request, Response

from boonli_calendar.crypto import encrypt_symmetric

# The domain the web site is hosted on
WEB_DOMAIN = "https://boonli.vovhund.com"


@functions_framework.http
def encrypt(request: Request) -> Response:
    """Exposes an encryption function that encrypts the parameters to a string
    that can be understood by the `calendar` endpoint as the `eid`
    parameter."""

    headers = {
        "Access-Control-Allow-Origin": WEB_DOMAIN,
        "Access-Control-Allow-Methods": "GET, POST",
    }

    # CORS Pre-flight handling
    if request.method == "OPTIONS":
        # Cache for 1 hour
        headers["Access-Control-Max-Age"] = "3600"
        return Response("", status=204, headers=headers)

    args = request.form if request.method == "POST" else request.args
    data = {
        "username": args.get("username"),
        "password": args.get("password"),
        "customer_id": args.get("customer_id"),
    }

    for key in ["username", "password", "customer_id"]:
        if not data.get(key):
            data = {"error": {"message": f"Missing a required parameter: {key}"}}
            response = jsonify(data)
            response.status_code = 500
            return response

    url_string = urlencode(data)
    encrypted = encrypt_symmetric(url_string)
    ret = {"eid": b64encode(encrypted).decode("ascii")}

    response = jsonify(ret)
    response.headers.extend(headers)
    return response
