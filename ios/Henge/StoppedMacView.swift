import SwiftUI

/// Terminal state after the engine has released the previous guest.
struct StoppedMacView: View {
    let outcome: Int32
    let reason: String
    var start: (() -> Void)? = nil
    let close: () -> Void

    private var title: String {
        switch outcome {
        case Int32(HENGE_VM_OUTCOME_SHUTDOWN.rawValue): return "Mac ausgeschaltet"
        case Int32(HENGE_VM_OUTCOME_RESTART.rawValue): return "Mac möchte neu starten"
        case Int32(HENGE_VM_OUTCOME_HOST_STOP.rawValue): return "Mac gestoppt"
        default: return "Mac unerwartet gestoppt"
        }
    }

    private var detail: String {
        let next = "Du kannst diesen Mac neu starten oder zu deinen Macs zurückkehren."
        switch outcome {
        case Int32(HENGE_VM_OUTCOME_SHUTDOWN.rawValue), Int32(HENGE_VM_OUTCOME_HOST_STOP.rawValue): return next
        case Int32(HENGE_VM_OUTCOME_RESTART.rawValue): return "Der Mac ist bereit für einen Neustart."
        default: return "Der Mac wurde gestoppt: \(reason). " + next
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "power").font(.system(size: 30))
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            if let start { Button("Mac starten", action: start).buttonStyle(.borderedProminent) }
            Button("Schließen", action: close).buttonStyle(.bordered)
        }
        .foregroundStyle(.white)
        .padding(24)
        .frame(maxWidth: 360)
        .background(Color(white: 0.10), in: RoundedRectangle(cornerRadius: 22))
        .accessibilityIdentifier("stopped-mac")
    }
}
