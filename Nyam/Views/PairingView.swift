import SwiftUI

/// Links the two phones: one creates a code, the other types it in.
struct PairingView: View {
    @Environment(NyamStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var enteredCode = ""
    @FocusState private var codeFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header

                if let code = store.householdCode {
                    linkedSection(code: code)
                } else {
                    createSection
                    orDivider
                    joinSection
                    if let error = store.syncError {
                        Text(error)
                            .font(.ui(14, weight: .semibold))
                            .foregroundStyle(Theme.danger)
                    }
                    Button("Skip for now") {
                        store.skipPairing()
                        dismiss()
                    }
                    .font(.ui(15, weight: .bold))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 40)
            .padding(.bottom, 30)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background.ignoresSafeArea())
        .overlay {
            if store.isLinking {
                ProgressView()
                    .controlSize(.large)
                    .padding(28)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image("NyamLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 76)
                .accessibilityHidden(true)
            Text("Nyam")
                .font(.display(40))
                .foregroundStyle(Theme.ink)
            Text("What are we eating today?")
                .font(.ui(18, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("Link your two phones once. Then you both swipe, and Nyam shows the dishes you both want.")
                .font(.ui(15))
                .foregroundStyle(Theme.muted)
        }
    }

    private var createSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("First phone")
                .font(.ui(15, weight: .bold))
                .foregroundStyle(Theme.ink)
            Button("Create a pair code") {
                Task { await store.createPairCode() }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(store.isLinking)
        }
    }

    private var orDivider: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Theme.line).frame(height: 1)
            Text("or")
                .font(.ui(14, weight: .semibold))
                .foregroundStyle(Theme.muted)
            Rectangle().fill(Theme.line).frame(height: 1)
        }
    }

    private var joinSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Second phone: enter your partner's code")
                .font(.ui(15, weight: .bold))
                .foregroundStyle(Theme.ink)
            TextField("e.g. PLOV42", text: $enteredCode)
                .font(.display(22, weight: .semibold))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($codeFieldFocused)
                .submitLabel(.join)
                .onSubmit { join() }
                .padding(.horizontal, 18)
                .frame(height: 56)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.fieldBorder, lineWidth: 1.5))
            Button("Join") { join() }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(store.isLinking || enteredCode.trimmingCharacters(in: .whitespaces).count < 6)
        }
    }

    private func linkedSection(code: String) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                Text("YOUR PAIR CODE")
                    .font(.ui(12, weight: .heavy))
                    .tracking(0.8)
                    .foregroundStyle(Theme.muted)
                PairCodeView(code: code)
                HStack(spacing: 8) {
                    if store.partnerJoined {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.teal)
                        Text("Your partner has joined. You're all set!")
                    } else {
                        ProgressView()
                        Text("Give this code to your partner. Waiting for them to join…")
                    }
                }
                .font(.ui(14, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
            }
            .padding(20)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.line, lineWidth: 1))

            Button(store.partnerJoined ? "Start swiping" : "Done") {
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func join() {
        codeFieldFocused = false
        Task { await store.joinPair(code: enteredCode) }
    }
}

/// The 6-letter code in big separate boxes.
struct PairCodeView: View {
    let code: String

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(code.enumerated()), id: \.offset) { _, character in
                Text(String(character))
                    .font(.display(24, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Theme.orangeSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pair code \(code.map(String.init).joined(separator: " "))")
    }
}
