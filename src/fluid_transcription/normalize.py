from __future__ import annotations

from collections import defaultdict

from fluid_transcription import SCHEMA_VERSION
from fluid_transcription.models import SpeakerTurn, TranscriptSegment


def normalize_transcript(job_id: str, input_path: str, raw: dict) -> dict:
    text = raw.get("stdout", "").strip()
    segments = []
    if text:
        segments.append(TranscriptSegment(segment_id="seg-0001", text=text).to_dict())

    return {
        "schema_version": SCHEMA_VERSION,
        "job_id": job_id,
        "input": input_path,
        "language": "unknown",
        "duration_sec": None,
        "segments": segments,
        "full_text": text,
        "notes": [
            "Initial scaffold uses FluidAudio CLI stdout for transcription text.",
            "Timestamped transcript normalization will be tightened once upstream structured ASR output is integrated.",
        ],
    }


def normalize_diarization(job_id: str, input_path: str, raw: dict) -> dict:
    raw_payload = raw.get("json", {})
    turns = [_coerce_turn(item, index) for index, item in enumerate(_extract_segments(raw_payload), start=1)]
    speakers = defaultdict(float)
    for turn in turns:
        speakers[turn.speaker_id] += max(0.0, turn.end_sec - turn.start_sec)

    return {
        "schema_version": SCHEMA_VERSION,
        "job_id": job_id,
        "input": input_path,
        "duration_sec": _infer_duration(turns),
        "speakers": [
            {"speaker_id": speaker_id, "total_talk_sec": round(total_sec, 3)}
            for speaker_id, total_sec in sorted(speakers.items())
        ],
        "turns": [turn.to_dict() for turn in turns],
    }


def _extract_segments(payload: dict) -> list[dict]:
    if isinstance(payload.get("segments"), list):
        return payload["segments"]

    for key in ("timeline", "result", "data"):
        node = payload.get(key)
        if isinstance(node, dict) and isinstance(node.get("segments"), list):
            return node["segments"]

    return []


def _coerce_turn(item: dict, index: int) -> SpeakerTurn:
    speaker_id = str(item.get("speakerId") or item.get("speaker_id") or item.get("speaker") or f"SPEAKER_{index - 1:02d}")
    start_sec = float(item.get("startTimeSeconds") or item.get("start_sec") or item.get("start") or 0.0)
    end_sec = float(item.get("endTimeSeconds") or item.get("end_sec") or item.get("end") or start_sec)
    return SpeakerTurn(
        turn_id=f"turn-{index:04d}",
        speaker_id=speaker_id,
        start_sec=start_sec,
        end_sec=end_sec,
    )


def _infer_duration(turns: list[SpeakerTurn]) -> float | None:
    if not turns:
        return None
    return max(turn.end_sec for turn in turns)
