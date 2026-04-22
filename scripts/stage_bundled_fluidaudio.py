from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
LOCK_PATH = REPO_ROOT / "fluidaudio.lock.json"
BUNDLE_ROOT = REPO_ROOT / "src" / "fluid_transcription" / "bundled" / "fluidaudio"
ENGINE_PATH = BUNDLE_ROOT / "bin" / "fluidaudiocli"
MANIFEST_PATH = BUNDLE_ROOT / "manifest.json"


def load_lock() -> dict:
    return json.loads(LOCK_PATH.read_text(encoding="utf-8"))


def stage_engine(engine_binary: Path, tag: str | None) -> dict:
    lock = load_lock()
    BUNDLE_ROOT.mkdir(parents=True, exist_ok=True)
    ENGINE_PATH.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(engine_binary, ENGINE_PATH)
    ENGINE_PATH.chmod(ENGINE_PATH.stat().st_mode | 0o111)

    manifest = {
        "repository": lock["repository"],
        "tag": tag or lock["tag"],
        "binary_name": lock["binary_name"],
        "status": "staged",
        "engine_path": str(ENGINE_PATH.relative_to(REPO_ROOT)),
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--engine-binary", required=True)
    parser.add_argument("--tag")
    args = parser.parse_args(argv)

    engine_binary = Path(args.engine_binary).expanduser().resolve()
    if not engine_binary.exists():
        raise FileNotFoundError(f"Engine binary not found: {engine_binary}")

    print(json.dumps(stage_engine(engine_binary, args.tag), indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
