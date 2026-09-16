# transcribe-audio

Transcribe audio files using macOS native speech recognition (`SpeechAnalyzer` on macOS 26+,
`SFSpeechRecognizer` below).

## When to use

Use this skill when you need to extract text from audio files on macOS:
- Transcribe interviews, calls, or meetings
- Convert video soundtracks to text
- Extract speech from any audio format macOS can read (MP3, WAV, QuickTime, etc.)

The skill uses Apple's built-in speech recognition engine, which works offline and requires no external API keys or subscriptions.

## How it works

On **macOS 26 and later** the skill uses Apple's `SpeechAnalyzer` / `SpeechTranscriber`. It:
- Reads audio files directly without requiring format conversion
- Runs fully on-device
- Transcribes at roughly **40–55x realtime** (a 174-minute recording took 190 seconds)
- Handles multi-hour files **in a single pass**, peaking around 200 MB of memory
- Carries **per-phrase timestamps**, so it can emit WebVTT or SubRip
- Reports progress to stderr as it goes

On **macOS 25 and earlier** it falls back to `SFSpeechRecognizer`, which returns plain text only
(`--vtt` and `--srt` are rejected with an error) and keeps the original 15-minute timeout.

### Why the fallback exists

`SFSpeechRecognizer`'s file-based recognition (`SFSpeechURLRecognitionRequest`) **does not work on
macOS 26**. Measured on 26.6.2: the recognizer reports `isAvailable = true`,
`supportsOnDeviceRecognition = true`, and authorization succeeds — then the recognition task never
fires a callback. A 60-second clip produced zero output and zero partial results after 120 seconds at
3% CPU, with and without `requiresOnDeviceRecognition = true`, for both MP3 and 16 kHz mono WAV
input. It is not slow; it never starts. That silent stall is the reason for the rewrite.

## Usage

### Command line

```bash
transcribe <audio-file-path>                       # plain text to stdout
transcribe <audio-file-path> output.txt            # plain text to a file
transcribe <audio-file-path> out.vtt --vtt         # WebVTT with timestamps
transcribe <audio-file-path> out.srt --srt         # SubRip with timestamps
transcribe <audio-file-path> --locale en-GB        # another locale
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
- **Language:** defaults to English (US). Pass `--locale` for another (e.g. `--locale es-ES`).
  `SpeechTranscriber.supportedLocales` lists what the system can do; `installedLocales` lists what is
  already downloaded.
- **Timeout:** only applies to the pre-macOS-26 fallback path, which stops after 15 minutes. The
  `SpeechAnalyzer` path has no timeout and does not need one.
- **Timestamps:** `--vtt` and `--srt` require macOS 26 or later.
- **Authorization:** First run may prompt for microphone/speech recognition permissions (required by macOS security model).
- **Performance:** on macOS 26+, roughly 40–55x realtime — 10 minutes of audio in 10–15 seconds,
  and a 174-minute recording in about 190 seconds. The pre-26 fallback is far slower.

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

Only the pre-macOS-26 fallback can time out. If you see this on macOS 26 or later, the build is not
taking the `SpeechAnalyzer` path — check `swift --version` and `sw_vers -productVersion`.

### Nothing happens at all, at ~3% CPU

That is the `SFSpeechRecognizer` stall described under "Why the fallback exists". It cannot be waited
out: the task never fires a callback. On macOS 26+ this path should not be reached.

### Output is empty or partial

This usually means the audio quality is too poor or the format is unsupported. Try:
1. Verify the file is a valid audio file: `file audio.mp3`
2. Check audio levels are not too quiet: `ffmpeg -i audio.mp3 -af volumedetect -f null -`
3. Try a different format (convert to MP3 or WAV with ffmpeg)

## Files

- **transcribe** — Bash wrapper script (the entry point)
- **transcribe.swift** — Swift implementation (`SpeechAnalyzer`, with an `SFSpeechRecognizer` fallback)
- **SKILL.md** — This file

## Future improvements

- Support for batch processing (transcribe multiple files)
- Language auto-detection
- Confidence scores and **word**-level timestamps (phrase-level shipped)
- Integration with Claude for automatic post-processing (grammar, punctuation)
- Speaker diarization
