"""
Logging configuration helpers for the model serving API.
"""

import contextvars
import logging
import logging.config

TRACE_ID: contextvars.ContextVar[str] = contextvars.ContextVar("trace_id", default="-")
SPAN_ID: contextvars.ContextVar[str] = contextvars.ContextVar("span_id", default="-")


def configure_logging(level: str = "INFO") -> None:
    """
    Configure structured logging for the service.

    Args:
        level: Root log level as string.
    """
    logging.config.dictConfig(
        {
            "version": 1,
            "disable_existing_loggers": False,
            "formatters": {
                "structured": {
                    "format": (
                        "%(asctime)s %(levelname)s %(name)s "
                        "%(message)s trace_id=%(trace_id)s span_id=%(span_id)s"
                    )
                }
            },
            "filters": {"context": {"()": RequestContextFilter}},
            "handlers": {
                "stdout": {
                    "class": "logging.StreamHandler",
                    "formatter": "structured",
                    "filters": ["context"],
                }
            },
            "root": {"level": level.upper(), "handlers": ["stdout"]},
            "loggers": {
                "uvicorn": {"level": level.upper(), "handlers": ["stdout"], "propagate": False},
                "uvicorn.error": {"level": level.upper(), "handlers": ["stdout"], "propagate": False},
                "uvicorn.access": {"level": level.upper(), "handlers": ["stdout"], "propagate": False},
            },
        }
    )


class RequestContextFilter(logging.Filter):
    """Ensure trace context fields are always present."""

    def filter(self, record: logging.LogRecord) -> bool:
        record.trace_id = getattr(record, "trace_id", TRACE_ID.get())
        record.span_id = getattr(record, "span_id", SPAN_ID.get())
        return True


def set_request_context(trace_id: str, span_id: str = "-") -> None:
    """Populate context variables for subsequent log records."""
    TRACE_ID.set(trace_id)
    SPAN_ID.set(span_id)
