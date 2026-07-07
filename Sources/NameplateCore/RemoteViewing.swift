import Foundation

/// Classifies displays and network state for the "only when viewed remotely"
/// decoration mode. Pure functions — the app layer feeds in NSScreen /
/// netstat data.
public enum RemoteViewing {
    /// Substrings (lowercased) of display names that mark virtual displays
    /// created by remote-desktop and dummy-display tools.
    public static let virtualNameMarkers: [String] = [
        "jump desktop",
        "virtual display",
        "dummy",
        "deskpad",
        "betterdisplay",
        "luna display",
    ]

    /// Display vendor IDs used by virtual displays. Jump Desktop stamps
    /// 0x70357379; CGVirtualDisplay-based tools commonly use "unkn".
    public static let virtualVendorIDs: Set<UInt32> = [
        0x7035_7379, // Jump Desktop
        0x756E_6B6E, // 'unkn' — CGVirtualDisplay default
    ]

    public static func isVirtualDisplay(name: String, vendorNumber: UInt32, isBuiltin: Bool) -> Bool {
        if isBuiltin { return false }
        if self.virtualVendorIDs.contains(vendorNumber) { return true }
        let lowered = name.lowercased()
        return self.virtualNameMarkers.contains { lowered.contains($0) }
    }

    /// True when netstat output shows an ESTABLISHED connection on a VNC /
    /// Screen Sharing port (5900-5901). Matches Apple Screen Sharing,
    /// classic VNC, and Jump Desktop's VNC-compatible listener.
    public static func hasEstablishedScreenSharing(netstatOutput: String) -> Bool {
        for line in netstatOutput.split(separator: "\n") {
            guard line.contains("ESTABLISHED") else { continue }
            let columns = line.split(separator: " ", omittingEmptySubsequences: true)
            // Local address is column 3 in `netstat -an -p tcp` output;
            // BSD netstat formats it as ip.port (e.g. 192.168.0.10.5900).
            guard columns.count >= 4 else { continue }
            let local = columns[3]
            if local.hasSuffix(".5900") || local.hasSuffix(".5901") {
                return true
            }
        }
        return false
    }
}
