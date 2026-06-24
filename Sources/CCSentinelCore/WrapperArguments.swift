public struct WrapperArguments: Equatable, Sendable {
    public var realClaudeBinary: String
    public var forwardedArguments: [String]

    public init(realClaudeBinary: String, forwardedArguments: [String]) {
        self.realClaudeBinary = realClaudeBinary
        self.forwardedArguments = forwardedArguments
    }

    public static func parse(_ arguments: [String]) -> WrapperArguments? {
        guard let binary = arguments.first, !binary.isEmpty else {
            return nil
        }
        return WrapperArguments(
            realClaudeBinary: binary,
            forwardedArguments: Array(arguments.dropFirst())
        )
    }
}
