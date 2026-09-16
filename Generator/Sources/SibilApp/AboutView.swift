import SwiftUI

struct AboutView: View {
    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Brand.bgTop, Brand.bgBottom],
                center: .topLeading,
                startRadius: 10,
                endRadius: 320
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Brand.textPrimary)
                    .padding(16)
                    .glassCard(cornerRadius: 18)

                VStack(spacing: 4) {
                    Text("SibilApp")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Brand.textPrimary)

                    Text("Version \(appVersion)")
                        .font(.system(size: 11))
                        .foregroundStyle(Brand.textPrimary.opacity(0.55))
                }

                Text("Turn any link into a native Mac app")
                    .font(.system(size: 12))
                    .foregroundStyle(Brand.textPrimary.opacity(0.7))
                    .multilineTextAlignment(.center)

                Button {
                    if let url = URL(string: "https://buymeacoffee.com/farnoud") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("Support Me", systemImage: "cup.and.saucer.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .glassButton(prominent: true)
                .tint(Brand.cyan)
                .padding(.top, 6)
            }
            .padding(28)
        }
        .frame(width: 300, height: 300)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
