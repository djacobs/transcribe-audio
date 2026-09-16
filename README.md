# macOS Audio Transcription Skill

A simple, offline audio transcription tool using macOS native speech recognition.

## Quick start

```bash
cd ~/Documents/GitHub/transcribe-audio
./transcribe /path/to/audio.mp3
```

## What's included

- **transcribe** — Command-line wrapper
- **transcribe.swift** — macOS native speech recognition implementation
- **SKILL.md** — Full documentation and usage guide

## Key features

✓ Works offline (no API keys or internet required)  
✓ Supports MP3, WAV, MOV, M4A, and most audio formats  
✓ **Fast: ~40–55x realtime** — a 174-minute recording transcribes in about 3 minutes  
✓ **Timestamped output** — `--vtt` and `--srt`, not just plain text  
✓ **Handles multi-hour files in one pass**, with a ~200 MB memory ceiling  
✓ Simple: single file, no dependencies beyond macOS built-ins  
✓ Uses Apple's `SpeechAnalyzer` on macOS 26+, falling back to `SFSpeechRecognizer` below  

## Examples

Transcribe to stdout:
```bash
./transcribe demo.mp3
```

Save to file:
```bash
./transcribe demo.mp3 transcript.txt
```

Timestamped subtitles:
```bash
./transcribe demo.mp3 demo.vtt --vtt
./transcribe demo.mp3 demo.srt --srt
```

Extract audio from video first:
```bash
ffmpeg -i video.mov -f mp3 audio.mp3 && ./transcribe audio.mp3
```

## See SKILL.md for full documentation

- Supported formats
- Troubleshooting guide
- Language support
- Integration with scripts and Claude Code
