from __future__ import annotations

import json
from pathlib import Path


def validate_run_directory(run_dir: Path) -> dict:
    errors: list[str] = []
    warnings: list[str] = []

    run_path = run_dir / "run.json"
    if not run_path.exists():
        errors.append("Missing run.json")
        return {"ok": False, "errors": errors, "warnings": warnings}

    run_payload = _load_json(run_path, errors)
    if not isinstance(run_payload, dict):
        errors.append("run.json must contain a JSON object")
        return {"ok": False, "errors": errors, "warnings": warnings}

    artifacts = run_payload.get("artifacts", [])
    for artifact_name in artifacts:
        artifact_path = run_dir / artifact_name
        if not artifact_path.exists():
            errors.append(f"Missing artifact referenced by run.json: {artifact_name}")
            continue
        if artifact_name == "events.jsonl":
            _validate_jsonl(artifact_path, errors)
            continue
        payload = _load_json(artifact_path, errors)
        if not isinstance(payload, dict):
            errors.append(f"Artifact must contain a JSON object: {artifact_name}")
            continue
        _validate_payload(artifact_name, payload, errors, warnings)

    return {"ok": not errors, "errors": errors, "warnings": warnings}


def _validate_payload(name: str, payload: dict, errors: list[str], warnings: list[str]) -> None:
    if payload.get("schema_version") is None:
        errors.append(f"{name}: missing schema_version")

    if name == "transcript.json":
        for index, segment in enumerate(payload.get("segments", []), start=1):
            _validate_time_pair(name, f"segments[{index}]", segment.get("start_sec"), segment.get("end_sec"), errors)
    elif name == "diarization.json":
        for index, turn in enumerate(payload.get("turns", []), start=1):
            _validate_time_pair(name, f"turns[{index}]", turn.get("start_sec"), turn.get("end_sec"), errors)
    elif name == "combined.json":
        utterances = payload.get("utterances", [])
        if not utterances:
            warnings.append("combined.json contains no utterances")
        for index, utterance in enumerate(utterances, start=1):
            _validate_time_pair(name, f"utterances[{index}]", utterance.get("start_sec"), utterance.get("end_sec"), errors, allow_null=True)
    elif name == "errors.json":
        if payload.get("error") is None:
            errors.append("errors.json: missing error")
        if payload.get("exit_code") is None:
            errors.append("errors.json: missing exit_code")


def _validate_time_pair(
    artifact_name: str,
    field_label: str,
    start_sec: float | None,
    end_sec: float | None,
    errors: list[str],
    allow_null: bool = False,
) -> None:
    if start_sec is None or end_sec is None:
        if not allow_null and not (start_sec is None and end_sec is None):
            errors.append(f"{artifact_name}: {field_label} must provide both start_sec and end_sec or neither")
        return
    if start_sec < 0 or end_sec < 0:
        errors.append(f"{artifact_name}: {field_label} contains a negative time")
    if end_sec < start_sec:
        errors.append(f"{artifact_name}: {field_label} has end_sec earlier than start_sec")


def _load_json(path: Path, errors: list[str]) -> dict | list | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        errors.append(f"Invalid JSON in {path.name}: {exc}")
        return None


def _validate_jsonl(path: Path, errors: list[str]) -> None:
    for line_number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not raw_line.strip():
            continue
        try:
            payload = json.loads(raw_line)
        except json.JSONDecodeError as exc:
            errors.append(f"Invalid JSONL in {path.name} line {line_number}: {exc}")
            continue
        if not isinstance(payload, dict):
            errors.append(f"events.jsonl line {line_number} must be a JSON object")
            continue
        if payload.get("event") is None:
            errors.append(f"events.jsonl line {line_number} missing event")
        if payload.get("timestamp") is None:
            errors.append(f"events.jsonl line {line_number} missing timestamp")
