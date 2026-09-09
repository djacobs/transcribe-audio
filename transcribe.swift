import Foundation
import Speech
import AVFoundation

// Get file path from command line arguments
guard CommandLine.arguments.count > 1 else {
    fputs("Usage: swift transcribe.swift <audio-file-path>\n", stderr)
    exit(1)
}

let audioPath = CommandLine.arguments[1]
let audioURL = URL(fileURLWithPath: audioPath)

// Verify file exists
guard FileManager.default.fileExists(atPath: audioPath) else {
    fputs("Error: File not found: \(audioPath)\n", stderr)
    exit(1)
}

// Create speech recognizer
guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) else {
    fputs("Error: Speech recognizer not available\n", stderr)
    exit(1)
}

// Request authorization
var authStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
let authSemaphore = DispatchSemaphore(value: 0)

SFSpeechRecognizer.requestAuthorization { status in
    authStatus = status
    authSemaphore.signal()
}

_ = authSemaphore.wait(timeout: .now() + 5)

switch authStatus {
case .authorized:
    break
case .denied:
    fputs("Error: Speech recognition authorization denied\n", stderr)
    exit(1)
case .restricted:
    fputs("Error: Speech recognition restricted\n", stderr)
    exit(1)
case .notDetermined:
    fputs("Error: Speech recognition authorization not determined\n", stderr)
    exit(1)
@unknown default:
    fputs("Error: Unknown authorization status\n", stderr)
    exit(1)
}

// Create recognition request
let request = SFSpeechURLRecognitionRequest(url: audioURL)
request.shouldReportPartialResults = false

var transcript = ""
let resultSemaphore = DispatchSemaphore(value: 0)

let task = recognizer.recognitionTask(with: request) { result, error in
    if let error = error {
        fputs("Error: \(error.localizedDescription)\n", stderr)
        resultSemaphore.signal()
        return
    }

    if let result = result {
        transcript = result.bestTranscription.formattedString
        if result.isFinal {
            print(transcript)
            resultSemaphore.signal()
        }
    }
}

// Wait for completion with 15-minute timeout
let timeout = DispatchTime.now() + .seconds(900)
let waitResult = resultSemaphore.wait(timeout: timeout)

if waitResult == .timedOut {
    fputs("Warning: Transcription timed out after 15 minutes\n", stderr)
    if !transcript.isEmpty {
        print(transcript)
    }
    task.cancel()
    exit(transcript.isEmpty ? 1 : 0)
}

task.cancel()
exit(transcript.isEmpty ? 1 : 0)
