from __future__ import annotations

import json
import re
from datetime import UTC, datetime
from hashlib import sha256
from pathlib import Path

from fluid_transcription.errors import CLIError, ExitCode
from fluid_transcription.models import JobContext


def utc_now() -> str:
    return datetime.now(UTC).replace(microsecond=0).isoformat()


def slugify(value: str) -> str:
    lowered = value.strip().lower()
    collapsed = re.sub(r"[^a-z0-9]+", "-", lowered)
    return collapsed.strip("-") or "job"


def stable_input_hash(path: Path) -> str:
    digest = sha256()
    digest.update(str(path.resolve()).encode("utf-8"))
    stat = path.stat()
    digest.update(str(stat.st_size).encode("utf-8"))
    digest.update(str(int(stat.st_mtime)).encode("utf-8"))
    return digest.hexdigest()[:12]


def create_job_context(
    input_path: Path,
    output_dir: Path,
    mode: str,
    job_id: str | None,
    overwrite: bool,
) -> JobContext:
    if not input_path.exists():
        raise CLIError(
            f"Input media not found: {input_path}",
            ExitCode.INPUT_ERROR,
            {"input": str(input_path)},
        )

    resolved_job_id = job_id or f"{slugify(input_path.stem)}-{stable_input_hash(input_path)}"
    run_dir = output_dir / resolved_job_id
    if run_dir.exists() and not overwrite:
        raise CLIError(
            f"Output job directory already exists: {run_dir}",
            ExitCode.INVALID_ARGUMENTS,
            {"job_id": resolved_job_id, "run_dir": str(run_dir)},
        )

    run_dir.mkdir(parents=True, exist_ok=True)
    (run_dir / "raw").mkdir(exist_ok=True)
    return JobContext(
        job_id=resolved_job_id,
        input_path=input_path.resolve(),
        run_dir=run_dir.resolve(),
        created_at=utc_now(),
        mode=mode,
    )


def write_json(path: Path, payload: dict | list) -> None:
    path.write_text(json.dumps(payload, indent=2, sort_keys=False) + "\n", encoding="utf-8")


def write_jsonl(path: Path, records: list[dict]) -> None:
    content = "\n".join(json.dumps(record, sort_keys=False) for record in records)
    path.write_text(content + ("\n" if content else ""), encoding="utf-8")


def write_text(path: Path, content: str) -> None:
    path.write_text(content.rstrip() + "\n", encoding="utf-8")
