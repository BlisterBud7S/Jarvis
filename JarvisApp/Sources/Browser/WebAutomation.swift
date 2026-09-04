import WebKit
import Foundation

@MainActor
class WebAutomation: NSObject, ObservableObject {
    @Published var currentURL: String = ""
    @Published var pageTitle: String = ""
    @Published var isLoading = false
    @Published var pageText: String = ""

    var webView: WKWebView?

    func attach(_ webView: WKWebView) {
        self.webView = webView
    }

    func navigate(to urlString: String) {
        var url = urlString
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "https://\(url)"
        }
        guard let u = URL(string: url) else { return }
        webView?.load(URLRequest(url: u))
    }

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload() { webView?.reload() }

    func tapElement(withText text: String) async -> Bool {
        let js = """
        (function() {
            const all = document.querySelectorAll('a, button, input[type=submit], input[type=button], [role=button], [onclick]');
            for (const el of all) {
                const t = (el.textContent || el.value || el.getAttribute('aria-label') || '').trim().toLowerCase();
                if (t.includes('\(text.lowercased().replacingOccurrences(of: "'", with: "\\'"))')) {
                    el.click();
                    return 'clicked: ' + t.substring(0, 50);
                }
            }
            const labels = document.querySelectorAll('label, span, div, p, h1, h2, h3, h4, li, td');
            for (const el of labels) {
                if (el.children.length > 3) continue;
                const t = (el.textContent || '').trim().toLowerCase();
                if (t.includes('\(text.lowercased().replacingOccurrences(of: "'", with: "\\'"))')) {
                    el.click();
                    return 'clicked: ' + t.substring(0, 50);
                }
            }
            return 'not found';
        })()
        """
        return await runJS(js) != "not found"
    }

    func fillField(placeholder: String, value: String) async -> Bool {
        let js = """
        (function() {
            const ph = '\(placeholder.lowercased().replacingOccurrences(of: "'", with: "\\'"))';
            const val = '\(value.replacingOccurrences(of: "'", with: "\\'"))';
            const inputs = document.querySelectorAll('input, textarea, [contenteditable]');
            for (const el of inputs) {
                const p = (el.placeholder || el.getAttribute('aria-label') || el.name || el.id || '').toLowerCase();
                if (p.includes(ph)) {
                    el.focus();
                    el.value = val;
                    el.dispatchEvent(new Event('input', {bubbles: true}));
                    el.dispatchEvent(new Event('change', {bubbles: true}));
                    return 'filled';
                }
            }
            const labels = document.querySelectorAll('label');
            for (const label of labels) {
                if (label.textContent.toLowerCase().includes(ph)) {
                    const input = label.querySelector('input, textarea') ||
                                  document.getElementById(label.getAttribute('for'));
                    if (input) {
                        input.focus();
                        input.value = val;
                        input.dispatchEvent(new Event('input', {bubbles: true}));
                        input.dispatchEvent(new Event('change', {bubbles: true}));
                        return 'filled';
                    }
                }
            }
            return 'not found';
        })()
        """
        return await runJS(js) == "filled"
    }

    func scrollDown() async {
        _ = await runJS("window.scrollBy(0, window.innerHeight * 0.8)")
    }

    func scrollUp() async {
        _ = await runJS("window.scrollBy(0, -window.innerHeight * 0.8)")
    }

    func scrollToElement(withText text: String) async -> Bool {
        let js = """
        (function() {
            const all = document.querySelectorAll('*');
            for (const el of all) {
                if (el.children.length > 5) continue;
                const t = (el.textContent || '').trim().toLowerCase();
                if (t.includes('\(text.lowercased().replacingOccurrences(of: "'", with: "\\'"))')) {
                    el.scrollIntoView({behavior: 'smooth', block: 'center'});
                    return 'scrolled';
                }
            }
            return 'not found';
        })()
        """
        return await runJS(js) == "scrolled"
    }

    func extractText() async -> String {
        let js = "document.body.innerText.substring(0, 5000)"
        return await runJS(js) ?? ""
    }

    func extractLinks() async -> String {
        let js = """
        Array.from(document.querySelectorAll('a[href]'))
            .slice(0, 30)
            .map(a => a.textContent.trim().substring(0, 50) + ' -> ' + a.href)
            .join('\\n')
        """
        return await runJS(js) ?? ""
    }

    func getFormFields() async -> String {
        let js = """
        Array.from(document.querySelectorAll('input, textarea, select'))
            .slice(0, 20)
            .map(el => {
                const type = el.tagName.toLowerCase() + (el.type ? ':' + el.type : '');
                const name = el.placeholder || el.name || el.id || el.getAttribute('aria-label') || '(unnamed)';
                const val = el.value || '';
                return type + ' | ' + name + ' | value: ' + val.substring(0, 30);
            })
            .join('\\n')
        """
        return await runJS(js) ?? ""
    }

    func submitForm() async -> Bool {
        let js = """
        (function() {
            const submit = document.querySelector('input[type=submit], button[type=submit]');
            if (submit) { submit.click(); return 'submitted'; }
            const form = document.querySelector('form');
            if (form) { form.submit(); return 'submitted'; }
            return 'no form';
        })()
        """
        return await runJS(js) == "submitted"
    }

    func screenshot() async -> UIImage? {
        guard let webView else { return nil }
        let config = WKSnapshotConfiguration()
        return try? await webView.takeSnapshot(configuration: config)
    }

    private func runJS(_ js: String) async -> String? {
        guard let webView else { return nil }
        do {
            let result = try await webView.evaluateJavaScript(js)
            return result as? String ?? "\(result)"
        } catch {
            return nil
        }
    }
}
