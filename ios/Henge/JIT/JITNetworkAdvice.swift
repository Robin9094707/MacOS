// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation

/// What the current network path offers, copied from NWPath by the app so this file stays Foundation-only.
struct NetworkPathSnapshot: Equatable {
    var isSatisfied: Bool
    var usesWiFi: Bool
    var usesCellular: Bool
    var usesWired: Bool
}

enum NetworkSituation: Equatable {
    case wifi
    case cellularOnly
    case wired
    case offline

    init(_ path: NetworkPathSnapshot) {
        if !path.isSatisfied {
            self = .offline
        } else if path.usesWiFi {
            self = .wifi
        } else if path.usesWired {
            self = .wired
        } else {
            // A satisfied path with no known interface type is not the cellular case: it keeps the plain VPN advice.
            self = path.usesCellular ? .cellularOnly : .wifi
        }
    }
}

/// What the user can be offered to do next.
enum JITAdviceAction: Equatable {
    case connectLocalDevVPN
    case pairAgain
}

struct JITAdvice: Equatable {
    var message: String
    var actions: [JITAdviceAction]
}

/// Why the built-in helper could not reach this device, read from its error text.
enum JITConnectionProblem: Equatable {
    /// Nothing answered at LocalDevVPN's address: the VPN is off or not routing, or iOS sent the connection elsewhere.
    case unreachable
    /// The device closed the connection, usually because it no longer accepts
    /// this pairing (every new pairing replaces the last).
    case pairing

    init?(helperMessage: String) {
        let text = helperMessage.lowercased()
        let has = { (needles: [String]) in needles.contains(where: text.contains) }
        if has(["connectionreset", "connection reset", "device refused connection"]) {
            self = .pairing
        } else if has(["connectionrefused", "connection refused", "timedout", "timed out",
                       "networkunreachable", "network unreachable", "hostunreachable",
                       "host unreachable", "no route"]) {
            self = .unreachable
        } else {
            return nil
        }
    }
}

enum JITNetworkAdvice {
    static func advice(forHelperMessage helperMessage: String, situation: NetworkSituation) -> JITAdvice? {
        guard let problem = JITConnectionProblem(helperMessage: helperMessage) else { return nil }
        if problem == .pairing {
            return JITAdvice(
                message: "Dieses Gerät hat die Verbindung geschlossen. Meist heißt das, dass es die Kopplung "
                       + "nicht mehr annimmt. Kopple erneut und prüfe, ob LocalDevVPN verbunden ist.",
                actions: [.pairAgain, .connectLocalDevVPN])
        }
        guard situation == .cellularOnly else {
            return JITAdvice(message: "Simplex Mac konnte dieses Gerät nicht erreichen. Verbinde LocalDevVPN und versuche es erneut.",
                             actions: [.connectLocalDevVPN])
        }
        return JITAdvice(
            message: "LocalDevVPN kann „Verbunden“ zeigen, während iOS die Verbindung noch über Mobilfunk schickt. "
                   + "Schalte Mobile Daten im Kontrollzentrum aus, warte 2 Sekunden und schalte sie wieder ein. "
                   + "Oder verbinde dich einmal mit irgendeinem WLAN; ein Hotspot reicht. "
                   + "Lass LocalDevVPN verbunden, schalte andere VPNs wie Tailscale aus und versuche es erneut.",
            actions: [.connectLocalDevVPN])
    }
}

enum JITRetryDecision: Equatable {
    case retry(after: TimeInterval)
    case giveUp
}

/// Whether to try the helper again by itself after it failed to connect.
///
/// On cellular, iOS tends to send the first connection to 10.7.0.1 out over the mobile network instead of through
/// LocalDevVPN, and later ones go through. So an unreachable error on cellular is retried: at most 2 retries (3
/// attempts in all), 4 seconds apart -- long enough for the routing to settle, short enough to feel like one try.
enum JITRetryPolicy {
    static let maxAttempts = 3

    /// Shown while waiting to try attempt `nextAttempt` (the first retry is attempt 2).
    static func statusText(nextAttempt: Int) -> String {
        "Neuer Versuch über LocalDevVPN (\(nextAttempt) von \(maxAttempts)) …"
    }

    static func decision(situation: NetworkSituation, problem: JITConnectionProblem, attempt: Int) -> JITRetryDecision {
        guard situation == .cellularOnly, problem == .unreachable else { return .giveUp }
        return attempt < maxAttempts ? .retry(after: 4) : .giveUp
    }
}
