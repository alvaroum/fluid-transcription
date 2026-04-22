from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path


@dataclass(slots=True)
class TranscriptSegment:
    segment_id: str
    text: str
    start_sec: float | None = None
    end_sec: float | None = None
    confidence: float | None = None

    def to_dict(self) -> dict:
        return {
            "segment_id": self.segment_id,
            "start_sec": self.start_sec,
            "end_sec": self.end_sec,
            "text": self.text,
            "confidence": self.confidence,
        }


@dataclass(slots=True)
class SpeakerTurn:
    turn_id: str
    speaker_id: str
    start_sec: float
    end_sec: float

    def to_dict(self) -> dict:
        return {
            "turn_id": self.turn_id,
            "speaker_id": self.speaker_id,
            "start_sec": self.start_sec,
            "end_sec": self.end_sec,
        }


@dataclass(slots=True)
class Utterance:
    utterance_id: str
    text: str
    source_segment_ids: list[str]
    speaker_id: str | None = None
    start_sec: float | None = None
    end_sec: float | None = None

    def to_dict(self) -> dict:
        return {
            "utterance_id": self.utterance_id,
            "speaker_id": self.speaker_id,
            "start_sec": self.start_sec,
            "end_sec": self.end_sec,
            "text": self.text,
            "source_segment_ids": self.source_segment_ids,
        }


@dataclass(slots=True)
class JobContext:
    job_id: str
    input_path: Path
    run_dir: Path
    created_at: str
    mode: str
    artifacts: list[str] = field(default_factory=list)
