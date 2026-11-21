"""The stack run.sh starts: REWRITER_URL is the rewriter, POSTGREST_URL the PostgREST behind it."""
import os
import time
from pathlib import Path

import pytest
from rest_client import Service
from stack_requests import StackRequests

READY_TIMEOUT_S = 60


@pytest.fixture(scope="session")
def rewriter() -> Service:
    service = Service(os.environ["REWRITER_URL"])
    # PostgREST answers once it has loaded its schema cache
    deadline = time.monotonic() + READY_TIMEOUT_S
    while (answer := service.status("/version")) != 200:
        if time.monotonic() > deadline:
            pytest.fail(f"the stack does not answer /version after {READY_TIMEOUT_S}s (last: {answer})")
        time.sleep(0.5)
    return service


@pytest.fixture(scope="session")
def postgrest() -> Service:
    return Service(os.environ["POSTGREST_URL"])


@pytest.fixture(scope="session")
def stack() -> StackRequests:
    return StackRequests(Path(os.environ["STACK_REQUESTS"]))
