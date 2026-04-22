import unittest

from fluid_transcription.merge import align_segments
from fluid_transcription.models import SpeakerTurn, TranscriptSegment


class AlignSegmentsTests(unittest.TestCase):
    def test_assigns_speaker_with_max_overlap(self) -> None:
        segments = [
            TranscriptSegment(segment_id="seg-1", text="hello", start_sec=0.0, end_sec=2.0),
            TranscriptSegment(segment_id="seg-2", text="world", start_sec=2.1, end_sec=4.0),
        ]
        turns = [
            SpeakerTurn(turn_id="turn-1", speaker_id="SPEAKER_00", start_sec=0.0, end_sec=1.0),
            SpeakerTurn(turn_id="turn-2", speaker_id="SPEAKER_01", start_sec=1.0, end_sec=4.0),
        ]

        utterances = align_segments(segments, turns)

        self.assertEqual(utterances[0].speaker_id, "SPEAKER_00")
        self.assertEqual(utterances[1].speaker_id, "SPEAKER_01")

    def test_leaves_speaker_null_without_timestamps(self) -> None:
        segments = [TranscriptSegment(segment_id="seg-1", text="hello")]
        turns = [SpeakerTurn(turn_id="turn-1", speaker_id="SPEAKER_00", start_sec=0.0, end_sec=1.0)]

        utterances = align_segments(segments, turns)

        self.assertIsNone(utterances[0].speaker_id)
