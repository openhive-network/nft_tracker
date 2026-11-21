"""The rewriter after its PostgREST is recreated alone, as `docker compose up --no-deps
--force-recreate` does, with no restart or reload of the rewriter."""
import socket
import time
from urllib.parse import urlsplit

from rest_client import Service
from stack_requests import StackRequests

HEAL_TIMEOUT_S = 15


def test_rewriter_reaches_a_recreated_postgrest(rewriter: Service, postgrest: Service,
                                                 stack: StackRequests) -> None:
    postgrest_name = urlsplit(postgrest.base).hostname
    assert postgrest_name, f"POSTGREST_URL names no host: {postgrest.base}"
    address = socket.gethostbyname(postgrest_name)
    rewriter_before = stack.ask("rewriter-state")

    stack.ask("recreate-postgrest")
    recreated = time.monotonic()
    # run.sh keeps the old address taken, so a rewriter holding it cannot reach the new one
    assert socket.gethostbyname(postgrest_name) != address

    while (answer := rewriter.status("/version")) != 200:
        assert time.monotonic() - recreated < HEAL_TIMEOUT_S, \
            f"the rewriter does not answer /version {HEAL_TIMEOUT_S}s after the recreate (last: {answer})"
        time.sleep(0.5)
    assert stack.ask("rewriter-state") == rewriter_before, "the rewriter was restarted"

