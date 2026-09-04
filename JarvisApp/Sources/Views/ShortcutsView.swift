import SwiftUI

struct ShortcutsView: View {
    @EnvironmentObject var appState: AppState
    private let bridge = ShortcutsBridge()
    @State private var selectedCategory: ShortcutInfo.ShortcutCategory = .apps

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(ShortcutInfo.ShortcutCategory.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                List {
                    ForEach(filteredShortcuts) { shortcut in
                        ShortcutRow(shortcut: shortcut) {
                            Task {
                                await bridge.runShortcut(name: shortcut.name)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Quick Actions")
        }
    }

    private var filteredShortcuts: [ShortcutInfo] {
        ShortcutsBridge.predefinedShortcuts.filter { $0.category == selectedCategory }
    }
}

struct ShortcutRow: View {
    let shortcut: ShortcutInfo
    let onRun: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(shortcut.name)
                    .font(.headline)
                Text(shortcut.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Run", systemImage: "play.fill") {
                onRun()
            }
            .buttonStyle(.bordered)
            .tint(.blue)
        }
        .padding(.vertical, 4)
    }
}
