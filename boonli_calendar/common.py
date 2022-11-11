"""Common functionality shared across the app."""
import functools
import logging
import os
from typing import Callable, List

from flask.wrappers import Response
from typing_extensions import ParamSpec

# The domain the web site is hosted on
WEB_DOMAIN = "https://boonli.vovhund.com"

P = ParamSpec("P")


def add_cors_headers(
    methods: List[str],
) -> Callable[[Callable[P, Response]], Callable[P, Response]]:
    """Adds CORS headers to the response to allow calls from the main
    domain."""

    def actual_decorator(func: Callable[P, Response]) -> Callable[P, Response]:
        @functools.wraps(func)
        def wrapper(*args: P.args, **kwargs: P.kwargs) -> Response:
            response = func(*args, **kwargs)
            response.headers.extend(
                {
                    "Access-Control-Allow-Origin": WEB_DOMAIN,
                    "Access-Control-Allow-Methods": ", ".join(methods),
                }
            )
            return response

        return wrapper

    return actual_decorator


def init_logging() -> None:
    """Initializes the logging system."""
    level = os.environ.get("LOG_LEVEL", "INFO").upper()
    logging.basicConfig(level=level)
