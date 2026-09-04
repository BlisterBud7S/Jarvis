import Foundation
import UIKit

class SystemMonitor {

    func getBatteryInfo() -> String {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = Int(UIDevice.current.batteryLevel * 100)
        let state: String
        switch UIDevice.current.batteryState {
        case .charging: state = "Charging"
        case .full: state = "Full"
        case .unplugged: state = "Unplugged"
        default: state = "Unknown"
        }
        return "Battery: \(level)% (\(state))"
    }

    func getStorageInfo() -> String {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
              let total = attrs[.systemSize] as? Int64,
              let free = attrs[.systemFreeSize] as? Int64 else {
            return "Storage: unavailable"
        }
        let totalGB = Double(total) / 1_073_741_824
        let freeGB = Double(free) / 1_073_741_824
        let usedGB = totalGB - freeGB
        return String(format: "Storage: %.1f GB used of %.1f GB (%.1f GB free)", usedGB, totalGB, freeGB)
    }

    func getDeviceInfo() -> String {
        let device = UIDevice.current
        var sysinfo = utsname()
        uname(&sysinfo)
        let machine = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        return """
        Device: \(device.model) (\(machine))
        Name: \(device.name)
        System: \(device.systemName) \(device.systemVersion)
        \(getBatteryInfo())
        \(getStorageInfo())
        """
    }

    func getNetworkInfo() -> String {
        var addresses: [String] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else {
            return "Network: Could not retrieve interface info"
        }
        defer { freeifaddrs(first) }
        var ptr = first
        while true {
            let iface = ptr.pointee
            let family = iface.ifa_addr.pointee.sa_family
            if family == UInt8(AF_INET) {
                let name = String(cString: iface.ifa_name)
                if name == "en0" || name == "pdp_ip0" {
                    var addr = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(iface.ifa_addr, socklen_t(iface.ifa_addr.pointee.sa_len),
                                &addr, socklen_t(addr.count), nil, 0, NI_NUMERICHOST)
                    addresses.append("\(name): \(String(cString: addr))")
                }
            }
            guard let next = iface.ifa_next else { break }
            ptr = next
        }
        if addresses.isEmpty { return "Network: No active connections detected" }
        return "Network:\n" + addresses.joined(separator: "\n")
    }

    func getUptimeInfo() -> String {
        let uptime = ProcessInfo.processInfo.systemUptime
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        return "Uptime: \(hours)h \(minutes)m"
    }

    func getMemoryInfo() -> String {
        let total = ProcessInfo.processInfo.physicalMemory
        let totalGB = Double(total) / 1_073_741_824
        return String(format: "RAM: %.1f GB total", totalGB)
    }

    func getFullDiagnostics() -> String {
        return """
        === JARVIS System Diagnostics ===
        \(getDeviceInfo())
        \(getNetworkInfo())
        \(getMemoryInfo())
        \(getUptimeInfo())
        Processor Cores: \(ProcessInfo.processInfo.processorCount)
        Thermal State: \(thermalState())
        """
    }

    private func thermalState() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "Normal"
        case .fair: return "Slightly elevated"
        case .serious: return "High — performance may be throttled"
        case .critical: return "Critical — immediate cooling needed"
        @unknown default: return "Unknown"
        }
    }
}
