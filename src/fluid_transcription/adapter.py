from __future__ import annotations

import json
import os
import shlex
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

from fluid_transcription.errors import CLIError, ExitCode


@dataclass(slots=True)
class AdapterProbe:
    available: bool
    source: str
    command: list[str]
    engine_path: str | None = None
    manifest: dict | None = None

    def to_dict(self) -> dict:
        payload = {
            "available": self.available,
            "source": self.source,
            "command": self.command,
        }
        if self.engine_path is not None:
            payload["engine_path"] = self.engine_path
        if self.manifest is not None:
            payload["manifest"] = self.manifest
        return payload


class FluidAudioAdapter:
    def __init__(
        self,
        cli_bin: str | None = None,
        bundled_engine_path: str | None = None,
        vendored_repo_path: str | None = None,
    ):
        self.cli_bin = cli_bin or os.environ.get("FLUIDAUDIO_CLI_BIN")
        self.bundled_engine_path = Path(
            bundled_engine_path or os.environ.get("FLUID_TRANSCRIPTION_BUNDLED_ENGINE", "")
        ).expanduser() if (bundled_engine_path or os.environ.get("FLUID_TRANSCRIPTION_BUNDLED_ENGINE")) else None
        default_vendored = Path(__file__).resolve().parents[2] / "vendor" / "FluidAudio"
        self.vendored_repo_path = Path(
            vendored_repo_path or os.environ.get("FLUIDAUDIO_VENDORED_REPO", str(default_vendored))
        ).expanduser()

    def probe(self) -> AdapterProbe:
        if self.cli_bin:
            resolved = shutil.which(self.cli_bin) or self.cli_bin
            return AdapterProbe(
                available=bool(shutil.which(self.cli_bin) or Path(resolved).exists()),
                source="cli_bin",
                command=[resolved],
                engine_path=str(resolved),
            )

        bundled_engine = self._bundled_engine_candidate()
        manifest = self._read_manifest(bundled_engine.parent.parent / "manifest.json") if bundled_engine is not None else None
        if bundled_engine is not None and bundled_engine.exists():
            return AdapterProbe(
                available=True,
                source="bundled",
                command=[str(bundled_engine)],
                engine_path=str(bundled_engine),
                manifest=manifest,
            )

        if self.vendored_repo_path.exists() and shutil.which("swift"):
            return AdapterProbe(
                available=True,
                source="vendored_source",
                command=["swift", "run", "--package-path", str(self.vendored_repo_path), "fluidaudiocli"],
                engine_path=str(self.vendored_repo_path),
                manifest=manifest,
            )

        return AdapterProbe(
            available=False,
            source="missing",
            command=[],
            engine_path=str(bundled_engine) if bundled_engine is not None else None,
            manifest=manifest,
        )

    def transcribe(self, input_path: Path, model_version: str | None = None) -> dict:
        command = self._base_command() + ["transcribe", str(input_path)]
        if model_version:
            command += ["--model-version", model_version]
        completed = self._run(command)
        return {
            "command": command,
            "stdout": completed.stdout.strip(),
            "stderr": completed.stderr.strip(),
        }

    def diarize(
        self,
        input_path: Path,
        output_path: Path,
        mode: str = "offline",
        threshold: float = 0.6,
    ) -> dict:
        command = self._base_command() + [
            "process",
            str(input_path),
            "--mode",
            mode,
            "--threshold",
            str(threshold),
            "--output",
            str(output_path),
        ]
        completed = self._run(command)
        if not output_path.exists():
            raise CLIError(
                "FluidAudio diarization command did not produce the expected JSON output file",
                ExitCode.ENGINE_FAILURE,
                {"command": command, "output": str(output_path), "stderr": completed.stderr.strip()},
            )
        return {
            "command": command,
            "stdout": completed.stdout.strip(),
            "stderr": completed.stderr.strip(),
            "json": json.loads(output_path.read_text(encoding="utf-8")),
        }

    def _base_command(self) -> list[str]:
        probe = self.probe()
        if not probe.available:
            raise CLIError(
                "Bundled FluidAudio engine is not available. Build a release bundle or stage the vendored FluidAudio binary first.",
                ExitCode.ENGINE_FAILURE,
                {
                    "FLUIDAUDIO_CLI_BIN": self.cli_bin,
                    "FLUID_TRANSCRIPTION_BUNDLED_ENGINE": str(self.bundled_engine_path) if self.bundled_engine_path else None,
                    "FLUIDAUDIO_VENDORED_REPO": str(self.vendored_repo_path),
                    "probe": probe.to_dict(),
                },
            )
        return probe.command

    def _bundled_engine_candidate(self) -> Path | None:
        candidates: list[Path] = []
        if self.bundled_engine_path is not None:
            candidates.append(self.bundled_engine_path)

        meipass = getattr(sys, "_MEIPASS", None)
        if meipass:
            candidates.append(Path(meipass) / "fluid_transcription" / "bundled" / "fluidaudio" / "bin" / "fluidaudiocli")

        candidates.append(Path(__file__).resolve().parent / "bundled" / "fluidaudio" / "bin" / "fluidaudiocli")

        for candidate in candidates:
            if candidate.exists():
                return candidate.resolve()

        return candidates[0] if candidates else None

    def _read_manifest(self, manifest_path: Path) -> dict | None:
        if not manifest_path.exists():
            return None
        try:
            return json.loads(manifest_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            return {"status": "invalid"}

    def _run(self, command: list[str]) -> subprocess.CompletedProcess[str]:
        completed = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=False,
        )
        if completed.returncode != 0:
            raise CLIError(
                "FluidAudio command failed",
                ExitCode.ENGINE_FAILURE,
                {
                    "command": shlex.join(command),
                    "returncode": completed.returncode,
                    "stdout": completed.stdout.strip(),
                    "stderr": completed.stderr.strip(),
                },
            )
        return completed
