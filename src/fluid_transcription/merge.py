from __future__ import annotations

from fluid_transcription import SCHEMA_VERSION
from fluid_transcription.models import SpeakerTurn, TranscriptSegment, Utterance


def combine_artifacts(job_id: str, input_path: str, transcript: dict, diarization: dict) -> dict:
    transcript_segments = [_segment_from_dict(item) for item in transcript.get("segments", [])]
    diarization_turns = [_turn_from_dict(item) for item in diarization.get("turns", [])]
    utterances = [utterance.to_dict() for utterance in align_segments(transcript_segments, diarization_turns)]

    if utterances and any(item["speaker_id"] is None for item in utterances):
        merge_notes = [
            "Transcript segments do not yet include reliable timestamps from FluidAudio CLI stdout.",
            "Utterances with null speaker_id require improved upstream transcript timing integration.",
        ]
    else:
        merge_notes = []

    return {
        "schema_version": SCHEMA_VERSION,
        "job_id": job_id,
        "input": input_path,
        "summary": {
            "duration_sec": diarization.get("duration_sec"),
            "speaker_count": len(diarization.get("speakers", [])),
            "segment_count": len(transcript_segments),
        },
        "utterances": utterances,
        "notes": merge_notes,
    }


def build_markdown(combined: dict) -> str:
    lines = [f"# Fluid Transcription {combined['job_id']}", ""]
    for utterance in combined.get("utterances", []):
        speaker = utterance.get("speaker_id") or "UNKNOWN"
        start_sec = utterance.get("start_sec")
        end_sec = utterance.get("end_sec")
        if start_sec is None or end_sec is None:
            lines.append(f"## {speaker}")
        else:
            lines.append(f"## {speaker} [{start_sec:.2f}s - {end_sec:.2f}s]")
        lines.append(utterance.get("text", ""))
        lines.append("")
    return "\n".join(lines).strip() + "\n"


def align_segments(
    transcript_segments: list[TranscriptSegment],
    diarization_turns: list[SpeakerTurn],
) -> list[Utterance]:
    utterances: list[Utterance] = []
    for index, segment in enumerate(transcript_segments, start=1):
        speaker_id = _best_matching_speaker(segment, diarization_turns)
        utterances.append(
            Utterance(
                utterance_id=f"utt-{index:04d}",
                speaker_id=speaker_id,
                start_sec=segment.start_sec,
                end_sec=segment.end_sec,
                text=segment.text,
                source_segment_ids=[segment.segment_id],
            )
        )
    return utterances


def _best_matching_speaker(segment: TranscriptSegment, turns: list[SpeakerTurn]) -> str | None:
    if segment.start_sec is None or segment.end_sec is None:
        return None

    best_speaker: str | None = None
    best_overlap = 0.0
    for turn in turns:
        overlap = _overlap(segment.start_sec, segment.end_sec, turn.start_sec, turn.end_sec)
        if overlap > best_overlap:
            best_overlap = overlap
            best_speaker = turn.speaker_id
    return best_speaker or "UNKNOWN"


def _overlap(a_start: float, a_end: float, b_start: float, b_end: float) -> float:
    return max(0.0, min(a_end, b_end) - max(a_start, b_start))


def _segment_from_dict(item: dict) -> TranscriptSegment:
    return TranscriptSegment(
        segment_id=str(item.get("segment_id")),
        text=str(item.get("text", "")),
        start_sec=item.get("start_sec"),
        end_sec=item.get("end_sec"),
        confidence=item.get("confidence"),
    )


def _turn_from_dict(item: dict) -> SpeakerTurn:
    return SpeakerTurn(
        turn_id=str(item.get("turn_id")),
        speaker_id=str(item.get("speaker_id")),
        start_sec=float(item.get("start_sec", 0.0)),
        end_sec=float(item.get("end_sec", 0.0)),
    )
