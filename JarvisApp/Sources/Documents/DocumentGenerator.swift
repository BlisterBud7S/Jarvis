import UIKit
import Foundation

class DocumentGenerator {

    enum DocType: String {
        case presentation, document, spreadsheet, html
    }

    struct Slide {
        let title: String
        let bullets: [String]
        let notes: String
    }

    struct DocSection {
        let heading: String
        let body: String
    }

    // MARK: - Presentation (HTML slides)

    func createPresentation(title: String, slides: [Slide], theme: PresentationTheme = .dark) -> URL? {
        let html = buildPresentationHTML(title: title, slides: slides, theme: theme)
        return saveToFile(html, name: sanitize(title), ext: "html")
    }

    func createPresentationFromTopic(topic: String, slideCount: Int = 8) -> URL? {
        let slides = generateSlides(for: topic, count: slideCount)
        return createPresentation(title: topic, slides: slides)
    }

    // MARK: - Document (HTML)

    func createDocument(title: String, sections: [DocSection]) -> URL? {
        let html = buildDocumentHTML(title: title, sections: sections)
        return saveToFile(html, name: sanitize(title), ext: "html")
    }

    func createDocumentFromTopic(topic: String) -> URL? {
        let sections = generateDocSections(for: topic)
        return createDocument(title: topic, sections: sections)
    }

    // MARK: - Spreadsheet (CSV)

    func createSpreadsheet(title: String, headers: [String], rows: [[String]]) -> URL? {
        var csv = headers.joined(separator: ",") + "\n"
        for row in rows {
            csv += row.map { "\"\($0)\"" }.joined(separator: ",") + "\n"
        }
        return saveToFile(csv, name: sanitize(title), ext: "csv")
    }

    // MARK: - Themes

    enum PresentationTheme {
        case dark, light, jarvis

        var bg: String {
            switch self {
            case .dark: return "#1a1a2e"
            case .light: return "#ffffff"
            case .jarvis: return "#0a0a1a"
            }
        }
        var text: String {
            switch self {
            case .dark: return "#e0e0e0"
            case .light: return "#333333"
            case .jarvis: return "#e0e0e0"
            }
        }
        var accent: String {
            switch self {
            case .dark: return "#4fc3f7"
            case .light: return "#1976d2"
            case .jarvis: return "#00e5ff"
            }
        }
        var heading: String {
            switch self {
            case .dark: return "#ffffff"
            case .light: return "#1a1a1a"
            case .jarvis: return "#00e5ff"
            }
        }
    }

    // MARK: - HTML Builders

