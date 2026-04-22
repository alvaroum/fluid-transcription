from __future__ import annotations

import argparse
from pathlib import Path

from fluid_transcription import SCHEMA_VERSION, __version__
from fluid_transcription.adapter import FluidAudioAdapter
from fluid_transcription.errors import CLIError, ExitCode
from fluid_transcription.merge import build_markdown, combine_artifacts
from fluid_transcription.normalize import normalize_diarization, normalize_transcript
from fluid_transcription.utils import create_job_context, utc_now, write_json, write_jsonl, write_text
from fluid_transcription.validate import validate_run_directory


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    try:
        if args.command == "version":
            payload = _handle_version(args)
        elif args.command == "validate":
            payload = _handle_validate(args)
        elif args.command == "transcribe":
            payload = _handle_transcribe(args)
        elif args.command == "diarize":
            payload = _handle_diarize(args)
        elif args.command == "process":
            payload = _handle_process(args)
        else:
            raise CLIError("No command selected", ExitCode.INVALID_ARGUMENTS)

        print_json(payload)
        return ExitCode.SUCCESS
    except CLIError as exc:
        print_json(exc.to_dict(), stderr=True)
        return exc.exit_code


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="fluid-transcription")
    subparsers = parser.add_subparsers(dest="command", required=True)

    version_parser = subparsers.add_parser("version")
    version_parser.add_argument("--fluidaudio-cli-bin")
    version_parser.add_argument("--bundled-engine-path")
    version_parser.add_argument("--vendored-fluidaudio-repo")

    validate_parser = subparsers.add_parser("validate")
    validate_parser.add_argument("--run-dir", required=True)

    for name in ("transcribe", "diarize", "process"):
        command_parser = subparsers.add_parser(name)
        command_parser.add_argument("--input", required=True)
        command_parser.add_argument("--output", required=True)
        command_parser.add_argument("--job-id")
        command_parser.add_argument("--overwrite", action="store_true")
        command_parser.add_argument("--fluidaudio-cli-bin")
        command_parser.add_argument("--bundled-engine-path")
        command_parser.add_argument("--vendored-fluidaudio-repo")
        command_parser.add_argument("--model-version")
        if name in {"diarize", "process"}:
            command_parser.add_argument("--mode", choices=["offline", "streaming"], default="offline")
            command_parser.add_argument("--threshold", type=float, default=0.6)

    return parser


def _handle_version(args: argparse.Namespace) -> dict:
    adapter = FluidAudioAdapter(
        cli_bin=args.fluidaudio_cli_bin,
        bundled_engine_path=args.bundled_engine_path,
        vendored_repo_path=args.vendored_fluidaudio_repo,
    )
    return {
        "app": "fluid-transcription",
        "app_version": __version__,
        "schema_version": SCHEMA_VERSION,
        "fluidaudio": adapter.probe().to_dict(),
    }


def _handle_validate(args: argparse.Namespace) -> dict:
    run_dir = Path(args.run_dir).expanduser().resolve()
    report = validate_run_directory(run_dir)
    if not report["ok"]:
        raise CLIError("Validation failed", ExitCode.VALIDATION_FAILURE, report)
    return report


def _handle_transcribe(args: argparse.Namespace) -> dict:
    context = create_job_context(
        input_path=Path(args.input).expanduser(),
        output_dir=Path(args.output).expanduser(),
        mode="transcribe",
        job_id=args.job_id,
        overwrite=args.overwrite,
    )
    events = [_event("job_started", job_id=context.job_id, mode=context.mode)]
    try:
        adapter = FluidAudioAdapter(
            cli_bin=args.fluidaudio_cli_bin,
            bundled_engine_path=args.bundled_engine_path,
            vendored_repo_path=args.vendored_fluidaudio_repo,
        )
        events.append(_event("adapter_probe", **adapter.probe().to_dict()))
        raw_result = adapter.transcribe(context.input_path, model_version=args.model_version)
        transcript = normalize_transcript(context.job_id, str(context.input_path), raw_result)

        write_text(context.run_dir / "raw" / "transcribe.stdout.txt", raw_result["stdout"])
        write_text(context.run_dir / "raw" / "transcribe.stderr.txt", raw_result["stderr"])
        write_json(context.run_dir / "transcript.json", transcript)
        events.append(_event("artifact_written", artifact="transcript.json"))

        payload = _write_run_record(context, ["transcript.json", "events.jsonl"])
        events.append(_event("job_completed", status="completed"))
        write_jsonl(context.run_dir / "events.jsonl", events)
        return payload
    except CLIError as exc:
        _write_failure_artifacts(context, events, exc)
        raise


