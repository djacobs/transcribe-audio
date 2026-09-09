# transcribe-audio

Transcribe audio files using macOS native speech recognition (SFSpeechRecognizer).

## When to use

Use this skill when you need to extract text from audio files on macOS:
- Transcribe interviews, calls, or meetings
- Convert video soundtracks to text
- Extract speech from any audio format macOS can read (MP3, WAV, QuickTime, etc.)

The skill uses Apple's built-in speech recognition engine, which works offline and requires no external API keys or subscriptions.

## How it works

The skill uses macOS native `SFSpeechRecognizer` framework through a Swift script. It:
- Reads audio files directly without requiring format conversion
- Streams recognition results for long audio files
- Returns full transcript as plain text
- Times out after 15 minutes of processing
- Provides error messages via stderr

## Usage

### Command line

```bash
transcribe <audio-file-path>                    # Output to stdout
transcribe <audio-file-path> output.txt         # Save to file
```

### From Claude Code

When invoked as a skill, the agent runs the transcriber on the specified file:

```bash
cd ~/Documents/GitHub/transcribe-audio
./transcribe /path/to/audio.mp3
```

### In a Script

```bash
TRANSCRIPT=$(cd ~/Documents/GitHub/transcribe-audio && ./transcribe /path/to/audio.mov)
echo "$TRANSCRIPT"
```

## Supported formats

The script accepts any audio format that macOS and AVFoundation can read:
- MP3 (.mp3)
- WAV (.wav)
- AIFF (.aiff, .aif)
- QuickTime (.mov, .mp4, .m4a)
- FLAC (.flac)
- And most other common audio formats

## Limitations

- **Accuracy depends on audio quality.** Clear audio with minimal background noise transcribes best.
- **Language:** Currently set to English (US). Modify the locale in `transcribe.swift` line 15 to support other languages (e.g., `es-ES` for Spanish).
- **Timeout:** Processing stops after 15 minutes. For longer files, split them first or extend the timeout.
- **Authorization:** First run may prompt for microphone/speech recognition permissions (required by macOS security model).
- **Performance:** Transcription speed depends on audio length and system resources. As a baseline, 10 minutes of audio takes 2–5 minutes to transcribe.

## Examples

### Transcribe a video demo

```bash
cd ~/Documents/GitHub/transcribe-audio
./transcribe ~/Movies/demo.mov > ~/demo_transcript.txt
```

### Extract audio from video, then transcribe

```bash
# Extract audio with ffmpeg
ffmpeg -i input.mov -q:a 9 -n audio.mp3

# Transcribe
cd ~/Documents/GitHub/transcribe-audio
./transcribe audio.mp3
```

### Use in a Claude Code agent flow

The agent can invoke the skill to transcribe files:

```bash
# Extract audio (if needed)
ffmpeg -i video.mov -f mp3 /tmp/audio.mp3

# Transcribe
cd ~/Documents/GitHub/transcribe-audio && ./transcribe /tmp/audio.mp3 > /tmp/transcript.txt

# Read and process the transcript
cat /tmp/transcript.txt
```

## Troubleshooting

### "Speech recognizer not available"

This error means speech recognition is not available for the English-US locale on your system. Check System Preferences > Privacy & Security > Speech Recognition.

### "Speech recognition authorization denied"

Microphone or speech recognition access was denied. Grant permission in System Preferences > Privacy & Security and try again.

### "File not found"

Verify the file path is correct and the file exists:
```bash
ls -lh /path/to/audio.mp3
```

### "Transcription timed out"

The audio file exceeded 15 minutes of processing. Large files may require extra time. Try:
1. Split the audio into shorter segments
2. Extend the timeout in `transcribe.swift` (change `900` to a larger value)
3. Reduce audio quality/sample rate first with ffmpeg

### Output is empty or partial

This usually means the audio quality is too poor or the format is unsupported. Try:
1. Verify the file is a valid audio file: `file audio.mp3`
2. Check audio levels are not too quiet: `ffmpeg -i audio.mp3 -af volumedetect -f null -`
3. Try a different format (convert to MP3 or WAV with ffmpeg)

## Files

- **transcribe** — Bash wrapper script (the entry point)
- **transcribe.swift** — Swift implementation using SFSpeechRecognizer
- **SKILL.md** — This file

## Future improvements

- Support for batch processing (transcribe multiple files)
- Language auto-detection
- Confidence scores and word-level timestamps
- Integration with Claude for automatic post-processing (grammar, punctuation)
- Progress reporting for long files
