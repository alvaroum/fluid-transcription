from __future__ import annotations

from enum import IntEnum


class ExitCode(IntEnum):
    SUCCESS = 0
    INVALID_ARGUMENTS = 2
    INPUT_ERROR = 3
    ENGINE_FAILURE = 4
    MERGE_FAILURE = 5
    VALIDATION_FAILURE = 6


class CLIError(RuntimeError):
    def __init__(self, message: str, exit_code: ExitCode, details: dict | None = None):
        super().__init__(message)
        self.message = message
        self.exit_code = exit_code
        self.details = details or {}

    def to_dict(self) -> dict:
        return {
            "error": self.message,
            "exit_code": int(self.exit_code),
            "details": self.details,
        }