def _handle_diarize(args: argparse.Namespace) -> dict:
    context = create_job_context(
        input_path=Path(args.input).expanduser(),
        output_dir=Path(args.output).expanduser(),
        mode="diarize",
        job_id=args.job_id,
        overwrite=args.overwrite,
    )
    events = [_event("job_started", job_id=context.job_id, mode=context.mode)]
    try:
        adapter = FluidAudioAdapter(
            cli_bin=args.fluidaudio_cli_bin,
            bundled_engine_path=args.bundled_engine_path,
            vendored_repo_path=args.vendored_fluidaudio_repo,
        )
        events.append(_event("adapter_probe", **adapter.probe().to_dict()))
        raw_path = context.run_dir / "raw" / "diarization.raw.json"
        raw_result = adapter.diarize(
            context.input_path,
            output_path=raw_path,
            mode=args.mode,
            threshold=args.threshold,
        )
        diarization = normalize_diarization(context.job_id, str(context.input_path), raw_result)

        write_text(context.run_dir / "raw" / "diarize.stdout.txt", raw_result["stdout"])
        write_text(context.run_dir / "raw" / "diarize.stderr.txt", raw_result["stderr"])
        write_json(context.run_dir / "diarization.json", diarization)
        events.append(_event("artifact_written", artifact="diarization.json"))

        payload = _write_run_record(context, ["diarization.json", "events.jsonl"])
        events.append(_event("job_completed", status="completed"))
        write_jsonl(context.run_dir / "events.jsonl", events)
        return payload
    except CLIError as exc:
        _write_failure_artifacts(context, events, exc)
        raise


def _handle_process(args: argparse.Namespace) -> dict:
    context = create_job_context(
        input_path=Path(args.input).expanduser(),
        output_dir=Path(args.output).expanduser(),
        mode="process",
        job_id=args.job_id,
        overwrite=args.overwrite,
    )
    events = [_event("job_started", job_id=context.job_id, mode=context.mode)]
    try:
        adapter = FluidAudioAdapter(
            cli_bin=args.fluidaudio_cli_bin,
            bundled_engine_path=args.bundled_engine_path,
            vendored_repo_path=args.vendored_fluidaudio_repo,
        )
        events.append(_event("adapter_probe", **adapter.probe().to_dict()))
        raw_transcript = adapter.transcribe(context.input_path, model_version=args.model_version)
        raw_diarization_path = context.run_dir / "raw" / "diarization.raw.json"
        raw_diarization = adapter.diarize(
            context.input_path,
            output_path=raw_diarization_path,
            mode=args.mode,
            threshold=args.threshold,
        )

        transcript = normalize_transcript(context.job_id, str(context.input_path), raw_transcript)
        diarization = normalize_diarization(context.job_id, str(context.input_path), raw_diarization)
        combined = combine_artifacts(context.job_id, str(context.input_path), transcript, diarization)

        write_text(context.run_dir / "raw" / "transcribe.stdout.txt", raw_transcript["stdout"])
        write_text(context.run_dir / "raw" / "transcribe.stderr.txt", raw_transcript["stderr"])
        write_text(context.run_dir / "raw" / "diarize.stdout.txt", raw_diarization["stdout"])
        write_text(context.run_dir / "raw" / "diarize.stderr.txt", raw_diarization["stderr"])
        write_json(context.run_dir / "transcript.json", transcript)
        write_json(context.run_dir / "diarization.json", diarization)
        write_json(context.run_dir / "combined.json", combined)
        write_text(context.run_dir / "combined.md", build_markdown(combined))
        events.extend(
            [
                _event("artifact_written", artifact="transcript.json"),
                _event("artifact_written", artifact="diarization.json"),
                _event("artifact_written", artifact="combined.json"),
            ]
        )

        payload = _write_run_record(context, ["transcript.json", "diarization.json", "combined.json", "events.jsonl"])
        events.append(_event("job_completed", status="completed"))
        write_jsonl(context.run_dir / "events.jsonl", events)
        return payload
    except CLIError as exc:
        _write_failure_artifacts(context, events, exc)
        raise


def _write_run_record(context, artifacts: list[str]) -> dict:
    context.artifacts = artifacts
    payload = {
        "schema_version": SCHEMA_VERSION,
        "job_id": context.job_id,
        "mode": context.mode,
        "input": str(context.input_path),
        "run_dir": str(context.run_dir),
        "created_at": context.created_at,
        "status": "completed",
        "artifacts": artifacts,
    }
    write_json(context.run_dir / "run.json", payload)
    return payload


def _write_failure_artifacts(context, events: list[dict], exc: CLIError) -> None:
    events.append(_event("job_failed", error=exc.message, exit_code=int(exc.exit_code)))
    write_json(
        context.run_dir / "errors.json",
        {
            "schema_version": SCHEMA_VERSION,
            **exc.to_dict(),
        },
    )
    write_json(
        context.run_dir / "run.json",
        {
            "schema_version": SCHEMA_VERSION,
            "job_id": context.job_id,
            "mode": context.mode,
            "input": str(context.input_path),
            "run_dir": str(context.run_dir),
            "created_at": context.created_at,
            "status": "failed",
            "artifacts": ["errors.json", "events.jsonl"],
        },
    )
    write_jsonl(context.run_dir / "events.jsonl", events)


def _event(event: str, **payload: object) -> dict:
    return {
        "timestamp": utc_now(),
        "event": event,
        **payload,
    }


def print_json(payload: dict, stderr: bool = False) -> None:
    import json
    import sys

    stream = sys.stderr if stderr else sys.stdout
    stream.write(json.dumps(payload, indent=2) + "\n")