    private func buildPresentationHTML(title: String, slides: [Slide], theme: PresentationTheme) -> String {
        var slideHTML = ""
        for (i, slide) in slides.enumerated() {
            let bullets = slide.bullets.map { "<li>\(escapeHTML($0))</li>" }.joined(separator: "\n")
            slideHTML += """
            <div class="slide" id="slide-\(i)">
                <h2>\(escapeHTML(slide.title))</h2>
                <ul>\(bullets)</ul>
                \(slide.notes.isEmpty ? "" : "<p class=\"notes\">\(escapeHTML(slide.notes))</p>")
            </div>
            """
        }

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>\(escapeHTML(title))</title>
        <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif;
            background: \(theme.bg);
            color: \(theme.text);
            overflow: hidden;
            height: 100vh;
        }
        .slide {
            display: none;
            width: 100vw;
            height: 100vh;
            padding: 8vh 8vw;
            flex-direction: column;
            justify-content: center;
        }
        .slide.active { display: flex; }
        .slide h2 {
            font-size: 3.5vw;
            color: \(theme.heading);
            margin-bottom: 4vh;
            letter-spacing: -0.02em;
        }
        .slide ul {
            list-style: none;
            padding: 0;
        }
        .slide li {
            font-size: 2.2vw;
            line-height: 1.6;
            padding: 1vh 0 1vh 2vw;
            border-left: 3px solid \(theme.accent);
            margin-bottom: 1.5vh;
        }
        .slide .notes {
            margin-top: auto;
            font-size: 1.4vw;
            opacity: 0.5;
            font-style: italic;
        }
        .controls {
            position: fixed;
            bottom: 3vh;
            right: 4vw;
            display: flex;
            gap: 1vw;
            z-index: 100;
        }
        .controls button {
            background: \(theme.accent);
            color: \(theme.bg);
            border: none;
            padding: 1.2vh 2.5vw;
            border-radius: 8px;
            font-size: 1.8vw;
            font-weight: 600;
            cursor: pointer;
        }
        .counter {
            position: fixed;
            bottom: 3vh;
            left: 4vw;
            font-size: 1.4vw;
            opacity: 0.4;
        }
        #slide-0 h2 {
            font-size: 5vw;
            text-align: center;
        }
        #slide-0 ul { display: none; }
        </style>
        </head>
        <body>
        \(slideHTML)
        <div class="controls">
            <button onclick="prev()">&#9664; Prev</button>
            <button onclick="next()">Next &#9654;</button>
        </div>
        <div class="counter" id="counter"></div>
        <script>
        let current = 0;
        const slides = document.querySelectorAll('.slide');
        function show(n) {
            slides.forEach(s => s.classList.remove('active'));
            current = Math.max(0, Math.min(n, slides.length - 1));
            slides[current].classList.add('active');
            document.getElementById('counter').textContent = (current + 1) + ' / ' + slides.length;
        }
        function next() { show(current + 1); }
        function prev() { show(current - 1); }
        document.addEventListener('keydown', e => {
            if (e.key === 'ArrowRight' || e.key === ' ') next();
            if (e.key === 'ArrowLeft') prev();
        });
        document.addEventListener('touchstart', e => { window._touchX = e.touches[0].clientX; });
        document.addEventListener('touchend', e => {
            const dx = e.changedTouches[0].clientX - (window._touchX || 0);
            if (dx < -50) next();
            if (dx > 50) prev();
        });
        show(0);
        </script>
        </body>
        </html>
        """
    }

    private func buildDocumentHTML(title: String, sections: [DocSection]) -> String {
        var body = ""
        for section in sections {
            body += "<h2>\(escapeHTML(section.heading))</h2>\n"
            let paragraphs = section.body.components(separatedBy: "\n").filter { !$0.isEmpty }
            for p in paragraphs {
                body += "<p>\(escapeHTML(p))</p>\n"
            }
        }

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>\(escapeHTML(title))</title>
        <style>
        body {
            font-family: Georgia, 'Times New Roman', serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 40px 20px;
            color: #333;
            line-height: 1.8;
            background: #fefefe;
        }
        h1 { font-size: 2.5em; margin-bottom: 0.5em; color: #1a1a1a; }
        h2 { font-size: 1.5em; margin-top: 2em; margin-bottom: 0.8em; color: #2c2c2c; border-bottom: 1px solid #ddd; padding-bottom: 0.3em; }
        p { margin-bottom: 1em; }
        @media (prefers-color-scheme: dark) {
            body { background: #1a1a1a; color: #e0e0e0; }
            h1, h2 { color: #f0f0f0; }
            h2 { border-color: #444; }
        }
        </style>
        </head>
        <body>
        <h1>\(escapeHTML(title))</h1>
        \(body)
        </body>
        </html>
        """
    }

    // MARK: - AI-free slide generation (templates for common topics)

    private func generateSlides(for topic: String, count: Int) -> [Slide] {
        var slides: [Slide] = []
        slides.append(Slide(title: topic, bullets: ["Created by Jarvis", "Swipe or tap to navigate"], notes: ""))
        slides.append(Slide(title: "Overview", bullets: ["What is \(topic)?", "Why it matters", "Key concepts to understand"], notes: ""))
        slides.append(Slide(title: "Key Points", bullets: ["Important aspect #1", "Important aspect #2", "Important aspect #3", "Important aspect #4"], notes: ""))
        slides.append(Slide(title: "Details", bullets: ["In-depth look at the core ideas", "Supporting evidence and examples", "Real-world applications"], notes: ""))
        slides.append(Slide(title: "Benefits", bullets: ["Advantage #1", "Advantage #2", "Advantage #3"], notes: ""))
        slides.append(Slide(title: "Challenges", bullets: ["Challenge #1 and how to address it", "Challenge #2 and potential solutions", "Ongoing considerations"], notes: ""))
        slides.append(Slide(title: "Examples", bullets: ["Real-world example #1", "Real-world example #2", "Case study highlights"], notes: ""))
        slides.append(Slide(title: "Summary", bullets: ["Key takeaways", "Next steps", "Questions?"], notes: ""))

        return Array(slides.prefix(max(3, count)))
    }

    private func generateDocSections(for topic: String) -> [DocSection] {
        [
            DocSection(heading: "Introduction", body: "This document covers \(topic) in detail."),
            DocSection(heading: "Background", body: "Understanding the context and history behind \(topic)."),
            DocSection(heading: "Key Points", body: "The most important aspects of \(topic) that should be understood."),
            DocSection(heading: "Analysis", body: "A deeper look into the implications and applications."),
            DocSection(heading: "Conclusion", body: "Summary of findings and recommended next steps."),
        ]
    }

    // MARK: - File Management

    private func saveToFile(_ content: String, name: String, ext: String) -> URL? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let jarvisDir = docs.appendingPathComponent("Jarvis", isDirectory: true)
        try? FileManager.default.createDirectory(at: jarvisDir, withIntermediateDirectories: true)
        let file = jarvisDir.appendingPathComponent("\(name).\(ext)")
        do {
            try content.write(to: file, atomically: true, encoding: .utf8)
            return file
        } catch {
            return nil
        }
    }

    func listGeneratedFiles() -> [URL] {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let jarvisDir = docs.appendingPathComponent("Jarvis", isDirectory: true)
        let files = (try? FileManager.default.contentsOfDirectory(at: jarvisDir, includingPropertiesForKeys: nil)) ?? []
        return files.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func openInBrowser(_ url: URL) {
        UIApplication.shared.open(url)
    }

    private func sanitize(_ name: String) -> String {
        let clean = name.components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: "-")
        return String(clean.prefix(50))
    }

    private func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
