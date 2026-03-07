final class SendableBox<T: Sendable>: @unchecked Sendable {
    private(set) var value: T
    init(_ value: T) { self.value = value }
    func set(_ newValue: T) { value = newValue }
}
