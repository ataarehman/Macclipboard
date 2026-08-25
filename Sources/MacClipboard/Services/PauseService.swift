import Foundation

enum PauseDuration: Equatable, Sendable {
    case minutes(Int)
    case indefinitely

    var title: String {
        switch self {
        case .minutes(5): "Pause for 5 minutes"
        case .minutes(15): "Pause for 15 minutes"
        case .minutes(60): "Pause for 1 hour"
        case .indefinitely: "Pause until resumed"
        case .minutes(let value): "Pause for \(value) minutes"
        }
    }
}

@MainActor
@Observable
final class PauseService {
    private(set) var pausedUntil: Date?
    private(set) var pausedIndefinitely = false
    private var resumeTask: Task<Void, Never>?

    var isPaused: Bool {
        if pausedIndefinitely { return true }
        if let pausedUntil { return pausedUntil > Date() }
        return false
    }

    var statusTitle: String {
        if pausedIndefinitely { return "Paused" }
        if let pausedUntil, pausedUntil > Date() {
            return "Paused until \(pausedUntil.formatted(date: .omitted, time: .shortened))"
        }
        return "Monitoring"
    }

    func pause(_ duration: PauseDuration) {
        resumeTask?.cancel()
        switch duration {
        case .indefinitely:
            pausedIndefinitely = true
            pausedUntil = nil
        case .minutes(let minutes):
            pausedIndefinitely = false
            let until = Date().addingTimeInterval(TimeInterval(minutes * 60))
            pausedUntil = until
            resumeTask = Task { [weak self] in
                let nanoseconds = UInt64(minutes) * 60_000_000_000
                try? await Task.sleep(nanoseconds: nanoseconds)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.resume()
                }
            }
        }
    }

    func resume() {
        resumeTask?.cancel()
        resumeTask = nil
        pausedUntil = nil
        pausedIndefinitely = false
    }
}
