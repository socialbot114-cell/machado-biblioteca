import AVFoundation
import Foundation

final class SpeechReader: NSObject, ObservableObject {
    @Published private(set) var isSpeaking = false
    @Published private(set) var isPaused = false
    @Published private(set) var currentParagraphIndex = -1
    @Published private(set) var totalParagraphs = 0
    @Published private(set) var voices: [AVSpeechSynthesisVoice] = []
    @Published private(set) var selectedVoiceName = ""
    @Published var rate = AVSpeechUtteranceDefaultSpeechRate
    private let synthesizer = AVSpeechSynthesizer()
    private var paragraphs: [String] = []
    private var nextParagraphIndex = 0
    private var currentUtterance: AVSpeechUtterance?

    override init() {
        super.init()
        synthesizer.delegate = self
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.allowBluetooth, .duckOthers])
        voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("pt-BR") }
        selectedVoiceName = UserDefaults.standard.string(forKey: "machado.voice") ?? voices.first?.name ?? "Voz padrão"
    }

    func speak(_ paragraphs: [String], startAt: Int = 0) {
        stop()
        self.paragraphs = paragraphs
        totalParagraphs = paragraphs.count
        nextParagraphIndex = min(max(startAt, 0), max(paragraphs.count - 1, 0))
        speakNext()
    }

    func resume() {
        guard isPaused else { return }
        _ = synthesizer.continueSpeaking()
        isPaused = false
        isSpeaking = true
    }

    func pause() {
        guard synthesizer.pauseSpeaking(at: .immediate) else { return }
        isPaused = true
        isSpeaking = false
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        isPaused = false
        currentParagraphIndex = -1
        currentUtterance = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    func chooseVoice(_ voice: AVSpeechSynthesisVoice) {
        selectedVoiceName = voice.name
        UserDefaults.standard.set(voice.name, forKey: "machado.voice")
        if isSpeaking || isPaused {
            let index = max(currentParagraphIndex, 0)
            speak(paragraphs, startAt: index)
        }
    }

    func next() {
        guard !paragraphs.isEmpty else { return }
        let current = currentParagraphIndex
        stop()
        nextParagraphIndex = min(max(current + 1, 0), paragraphs.count - 1)
        speakNext()
    }

    func previous() {
        guard !paragraphs.isEmpty else { return }
        let current = currentParagraphIndex
        stop()
        nextParagraphIndex = max(current - 1, 0)
        speakNext()
    }

    private func speakNext() {
        guard paragraphs.indices.contains(nextParagraphIndex) else {
            stop()
            return
        }
        let text = paragraphs[nextParagraphIndex]
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voices.first { $0.name == selectedVoiceName } ?? AVSpeechSynthesisVoice(language: "pt-BR")
        utterance.rate = rate
        currentUtterance = utterance
        try? AVAudioSession.sharedInstance().setActive(true)
        synthesizer.speak(utterance)
    }
}

extension SpeechReader: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        isSpeaking = true
        isPaused = false
        currentParagraphIndex = nextParagraphIndex
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard utterance === currentUtterance else { return }
        nextParagraphIndex += 1
        if nextParagraphIndex < paragraphs.count {
            speakNext()
        } else {
            isSpeaking = false
            currentParagraphIndex = -1
            try? AVAudioSession.sharedInstance().setActive(false)
        }
    }
}
