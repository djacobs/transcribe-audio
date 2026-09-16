import Foundation
import Speech
import AVFoundation

// transcribe <audio-file> [--vtt|--srt|--text] [--locale en-US]
//
// macOS 26 and later use SpeechAnalyzer / SpeechTranscriber, which is on-device,
// handles multi-hour files in one pass, and carries per-phrase timestamps.
// Earlier systems fall back to SFSpeechRecognizer, which returns plain text only.

enum Format: String { case text, vtt, srt }

struct Options {
    var path: String
    var format: Format = .text
    var locale: String = "en-US"
}

func parseArgs() -> Options {
    let args = Array(CommandLine.arguments.dropFirst())
    guard !args.isEmpty else {
        fputs("""
        Usage: transcribe <audio-file-path> [--vtt|--srt|--text] [--locale en-US]

          --text    plain transcript (default)
          --vtt     WebVTT with timestamps   (macOS 26+)
          --srt     SubRip with timestamps   (macOS 26+)

        """, stderr)
        exit(1)
    }
    var o = Options(path: "")
    var i = 0
    while i < args.count {
        switch args[i] {
        case "--vtt":    o.format = .vtt
        case "--srt":    o.format = .srt
        case "--text":   o.format = .text
        case "--locale":
            i += 1
            guard i < args.count else { fputs("Error: --locale needs a value\n", stderr); exit(1) }
            o.locale = args[i]
        default:
            if args[i].hasPrefix("--") { fputs("Error: unknown option \(args[i])\n", stderr); exit(1) }
            o.path = args[i]
        }
        i += 1
    }
    guard !o.path.isEmpty else { fputs("Error: no audio file given\n", stderr); exit(1) }
    guard FileManager.default.fileExists(atPath: o.path) else {
        fputs("Error: File not found: \(o.path)\n", stderr); exit(1)
    }
    return o
}

func stamp(_ s: Double, comma: Bool = false) -> String {
    let h = Int(s) / 3600, m = (Int(s) % 3600) / 60
    let sec = s - Double(h * 3600 + m * 60)
    let str = String(format: "%02d:%02d:%06.3f", h, m, sec)
    return comma ? str.replacingOccurrences(of: ".", with: ",") : str
}

// MARK: - macOS 26+ : SpeechAnalyzer

@available(macOS 26.0, *)
func transcribeModern(_ o: Options) async throws {
    let transcriber = SpeechTranscriber(
        locale: Locale(identifier: o.locale),
        transcriptionOptions: [],
        reportingOptions: [],
        attributeOptions: [.audioTimeRange]
    )
    let analyzer = SpeechAnalyzer(modules: [transcriber])
    let file = try AVAudioFile(forReading: URL(fileURLWithPath: o.path))
    let duration = Double(file.length) / file.fileFormat.sampleRate
    let started = Date()

    var out = o.format == .vtt ? "WEBVTT\n\n" : ""
    var index = 0

    let collector = Task { () -> Int in
        for try await result in transcriber.results {
            let text = result.text
            var lo = Double.infinity, hi = -Double.infinity
            for run in text.runs {
                if let range = run.audioTimeRange {
                    lo = min(lo, range.start.seconds)
                    hi = max(hi, range.end.seconds)
                }
            }
            let line = String(text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            switch o.format {
            case .text:
                out += line + " "
            case .vtt:
                guard lo.isFinite, hi > lo else { continue }
                out += "\(stamp(lo)) --> \(stamp(hi))\n\(line)\n\n"
            case .srt:
                guard lo.isFinite, hi > lo else { continue }
                index += 1
                out += "\(index)\n\(stamp(lo, comma: true)) --> \(stamp(hi, comma: true))\n\(line)\n\n"
            }

            if hi.isFinite && duration > 0 && Int(hi) % 600 < 2 {
                fputs(String(format: "  … %.0f%% (%.0fs elapsed)\n",
                             100 * hi / duration, Date().timeIntervalSince(started)), stderr)
            }
        }
        return index
    }

    _ = try await analyzer.analyzeSequence(from: file)
    try await analyzer.finalizeAndFinishThroughEndOfInput()
    _ = try await collector.value

    print(out.trimmingCharacters(in: .whitespacesAndNewlines))
    let elapsed = Date().timeIntervalSince(started)
    fputs(String(format: "Transcribed %.1f min of audio in %.1fs (%.0fx realtime)\n",
                 duration / 60, elapsed, elapsed > 0 ? duration / elapsed : 0), stderr)
}

// MARK: - macOS 25 and earlier : SFSpeechRecognizer

func transcribeLegacy(_ o: Options) {
    if o.format != .text {
        fputs("Error: --vtt and --srt need macOS 26 or later (timestamps come from SpeechAnalyzer).\n", stderr)
        exit(1)
    }
    guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: o.locale)) else {
        fputs("Error: Speech recognizer not available for \(o.locale)\n", stderr); exit(1)
    }

    var auth: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    let authDone = DispatchSemaphore(value: 0)
    SFSpeechRecognizer.requestAuthorization { auth = $0; authDone.signal() }
    _ = authDone.wait(timeout: .now() + 10)
    guard auth == .authorized else {
        fputs("Error: speech recognition not authorized (status \(auth.rawValue)). "
            + "Grant it in System Settings > Privacy & Security > Speech Recognition.\n", stderr)
        exit(1)
    }

    let request = SFSpeechURLRecognitionRequest(url: URL(fileURLWithPath: o.path))
    request.shouldReportPartialResults = false
    if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }

    var transcript = ""
    let done = DispatchSemaphore(value: 0)
    let task = recognizer.recognitionTask(with: request) { result, error in
        if let error {
            fputs("Error: \(error.localizedDescription)\n", stderr); done.signal(); return
        }
        if let result {
            transcript = result.bestTranscription.formattedString
            if result.isFinal { done.signal() }
        }
    }
    if done.wait(timeout: .now() + 900) == .timedOut {
        fputs("Warning: timed out after 15 minutes.\n", stderr)
        task.cancel()
        if transcript.isEmpty { exit(1) }
    }
    task.cancel()
    guard !transcript.isEmpty else { fputs("Error: empty transcript\n", stderr); exit(1) }
    print(transcript)
}

// MARK: - main

let options = parseArgs()
if #available(macOS 26.0, *) {
    do { try await transcribeModern(options) }
    catch { fputs("Error: \(error)\n", stderr); exit(1) }
} else {
    transcribeLegacy(options)
}
