import Flutter

/// Thread-safe EventChannel sink wrapper for iOS.
/// Buffers events that arrive before Flutter calls onListen, then flushes them.
final class TwilioEventSink: NSObject, FlutterStreamHandler {

    private var eventSink: FlutterEventSink?
    private var pendingEvents: [[String: Any?]] = []

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        // Flush buffered events
        let toFlush = pendingEvents
        pendingEvents.removeAll()
        toFlush.forEach { events($0) }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    /// Sends an event map to Flutter. Always dispatches on main thread.
    /// If Flutter is not yet listening, buffers the event for later delivery.
    func send(_ event: [String: Any?]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let sink = self.eventSink {
                sink(event)
            } else {
                self.pendingEvents.append(event)
            }
        }
    }

    func sendError(code: String, message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(FlutterError(code: code, message: message, details: nil))
        }
    }
}
