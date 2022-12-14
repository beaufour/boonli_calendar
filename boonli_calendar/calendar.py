"""This is the calendar API endpoint."""

import logging
from base64 import b64decode
from datetime import date, timedelta
from urllib.parse import parse_qs

import functions_framework
from boonli_api.api import BoonliAPI, LoginError
from boonli_api.utils import menus_to_ical
from dateutil.relativedelta import MO, relativedelta
from flask import jsonify
from flask.wrappers import Request, Response

from boonli_calendar.common import add_cors_headers, init_logging
from boonli_calendar.crypto import decrypt_symmetric

init_logging()


@functions_framework.http
@add_cors_headers(["GET", "POST"])
def calendar(request: Request) -> Response:
    """Returns three weeks worth of menus in iCalendar format (last, current,
    and next week)

    The function takes `username`, `password` and `customer_id` as query params.

    You can also pass them in as a encrypted string using the `encrypt`
    function through `eid` which is much preferable, so we aren't sending
    passwords in plain text.

    Lastly, you can also pass them in through `id` with the query params as a
    base64 encoded UTF-8 string. This is terrible "security" but at least
    people don't see your password directly if they look at your calendar list?
    Or see it in a query log.

    To create the id in Python:
    > from base64 import b64encode
    > b64encode(bytes('username=...&password=...&customer_id=...', 'UTF-8'))
    """

    # CORS Pre-flight handling
    if request.method == "OPTIONS":
        # Cache for 1 hour
        headers = {"Access-Control-Max-Age": "3600"}
        return Response("", status=204, headers=headers)

    opt_id = request.args.get("id")
    eid = request.args.get("eid")
    if eid or opt_id:
        if eid:
            url_string = decrypt_symmetric(b64decode(eid))
        else:
            # Pylance is not smart enough to understand that id cannot be None here
            id_: str = opt_id  # type: ignore
            url_string = b64decode(id_).decode("utf-8")

        args_list = parse_qs(url_string)
        args = {}
        for arg, value in args_list.items():
            args[arg] = value[0]
    else:
        args = request.args

    for key in ["username", "password", "customer_id"]:
        if not args.get(key):
            return Response(f"Missing a required parameter: {key}", status=400)

    api = BoonliAPI()
    try:
        api.login(args["customer_id"], args["username"], args["password"])
    except LoginError as ex:
        logging.error("Boonli Login Error: %s", ex, exc_info=ex)
        return Response(f"Could not login to Boonli API: {ex}", status=401)
    except Exception as ex:
        logging.error("Boonli General Exception: %s", ex, exc_info=ex)
        return Response(f"Error logging in to Boonli API: {ex}", status=500)

    day = date.today()
    sequence_num = day.toordinal()

    # Start listening menus from a Monday. List menus from last week and show
    # 21 days from then
    if day.weekday() != MO:
        day = day + relativedelta(weekday=MO(-1))
    day -= timedelta(days=7)
    try:
        menus = api.get_range(day, 21)
    except Exception as ex:
        logging.error("Boonli exception getting menus: %s", ex, exc_info=ex)
        return Response(f"Could not get menus from Boonli API: {ex}", status=500)

    if request.args.get("fmt") == "json":
        data = [{"day": menu["day"].isoformat(), "menu": menu["menu"]} for menu in menus]
        return jsonify(data)

    # we set the sequence number to the current day as a hack, because being
    # stateless we don't know if anything has changed. That way it
    # monotonically increases every day at least.
    ical = menus_to_ical(menus, "beaufour.dk", sequence_num=sequence_num)

    response = Response(ical, headers={"Content-Type": "text/calendar"})
    return response
