"""
API key authentication dependency.
"""

from fastapi import HTTPException, Request, status
import hmac
from typing import Optional


class APIKeyAuthenticator:
    """FastAPI dependency that enforces optional API key authentication."""

    def __init__(self, expected_key: Optional[str]):
        self.expected_key = expected_key

    async def __call__(self, request: Request) -> None:
        if not self.expected_key:
            return

        header_key = request.headers.get("X-API-Key")
        if header_key and hmac.compare_digest(header_key, self.expected_key):
            return

        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key",
            headers={"WWW-Authenticate": "API-Key"},
        )
