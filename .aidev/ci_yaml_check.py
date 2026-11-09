"""Check the script shape of a GitLab CI file.

    ci_yaml_check.py FILE

Every script, before_script and after_script of a job, a hidden job or `default:`
must be a string or a (nested) list of strings, as GitLab requires. A plain
scalar item holding `: ` (`- echo "a: b"`) parses as a mapping and fails this.
`!reference [...]` items are GitLab's and are accepted. Exits 1 naming each bad
item.
"""
import sys
from collections.abc import Iterator
from typing import Any

import yaml

_SCRIPT_KEYS = ("before_script", "script", "after_script")


class _Reference:
    pass


yaml.SafeLoader.add_constructor("!reference", lambda loader, node: _Reference())


def _bad_items(value: Any, path: str) -> Iterator[str]:
    if isinstance(value, (str, _Reference)):
        return
    if isinstance(value, list):
        for i, item in enumerate(value):
            yield from _bad_items(item, f"{path}[{i}]")
        return
    yield f"{path}: {type(value).__name__} {value!r}"


def main(path: str) -> int:
    with open(path, encoding="utf-8") as f:
        config = yaml.safe_load(f)
    bad: list[str] = []
    for job, body in config.items():
        if not isinstance(body, dict):
            continue
        for key in _SCRIPT_KEYS:
            if key in body:
                bad.extend(_bad_items(body[key], f"{job}:{key}"))
    for item in bad:
        print(f"{path}: not a string: {item} (quote the item)")
    if bad:
        return 1
    print(f"{path}: every script item is a string")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
