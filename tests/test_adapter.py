import json
import tempfile
import unittest
from pathlib import Path

from fluid_transcription.adapter import FluidAudioAdapter


class FluidAudioAdapterTests(unittest.TestCase):
    def test_probe_prefers_bundled_engine(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            bundle_dir = root / "fluidaudio"
            binary_path = bundle_dir / "bin" / "fluidaudiocli"
            manifest_path = bundle_dir / "manifest.json"
            binary_path.parent.mkdir(parents=True)
            binary_path.write_text("#!/bin/sh\necho ok\n", encoding="utf-8")
            binary_path.chmod(0o755)
            manifest_path.write_text(
                json.dumps(
                    {
                        "repository": "FluidInference/FluidAudio",
                        "tag": "v0.13.6",
                        "binary_name": "fluidaudiocli",
                        "status": "staged",
                    }
                ),
                encoding="utf-8",
            )

            adapter = FluidAudioAdapter(bundled_engine_path=str(binary_path), vendored_repo_path=str(root / "vendor"))
            probe = adapter.probe()

            self.assertTrue(probe.available)
            self.assertEqual(probe.source, "bundled")
            self.assertEqual(probe.command, [str(binary_path.resolve())])
            self.assertEqual(probe.manifest["tag"], "v0.13.6")
