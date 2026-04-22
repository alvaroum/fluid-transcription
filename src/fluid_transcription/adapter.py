from __future__ import annotations

import json
import os
import shlex
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path

from fluid_transcription.errors import CLIError, ExitCode


@dataclass(slots=True)
class AdapterProbe:
    available: bool
    source: str
    command: list[str]

    def to_dict(self) -> dict:
        return {
            "available": self.available,
            "source": self.source,
            "command": self.command,
        }


class FluidAudioAdapter:
    def __init__(
        self,
        cli_bin: str | None = None,
        repo_path: str | None = None,
    ):
        self.cli_bin = cli_bin or os.environ.get("FLUIDAUDIO_CLI_BIN")
        self.repo_path = Path(repo_path or os.environ.get("FLUIDAUDIO_REPO", "~/tools/src/FluidAudio")).expanduser()

    def probe(self) -> AdapterProbe:
        if self.cli_bin:
            resolved = shutil.which(self.cli_bin) or self.cli_bin
            return AdapterProbe(available=bool(shutil.which(self.cli_bin) or Path(resolved).exists()), source="cli_bin", command=[resolved])

        installed = shutil.which("fluidaudiocli")
        if installed:
            return AdapterProbe(available=True, source="path", command=[installed])

        if self.repo_path.exists() and shutil.which("swift"):
            return AdapterProbe(
                available=True,
                source="swift_run",
                command=["swift", "run", "--package-path", str(self.repo_path), "fluidaudiocli"],
            )

        return AdapterProbe(available=False, source="missing", command=[])

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
                "FluidAudio CLI is not available. Install fluidaudiocli or set FLUIDAUDIO_REPO/FLUIDAUDIO_CLI_BIN.",
                ExitCode.ENGINE_FAILURE,
                {
                    "FLUIDAUDIO_CLI_BIN": self.cli_bin,
                    "FLUIDAUDIO_REPO": str(self.repo_path),
                },
            )
        return probe.command

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
