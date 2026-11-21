"""Requests for a change of the stack, which run.sh serves from outside while the suite runs.

The suite's container has no Docker. A request is a file `request` in the directory
STACK_REQUESTS names; run.sh removes it once served and leaves its answer in `reply`.
"""
import os
import time
from dataclasses import dataclass
from pathlib import Path

REPLY_TIMEOUT_S = 120


class StackRequestError(Exception):
    """run.sh did not serve a request, or answered it with an error."""


@dataclass(frozen=True)
class StackRequests:
    directory: Path

    def ask(self, request: str) -> str:
        """Ask run.sh for `request` and return its reply.

        Raises StackRequestError when no reply comes within REPLY_TIMEOUT_S or the reply
        is an error.
        """
        self.directory.mkdir(parents=True, exist_ok=True)
        reply = self.directory / "reply"
        reply.unlink(missing_ok=True)
        pending = self.directory / "request.tmp"
        pending.write_text(request)
        os.replace(pending, self.directory / "request")
        deadline = time.monotonic() + REPLY_TIMEOUT_S
        while not reply.exists():
            if time.monotonic() > deadline:
                raise StackRequestError(f"no reply to {request} after {REPLY_TIMEOUT_S}s; is run.sh serving?")
            time.sleep(0.2)
        answer = reply.read_text()
        reply.unlink()
        if answer.startswith("error:"):
            raise StackRequestError(f"{request}: {answer}")
        return answer
