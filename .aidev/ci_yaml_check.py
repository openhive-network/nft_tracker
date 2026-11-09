"""Check a GitLab CI file and the files it includes.

    ci_yaml_check.py scripts FILE
    ci_yaml_check.py includes FILE [REF]
    ci_yaml_check.py extends FILE LABEL [FILE LABEL]...

`scripts`: every script, before_script and after_script of a job, a hidden job or
`default:` must be a string or a (nested) list of strings, as GitLab requires. A
plain scalar item holding `: ` (`- echo "a: b"`) parses as a mapping and fails
this. `!reference [...]` items are GitLab's and are accepted. Exits 1 naming each
bad item.

`includes`: one line per `include:` entry of FILE, tab-separated. `fetch REF PATH`
names a common-ci-configuration file to fetch at REF; `skip DESCRIPTION` an entry
that is not resolved (a template, another project, a remote, a wildcard, a ref
that is a variable). Without REF, FILE is the project's own file and its `local:`
entries are not resolved; with REF, FILE is a common-ci-configuration file at REF
and its `local:` entries are that project's files at that ref.

`extends`: every `extends` and `!reference [job, ...]` target of every job, hidden
job and other top-level entry of the FILEs must be defined in one of them. Exits 1
naming the defining file (by its LABEL), the job and each missing target.
"""
import sys
from collections.abc import Iterator
from typing import Any

import yaml

_SCRIPT_KEYS = ("before_script", "script", "after_script")
_CCC_PROJECT = "hive/common-ci-configuration"
_GLOBAL_KEYWORDS = frozenset({
    "default", "include", "stages", "variables", "workflow",
    "image", "services", "cache", "before_script", "after_script",
})


class _Reference:
    def __init__(self, path: list[Any]) -> None:
        self.path = path


yaml.SafeLoader.add_constructor(
    "!reference", lambda loader, node: _Reference(loader.construct_sequence(node, deep=True)))


def _load(path: str) -> dict[str, Any]:
    with open(path, encoding="utf-8") as f:
        config = yaml.safe_load(f)
    return config if isinstance(config, dict) else {}


def _bad_items(value: Any, path: str) -> Iterator[str]:
    if isinstance(value, (str, _Reference)):
        return
    if isinstance(value, list):
        for i, item in enumerate(value):
            yield from _bad_items(item, f"{path}[{i}]")
        return
    yield f"{path}: {type(value).__name__} {value!r}"


def _scripts(path: str) -> int:
    bad: list[str] = []
    for job, body in _load(path).items():
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


def _as_list(value: Any) -> list[Any]:
    return value if isinstance(value, list) else [value]


def _local_file(name: str, ref: str | None) -> str:
    if ref is None:
        return f"skip\tlocal: {name} (a file of this project)"
    if "*" in name:
        return f"skip\tlocal: {name} (a wildcard)"
    return f"fetch\t{ref}\t/{name.lstrip('/')}"


def _include_lines(entry: Any, ref: str | None) -> Iterator[str]:
    if isinstance(entry, str):
        if entry.startswith(("http://", "https://")):
            yield f"skip\tremote: {entry}"
        else:
            yield _local_file(entry, ref)
        return
    if not isinstance(entry, dict):
        yield f"skip\t{entry!r}"
        return
    if "local" in entry:
        yield _local_file(str(entry["local"]), ref)
    elif "project" in entry:
        project, files = str(entry["project"]).strip("/"), _as_list(entry.get("file"))
        entry_ref = entry.get("ref")
        if project != _CCC_PROJECT:
            yield f"skip\tproject: {project} {files}"
        elif not isinstance(entry_ref, str) or "$" in entry_ref:
            yield f"skip\tproject: {project} ref {entry_ref!r} {files}"
        else:
            for name in files:
                yield f"fetch\t{entry_ref}\t/{str(name).lstrip('/')}"
    elif "template" in entry:
        yield f"skip\ttemplate: {entry['template']}"
    else:
        yield f"skip\t{entry!r}"


def _includes(path: str, ref: str | None) -> int:
    for entry in _as_list(_load(path).get("include", [])):
        for line in _include_lines(entry, ref):
            print(line)
    return 0


def _references(value: Any) -> Iterator[str]:
    if isinstance(value, _Reference):
        if value.path:
            yield str(value.path[0])
    elif isinstance(value, dict):
        for item in value.values():
            yield from _references(item)
    elif isinstance(value, list):
        for item in value:
            yield from _references(item)


def _targets(name: str, body: Any) -> Iterator[tuple[str, str]]:
    if isinstance(body, dict) and name not in _GLOBAL_KEYWORDS:
        for target in _as_list(body.get("extends", [])):
            yield "extends", str(target)
    for target in _references(body):
        yield "!reference", target


def _extends(pairs: list[str]) -> int:
    files = [(pairs[i + 1], _load(pairs[i])) for i in range(0, len(pairs), 2)]
    defined = {name for _, config in files for name in config}
    missing = [
        f"{label}: {name}: {kind} {target}"
        for label, config in files
        for name, body in config.items()
        for kind, target in _targets(name, body)
        if target not in defined
    ]
    for item in missing:
        print(f"{item}: defined in none of the {len(files)} files")
    if missing:
        return 1
    print(f"every extends and !reference target is defined in the {len(files)} files")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) == 2 and argv[0] == "scripts":
        return _scripts(argv[1])
    if len(argv) in (2, 3) and argv[0] == "includes":
        return _includes(argv[1], argv[2] if len(argv) == 3 else None)
    if len(argv) >= 3 and len(argv) % 2 == 1 and argv[0] == "extends":
        return _extends(argv[1:])
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
