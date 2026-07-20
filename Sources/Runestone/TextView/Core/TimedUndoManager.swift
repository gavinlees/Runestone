import Foundation

final class TimedUndoManager: UndoManager {
    private let endGroupingInterval: TimeInterval = 1
    private var endGroupingTimer: Timer?
    private var hasOpenGroup: Bool {
        groupingLevel > 0
    }

    override init() {
        super.init()
        groupsByEvent = false
    }

    override func removeAllActions() {
        cancelTimer()
        super.removeAllActions()
    }

    override func beginUndoGrouping() {
        if !hasOpenGroup {
            super.beginUndoGrouping()
        }
        // Restart the inactivity timer on every edit so a continuous run of
        // keystrokes coalesces into a single undo group that closes only after a
        // pause. Previously the timer was scheduled just once — from the first
        // keystroke — so any typing slower than `endGroupingInterval` fragmented
        // into per-character undo steps.
        scheduleTimer()
    }

    override func endUndoGrouping() {
        cancelTimer()
        if hasOpenGroup {
            super.endUndoGrouping()
        }
    }

    override func undo() {
        endUndoGrouping()
        super.undo()
    }
}

private extension TimedUndoManager {
    private func scheduleTimer() {
        cancelTimer()
        let timer = Timer(timeInterval: endGroupingInterval, target: self, selector: #selector(timerDidTrigger), userInfo: nil, repeats: false)
        endGroupingTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func cancelTimer() {
        endGroupingTimer?.invalidate()
        endGroupingTimer = nil
    }

    @objc private func timerDidTrigger() {
        cancelTimer()
        endUndoGrouping()
    }
}
