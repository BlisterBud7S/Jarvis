import Foundation

class SmartHomeController {

    func controlDevice(name: String, action: String) -> String {
        let shortcutName: String
        let input: String

        switch action.lowercased() {
        case "on", "turn on":
            shortcutName = "Turn On Device"
            input = name
        case "off", "turn off":
            shortcutName = "Turn Off Device"
            input = name
        case "dim", "lower":
            shortcutName = "Dim Light"
            input = name
        case "brighten", "bright":
            shortcutName = "Brighten Light"
            input = name
        case "lock":
            shortcutName = "Lock Door"
            input = name
        case "unlock":
            shortcutName = "Unlock Door"
            input = name
        default:
            shortcutName = "Control Device"
            input = "\(name)|\(action)"
        }

        return "shortcuts://run-shortcut?name=\(shortcutName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? shortcutName)&input=text&text=\(input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input)"
    }

    func runScene(name: String) -> String {
        let enc = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        return "shortcuts://run-shortcut?name=Run%20Scene&input=text&text=\(enc)"
    }

    func setThermostat(temperature: Int) -> String {
        return "shortcuts://run-shortcut?name=Set%20Thermostat&input=text&text=\(temperature)"
    }
}
