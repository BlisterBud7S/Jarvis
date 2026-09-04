import Foundation

class MathEngine {

    func evaluate(_ expression: String) -> String {
        let cleaned = expression
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "^", with: "**")
            .replacingOccurrences(of: " ", with: "")

        let nsExpression = NSExpression(format: cleaned)
        if let result = nsExpression.expressionValue(with: nil, context: nil) as? NSNumber {
            let d = result.doubleValue
            if d == d.rounded() && abs(d) < 1e15 {
                return String(format: "%.0f", d)
            }
            return String(format: "%.6g", d)
        }
        return "Could not evaluate: \(expression)"
    }

    func convert(_ value: Double, from: String, to: String) -> String {
        // Length
        let lengthFactors: [String: Double] = [
            "m": 1, "km": 1000, "cm": 0.01, "mm": 0.001,
            "mi": 1609.344, "mile": 1609.344, "miles": 1609.344,
            "ft": 0.3048, "feet": 0.3048, "foot": 0.3048,
            "in": 0.0254, "inch": 0.0254, "inches": 0.0254,
            "yd": 0.9144, "yard": 0.9144, "yards": 0.9144,
        ]

        // Weight
        let weightFactors: [String: Double] = [
            "kg": 1, "g": 0.001, "mg": 0.000001,
            "lb": 0.453592, "lbs": 0.453592, "pound": 0.453592, "pounds": 0.453592,
            "oz": 0.0283495, "ounce": 0.0283495, "ounces": 0.0283495,
            "ton": 907.185, "tons": 907.185,
        ]

        // Volume
        let volumeFactors: [String: Double] = [
            "l": 1, "liter": 1, "liters": 1, "litre": 1,
            "ml": 0.001, "gal": 3.78541, "gallon": 3.78541, "gallons": 3.78541,
            "cup": 0.236588, "cups": 0.236588,
            "pt": 0.473176, "pint": 0.473176, "pints": 0.473176,
            "qt": 0.946353, "quart": 0.946353,
            "fl oz": 0.0295735, "floz": 0.0295735,
        ]

        let fromL = from.lowercased()
        let toL = to.lowercased()

        // Temperature
        if isTemp(fromL) && isTemp(toL) {
            return convertTemp(value, from: fromL, to: toL)
        }

        for factors in [lengthFactors, weightFactors, volumeFactors] {
            if let fFrom = factors[fromL], let fTo = factors[toL] {
                let result = value * fFrom / fTo
                return String(format: "%.4g \(to)", result)
            }
        }

        return "Cannot convert \(from) to \(to)"
    }

    private func isTemp(_ unit: String) -> Bool {
        ["c", "f", "k", "celsius", "fahrenheit", "kelvin"].contains(unit)
    }

    private func convertTemp(_ value: Double, from: String, to: String) -> String {
        let celsius: Double
        switch from.first {
        case "f": celsius = (value - 32) * 5 / 9
        case "k": celsius = value - 273.15
        default: celsius = value
        }
        let result: Double
        let unit: String
        switch to.first {
        case "f": result = celsius * 9 / 5 + 32; unit = "°F"
        case "k": result = celsius + 273.15; unit = "K"
        default: result = celsius; unit = "°C"
        }
        return String(format: "%.1f %@", result, unit)
    }

    func parseAndEvaluate(_ text: String) -> String? {
        let t = text.lowercased()

        // "what is 5 + 3" or "calculate 10 * 20"
        let mathPrefixes = ["what is ", "what's ", "calculate ", "compute ", "solve ", "evaluate ", "how much is "]
        for p in mathPrefixes {
            if t.hasPrefix(p) {
                let expr = String(t.dropFirst(p.count))
                    .replacingOccurrences(of: "plus", with: "+")
                    .replacingOccurrences(of: "minus", with: "-")
                    .replacingOccurrences(of: "times", with: "*")
                    .replacingOccurrences(of: "multiplied by", with: "*")
                    .replacingOccurrences(of: "divided by", with: "/")
                    .replacingOccurrences(of: "over", with: "/")
                    .replacingOccurrences(of: "mod", with: "%")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if expr.contains(where: { "0123456789+-*/.%".contains($0) }) {
                    return evaluate(expr)
                }
            }
        }

        // Unit conversion: "convert 5 miles to km"
        let convertPattern = #"convert\s+([\d.]+)\s+(\w+)\s+to\s+(\w+)"#
        if let match = t.range(of: convertPattern, options: .regularExpression) {
            let parts = t[match].components(separatedBy: " ").filter { !$0.isEmpty }
            if parts.count >= 4, let val = Double(parts[1]) {
                return convert(val, from: parts[2], to: parts[parts.count - 1])
            }
        }

        // "X to Y" pattern: "100 f to c", "5 miles to km"
        let toPattern = #"([\d.]+)\s+(\w+)\s+(?:to|in)\s+(\w+)"#
        if let match = t.range(of: toPattern, options: .regularExpression) {
            let sub = String(t[match])
            let parts = sub.components(separatedBy: " ").filter { !$0.isEmpty }
            if parts.count >= 3, let val = Double(parts[0]) {
                let fromUnit = parts[1]
                let toUnit = parts[parts.count - 1]
                let result = convert(val, from: fromUnit, to: toUnit)
                if !result.hasPrefix("Cannot") { return result }
            }
        }

        return nil
    }
}
