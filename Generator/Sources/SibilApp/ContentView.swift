import SwiftUI

// Palette sampled from farnoud.net: dark navy background, cyan-blue + emerald accents.
enum Brand {
    static let bgTop = Color(red: 19 / 255, green: 42 / 255, blue: 61 / 255)
    static let bgBottom = Color(red: 10 / 255, green: 20 / 255, blue: 32 / 255)
    static let cyan = Color(red: 74 / 255, green: 166 / 255, blue: 204 / 255)
    static let emerald = Color(red: 0 / 255, green: 188 / 255, blue: 125 / 255)
    static let paleCyan = Color(red: 170 / 255, green: 205 / 255, blue: 213 / 255)
    static let textPrimary = Color(red: 238 / 255, green: 246 / 255, blue: 251 / 255)
}

struct ContentView: View {
    @StateObject private var engine = GeneratorEngine()
    @FocusState private var urlFieldFocused: Bool

    var body: some View {
        ZStack {
            background

            VStack(spacing: 20) {
                header

                Group {
                    switch engine.state {
                    case .idle, .working, .failed:
                        formCard
                    case .done(let path):
                        doneCard(path: path)
                    }
                }

                Spacer(minLength: 0)

                footer
            }
            .padding(28)
        }
        .frame(width: 480, height: 560)
        .onAppear { urlFieldFocused = true }
    }

    private var footer: some View {
        Text("Designed & developed by Farnoud Najari")
            .font(.system(size: 10, weight: .regular))
            .foregroundStyle(Brand.textPrimary.opacity(0.28))
    }

    private var background: some View {
        ZStack {
            RadialGradient(
                colors: [Brand.bgTop, Brand.bgBottom],
                center: .topLeading,
                startRadius: 20,
                endRadius: 560
            )
            Circle()
                .fill(Brand.cyan.opacity(0.35))
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .offset(x: -150, y: -220)
            Circle()
                .fill(Brand.emerald.opacity(0.28))
                .frame(width: 240, height: 240)
                .blur(radius: 70)
                .offset(x: 160, y: 240)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Brand.textPrimary)
                .padding(18)
                .glassCard(cornerRadius: 20)

            Text("SibilApp")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Brand.textPrimary)

            Text("Turn any link into a native Mac app")
                .font(.system(size: 13))
                .foregroundStyle(Brand.textPrimary.opacity(0.7))
        }
        .padding(.top, 8)
    }

    private var formCard: some View {
        VStack(spacing: 14) {
            fieldLabel("LINK")
            TextField("https://example.com", text: $engine.urlText)
                .textFieldStyle(.plain)
                .focused($urlFieldFocused)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Brand.textPrimary)
                .padding(12)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onSubmit { engine.generate() }

            fieldLabel("APP NAME (OPTIONAL)")
            TextField("Auto-detected from link", text: $engine.nameText)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Brand.textPrimary)
                .padding(12)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onSubmit { engine.generate() }

            iconPicker

            if case .failed(let message) = engine.state {
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.yellow.opacity(0.95))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            generateButton
        }
        .padding(20)
        .glassCard(cornerRadius: 26)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Brand.textPrimary.opacity(0.55))
            .tracking(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var iconPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("APP ICON")

            Picker("", selection: $engine.iconMode) {
                Text("Auto (favicon)").tag(IconMode.auto)
                Text("Custom logo").tag(IconMode.custom)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if engine.iconMode == .custom {
                HStack(spacing: 10) {
                    if let url = engine.customIconURL, let image = NSImage(contentsOf: url) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.white.opacity(0.08))
                            .frame(width: 32, height: 32)
                            .overlay(Image(systemName: "photo").foregroundStyle(Brand.textPrimary.opacity(0.5)))
                    }

                    Text(engine.customIconURL?.lastPathComponent ?? "No image chosen")
                        .font(.system(size: 12))
                        .foregroundStyle(Brand.textPrimary.opacity(0.75))
                        .lineLimit(1)

                    Spacer()

                    Button {
                        engine.pickCustomIcon()
                    } label: {
                        Text("Choose…")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .glassButton(prominent: false)
                }
            }
        }
    }

    private var generateButton: some View {
        Group {
            switch engine.state {
            case .working(let status):
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Brand.textPrimary)
                    Text(status)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Brand.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .glassCard(cornerRadius: 14)
            default:
                Button {
                    engine.generate()
                } label: {
                    Text("Generate App")
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .glassButton(prominent: true)
                .tint(Brand.cyan)
                .disabled(!engine.canGenerate)
            }
        }
    }

    private func doneCard(path: String) -> some View {
        let name = (path as NSString).lastPathComponent
        return VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Brand.emerald)

            Text("\(name) is ready")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Brand.textPrimary)

            Text("Saved to your Desktop")
                .font(.system(size: 12))
                .foregroundStyle(Brand.textPrimary.opacity(0.7))

            VStack(spacing: 10) {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                } label: {
                    Text("Reveal in Finder")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .glassButton(prominent: true)
                .tint(Brand.cyan)

                Button {
                    NSWorkspace.shared.open(URL(fileURLWithPath: path))
                } label: {
                    Text("Open App")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .glassButton(prominent: false)
                .tint(Brand.textPrimary)

                Button {
                    engine.reset()
                } label: {
                    Text("Make Another")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Brand.textPrimary.opacity(0.75))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(24)
        .glassCard(cornerRadius: 26)
    }
}
