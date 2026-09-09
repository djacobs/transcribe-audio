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
✓ Fast: transcribes 10 minutes of audio in 2–5 minutes  
✓ Simple: single file, no dependencies beyond macOS built-ins  
✓ Reliable: uses Apple's official SFSpeechRecognizer framework  

## Examples

Transcribe to stdout:
```bash
./transcribe demo.mp3
```

Save to file:
```bash
./transcribe demo.mp3 transcript.txt
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
