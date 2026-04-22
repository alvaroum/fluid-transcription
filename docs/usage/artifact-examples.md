# Artifact Examples

This page shows representative artifact shapes so downstream consumers can understand the contract without first running the CLI.

Examples below are intentionally shortened and sanitized.

## `run.json`

```json
{
  "schema_version": "1.0.0-draft",
  "job_id": "meeting-a1b2c3d4e5f6",
  "mode": "process",
  "input": "/path/to/meeting.m4a",
  "run_dir": "/path/to/runs/meeting-a1b2c3d4e5f6",
  "created_at": "2026-04-22T10:52:30Z",
  "status": "completed",
  "artifacts": [
    "transcript.json",
    "diarization.json",
    "combined.json",
    "events.jsonl"
  ]
}
```

## `events.jsonl`

```json
{"event":"job_started","timestamp":"2026-04-22T10:52:30Z","details":{"mode":"process"}}
{"event":"input_prepared","timestamp":"2026-04-22T10:52:30Z","details":{"strategy":"avfoundation"}}
{"event":"artifact_written","timestamp":"2026-04-22T10:53:35Z","details":{"artifact":"transcript.json"}}
{"event":"job_completed","timestamp":"2026-04-22T10:53:35Z","details":{"status":"completed"}}
```

## `transcript.json`

```json
{
  "schema_version": "1.0.0-draft",
  "job_id": "meeting-a1b2c3d4e5f6",
  "input": "/path/to/meeting.m4a",
  "language": "auto",
  "tool_versions": {
    "appVersion": "0.2.0",
    "fluidAudioVersion": "0.13.6"
  },
  "segments": [
    {
      "segment_id": "seg-0001",
      "text": "Example transcript text...",
      "confidence": 0.93
    }
  ],
  "full_text": "Example transcript text...",
  "notes": [
    "ASR models are downloaded automatically on first use and cached by FluidAudio.",
    "Initial Swift CLI integration emits a single transcript segment until richer ASR timing extraction is added."
  ]
}
```

## `diarization.json`

```json
{
  "schema_version": "1.0.0-draft",
  "job_id": "meeting-a1b2c3d4e5f6",
  "input": "/path/to/meeting.m4a",
  "duration_sec": 321.4,
  "tool_versions": {
    "appVersion": "0.2.0",
    "fluidAudioVersion": "0.13.6"
  },
  "speakers": [
    {
      "speaker_id": "S1",
      "total_talk_sec": 180.2
    },
    {
      "speaker_id": "S2",
      "total_talk_sec": 141.2
    }
  ],
  "turns": [
    {
      "turn_id": "turn-0001",
      "speaker_id": "S1",
      "start_sec": 0.0,
      "end_sec": 4.2
    }
  ]
}
```

## `combined.json`

```json
{
  "schema_version": "1.0.0-draft",
  "job_id": "meeting-a1b2c3d4e5f6",
  "input": "/path/to/meeting.m4a",
  "tool_versions": {
    "appVersion": "0.2.0",
    "fluidAudioVersion": "0.13.6"
  },
  "summary": {
    "duration_sec": 321.4,
    "speaker_count": 2,
    "segment_count": 1
  },
  "transcript_full_text": "Example transcript text...",
  "speaker_turns": [
    {
      "turn_id": "turn-0001",
      "speaker_id": "S1",
      "start_sec": 0.0,
      "end_sec": 4.2
    }
  ],
  "notes": [
    "The `process` command runs transcription and diarization in one pass at the app level.",
    "Transcript-to-speaker alignment is deferred until timestamp-rich ASR segmentation is added."
  ]
}
```

## `combined.md`

```md
# Fluid Transcription meeting-a1b2c3d4e5f6

## Transcript
Example transcript text...

## Speaker Turns
- S1 [0.00s - 4.20s]
```

## Consumer Advice

- Treat `combined.md` as a convenience artifact, not the canonical integration target.
- Use JSON artifacts for machine workflows.
- Expect the draft schema to evolve while the CLI surface is still settling.