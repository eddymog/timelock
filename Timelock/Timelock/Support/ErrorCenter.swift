import Foundation
import Observation
import SwiftUI

struct AppError: Identifiable {
    let id = UUID()
    let message: String
}

/// Collects failures so the UI can show them instead of swallowing them.
@Observable
final class ErrorCenter {
    private(set) var current: AppError?

    func report(_ error: Error, while what: String) {
        current = AppError(message: "\(what) failed: \(error.localizedDescription)")
    }

    func dismiss() {
        current = nil
    }

    /// Runs `body`, reporting any thrown error. Returns whether it succeeded.
    @discardableResult
    func perform(_ what: String, _ body: () throws -> Void) -> Bool {
        do {
            try body()
            return true
        } catch {
            report(error, while: what)
            return false
        }
    }
}

private struct ErrorAlert: ViewModifier {
    let errors: ErrorCenter

    func body(content: Content) -> some View {
        content.alert(
            "Something went wrong",
            isPresented: Binding(get: { errors.current != nil }, set: { if !$0 { errors.dismiss() } }),
            presenting: errors.current
        ) { _ in
            Button("OK") { errors.dismiss() }
        } message: { error in
            Text(error.message)
        }
    }
}

extension View {
    func errorAlert(_ errors: ErrorCenter) -> some View {
        modifier(ErrorAlert(errors: errors))
    }
}
