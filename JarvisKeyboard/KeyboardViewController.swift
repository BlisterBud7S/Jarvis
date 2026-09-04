import UIKit

class KeyboardViewController: UIInputViewController {

    private let groupID = "group.com.jarvis.ai"
    private var pollTimer: Timer?
    private var statusLabel: UILabel!
    private var isJarvisTyping = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        startPolling()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pollTimer?.invalidate()
    }

    private func setupUI() {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            container.topAnchor.constraint(equalTo: view.topAnchor),
            container.heightAnchor.constraint(equalToConstant: 50),
        ])

        // Jarvis status bar
        let bg = UIView()
        bg.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.12, alpha: 1)
        bg.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(bg)
        NSLayoutConstraint.activate([
            bg.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bg.topAnchor.constraint(equalTo: container.topAnchor),
            bg.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        // Orb indicator
        let orb = UIView()
        orb.backgroundColor = UIColor.cyan
        orb.layer.cornerRadius = 6
        orb.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(orb)
        NSLayoutConstraint.activate([
            orb.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 16),
            orb.centerYAnchor.constraint(equalTo: bg.centerYAnchor),
            orb.widthAnchor.constraint(equalToConstant: 12),
            orb.heightAnchor.constraint(equalToConstant: 12),
        ])

        statusLabel = UILabel()
        statusLabel.text = "Jarvis Keyboard Active"
        statusLabel.textColor = .cyan
        statusLabel.font = .systemFont(ofSize: 14, weight: .medium)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: orb.trailingAnchor, constant: 10),
            statusLabel.centerYAnchor.constraint(equalTo: bg.centerYAnchor),
        ])

        // Switch keyboard button
        let switchBtn = UIButton(type: .system)
        switchBtn.setImage(UIImage(systemName: "globe"), for: .normal)
        switchBtn.tintColor = .cyan
        switchBtn.addTarget(self, action: #selector(handleNextKeyboard), for: .touchUpInside)
        switchBtn.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(switchBtn)
        NSLayoutConstraint.activate([
            switchBtn.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -16),
            switchBtn.centerYAnchor.constraint(equalTo: bg.centerYAnchor),
            switchBtn.widthAnchor.constraint(equalToConstant: 30),
            switchBtn.heightAnchor.constraint(equalToConstant: 30),
        ])
    }

    @objc private func handleNextKeyboard() {
        advanceToNextInputMode()
    }

    // MARK: - Polling for text injection commands

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.checkForPendingText()
        }
    }

    private func checkForPendingText() {
        guard let defaults = UserDefaults(suiteName: groupID) else { return }

        if let textToType = defaults.string(forKey: "jarvis_type_text"), !textToType.isEmpty {
            defaults.removeObject(forKey: "jarvis_type_text")
            defaults.synchronize()
            typeText(textToType)
        }

        if defaults.bool(forKey: "jarvis_clear_field") {
            defaults.set(false, forKey: "jarvis_clear_field")
            defaults.synchronize()
            clearCurrentField()
        }

        if defaults.bool(forKey: "jarvis_select_all") {
            defaults.set(false, forKey: "jarvis_select_all")
            defaults.synchronize()
            selectAllText()
        }

        if let deleteCount = defaults.object(forKey: "jarvis_delete_chars") as? Int, deleteCount > 0 {
            defaults.removeObject(forKey: "jarvis_delete_chars")
            defaults.synchronize()
            deleteCharacters(count: deleteCount)
        }

        if defaults.bool(forKey: "jarvis_press_return") {
            defaults.set(false, forKey: "jarvis_press_return")
            defaults.synchronize()
            pressReturn()
        }
    }

    // MARK: - Text operations

    private func typeText(_ text: String) {
        isJarvisTyping = true
        statusLabel.text = "Typing..."

        // Type character by character for realistic effect
        let chars = Array(text)
        var index = 0

        Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] timer in
            guard let self, index < chars.count else {
                timer.invalidate()
                self?.isJarvisTyping = false
                self?.statusLabel.text = "Jarvis Keyboard Active"
                self?.notifyTypingComplete()
                return
            }

            let proxy = self.textDocumentProxy
            proxy.insertText(String(chars[index]))
            index += 1
        }
    }

    private func clearCurrentField() {
        let proxy = textDocumentProxy
        // Select all and delete
        if let before = proxy.documentContextBeforeInput {
            for _ in 0..<before.count {
                proxy.deleteBackward()
            }
        }
        if let after = proxy.documentContextAfterInput {
            proxy.adjustTextPosition(byCharacterOffset: after.count)
            for _ in 0..<after.count {
                proxy.deleteBackward()
            }
        }
        statusLabel.text = "Field cleared"
    }

    private func selectAllText() {
        // Move to end, then select back to start
        let proxy = textDocumentProxy
        if let after = proxy.documentContextAfterInput {
            proxy.adjustTextPosition(byCharacterOffset: after.count)
        }
        statusLabel.text = "Selected all"
    }

    private func deleteCharacters(count: Int) {
        let proxy = textDocumentProxy
        for _ in 0..<count {
            proxy.deleteBackward()
        }
    }

    private func pressReturn() {
        textDocumentProxy.insertText("\n")
    }

    private func notifyTypingComplete() {
        guard let defaults = UserDefaults(suiteName: groupID) else { return }
        defaults.set(true, forKey: "jarvis_typing_done")
        defaults.synchronize()
    }
}
