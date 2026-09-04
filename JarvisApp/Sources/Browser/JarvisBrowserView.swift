import SwiftUI
import WebKit

struct JarvisBrowserView: View {
    @EnvironmentObject var jarvis: JarvisBrain
    @StateObject private var automation = WebAutomation()
    @State private var urlText = ""
    @State private var showCommandBar = false
    @State private var commandText = ""

    var body: some View {
        VStack(spacing: 0) {
            // URL bar
            HStack(spacing: 8) {
                Button(action: { automation.goBack() }) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                }
                .disabled(automation.webView?.canGoBack != true)

                Button(action: { automation.goForward() }) {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                }
                .disabled(automation.webView?.canGoForward != true)

                HStack {
                    Image(systemName: automation.isLoading ? "arrow.2.circlepath" : "lock.fill")
                        .font(.caption)
                        .foregroundStyle(automation.isLoading ? .orange : .green)

                    TextField("Search or enter URL", text: $urlText)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit {
                            let query = urlText.trimmingCharacters(in: .whitespaces)
                            if query.contains(".") && !query.contains(" ") {
                                automation.navigate(to: query)
                            } else {
                                let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
                                automation.navigate(to: "https://www.google.com/search?q=\(encoded)")
                            }
                        }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Button(action: { automation.reload() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.body.weight(.medium))
                }

                Button(action: { showCommandBar.toggle() }) {
                    Image(systemName: "terminal.fill")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.cyan)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)

            // Command bar (Jarvis control)
            if showCommandBar {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(.cyan)

                    TextField("Tell Jarvis what to do on this page...", text: $commandText)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                        .onSubmit {
                            let cmd = commandText
                            commandText = ""
                            Task { await jarvis.processBrowserCommand(cmd, automation: automation) }
                        }

                    Button("Go") {
                        let cmd = commandText
                        commandText = ""
                        Task { await jarvis.processBrowserCommand(cmd, automation: automation) }
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.cyan)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.8))
            }

            // Web view
            WebViewRepresentable(automation: automation, urlText: $urlText)
                .ignoresSafeArea(edges: .bottom)

            // Quick actions bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    BrowserAction(icon: "hand.tap", label: "Tap") {
                        Task {
                            let text = await promptForInput("Element text to tap:")
                            if !text.isEmpty { _ = await automation.tapElement(withText: text) }
                        }
                    }
                    BrowserAction(icon: "character.cursor.ibeam", label: "Fill") {
                        Task {
                            let fields = await automation.getFormFields()
                            jarvis.messages.append(Message(role: .system, content: "Form fields found:\n\(fields)"))
                        }
                    }
                    BrowserAction(icon: "arrow.down", label: "Scroll") {
                        Task { await automation.scrollDown() }
                    }
                    BrowserAction(icon: "doc.text", label: "Read") {
                        Task {
                            let text = await automation.extractText()
                            jarvis.messages.append(Message(role: .system, content: "Page text:\n\(text.prefix(2000))"))
                        }
                    }
                    BrowserAction(icon: "link", label: "Links") {
                        Task {
                            let links = await automation.extractLinks()
                            jarvis.messages.append(Message(role: .system, content: "Links:\n\(links)"))
                        }
                    }
                    BrowserAction(icon: "paperplane", label: "Submit") {
                        Task { _ = await automation.submitForm() }
                    }
                    BrowserAction(icon: "camera", label: "Capture") {
                        Task {
                            if let img = await automation.screenshot() {
                                UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                                jarvis.messages.append(Message(role: .system, content: "Browser screenshot saved to Photos."))
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(.ultraThinMaterial)
        }
    }

    private func promptForInput(_ prompt: String) async -> String {
        return ""
    }
}

struct BrowserAction: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.body)
                Text(label)
                    .font(.caption2)
            }
            .frame(width: 52)
            .foregroundStyle(.cyan)
        }
    }
}

struct WebViewRepresentable: UIViewRepresentable {
    @ObservedObject var automation: WebAutomation
    @Binding var urlText: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        automation.attach(webView)
        webView.load(URLRequest(url: URL(string: "https://www.google.com")!))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(automation: automation, urlText: $urlText)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let automation: WebAutomation
        @Binding var urlText: String

        init(automation: WebAutomation, urlText: Binding<String>) {
            self.automation = automation
            self._urlText = urlText
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Task { @MainActor in
                automation.isLoading = true
                automation.currentURL = webView.url?.absoluteString ?? ""
                urlText = automation.currentURL
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                automation.isLoading = false
                automation.pageTitle = webView.title ?? ""
                automation.currentURL = webView.url?.absoluteString ?? ""
                urlText = automation.currentURL
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in automation.isLoading = false }
        }
    }
}
