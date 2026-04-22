import json
import tempfile
import unittest
from pathlib import Path

from fluid_transcription.validate import validate_run_directory


class ValidateRunDirectoryTests(unittest.TestCase):
    def test_accepts_valid_transcript(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            run_dir = Path(temp_dir) / "job"
            run_dir.mkdir()
            (run_dir / "run.json").write_text(
                json.dumps(
                    {
                        "schema_version": "1.0.0-draft",
                        "artifacts": ["transcript.json"],
                    }
                ),
                encoding="utf-8",
            )
            (run_dir / "transcript.json").write_text(
                json.dumps(
                    {
                        "schema_version": "1.0.0-draft",
                        "segments": [
                            {
                                "segment_id": "seg-1",
                                "start_sec": None,
                                "end_sec": None,
                                "text": "hello",
                                "confidence": None,
                            }
                        ],
                    }
                ),
                encoding="utf-8",
            )

            report = validate_run_directory(run_dir)

            self.assertTrue(report["ok"])
            self.assertEqual(report["errors"], [])

    def test_rejects_negative_diarization_times(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            run_dir = Path(temp_dir) / "job"
            run_dir.mkdir()
            (run_dir / "run.json").write_text(
                json.dumps(
                    {
                        "schema_version": "1.0.0-draft",
                        "artifacts": ["diarization.json"],
                    }
                ),
                encoding="utf-8",
            )
            (run_dir / "diarization.json").write_text(
                json.dumps(
                    {
                        "schema_version": "1.0.0-draft",
                        "turns": [
                            {
                                "turn_id": "turn-1",
                                "speaker_id": "SPEAKER_00",
                                "start_sec": -1.0,
                                "end_sec": 2.0,
                            }
                        ],
                    }
                ),
                encoding="utf-8",
            )

            report = validate_run_directory(run_dir)

            self.assertFalse(report["ok"])
            self.assertIn("negative time", report["errors"][0])
