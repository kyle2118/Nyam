import SwiftUI

struct TodayView: View {
    @Environment(NyamStore.self) private var store
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            TodayHeader(showSettings: $showSettings)

            switch store.todayState {
            case .emptyMenu:
                EmptyMenuView()
            case .swiping:
                SwipeDeckView()
            case .waitingForPartner:
                WaitingView()
            case .matches(let results):
                MatchesView(results: results)
            case .noMatch:
                NoMatchView()
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: Binding(
            get: { store.showingReview },
            set: { store.showingReview = $0 }
        )) {
            ReviewView()
        }
    }
}

/// Small text button that opens "My answers".
struct ReviewAnswersButton: View {
    @Environment(NyamStore.self) private var store

    var body: some View {
        Button {
            store.showingReview = true
        } label: {
            Label("Review my answers", systemImage: "checklist")
                .font(.ui(15, weight: .bold))
                .foregroundStyle(Theme.orangeText)
                .frame(minHeight: 44)
        }
    }
}

struct WaitingView: View {
    @Environment(NyamStore.self) private var store

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "hourglass")
                .font(.system(size: 50, weight: .regular))
                .foregroundStyle(Theme.orangeText)
                .frame(width: 132, height: 132)
                .background(Theme.orangeSoft, in: Circle())
            Text("Not complete yet")
                .font(.display(24, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Your partner hasn't finished swiping. Results appear here as soon as you've both finished.")
                .font(.ui(16))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            HStack(spacing: 10) {
                StatusPill(text: "You: done", isDone: true)
                StatusPill(text: "Partner: not done", isDone: false)
            }
            ReviewAnswersButton()
            Button("Redo my swipes") {
                store.restartMyRound()
            }
            .font(.ui(15, weight: .bold))
            .foregroundStyle(Theme.muted)
            .frame(minHeight: 44)
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

struct MatchesView: View {
    let results: [MatchResult]
    @State private var selectedID: String?

    /// The match shown in the big card. Starts with the top match.
    private var selected: MatchResult? {
        results.first { $0.id == selectedID } ?? results.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("It's a match!")
                        .font(.display(30))
                        .foregroundStyle(Theme.ink)
                    Text(results.count == 1 ? "You both want 1 dish today" : "You both want \(results.count) dishes today")
                        .font(.ui(15))
                        .foregroundStyle(Theme.muted)
                }
                .padding(.bottom, 4)

                if let selected {
                    TopMatchCard(result: selected, isTopMatch: selected.id == results.first?.id)
                        .id(selected.id)
                        .transition(.opacity)
                }

                if results.count > 1 {
                    Text("ALL MATCHES · TAP TO VIEW")
                        .font(.ui(12, weight: .heavy))
                        .tracking(0.8)
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                    ForEach(results) { result in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedID = result.id
                            }
                        } label: {
                            MatchRow(result: result, isSelected: result.id == selected?.id)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(result.id == selected?.id ? .isSelected : [])
                    }
                }

                VStack(spacing: 2) {
                    ReviewAnswersButton()
                    Text("A new round starts tomorrow")
                        .font(.ui(14))
                        .foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .sensoryFeedback(.selection, trigger: selectedID)
    }
}

private struct TopMatchCard: View {
    let result: MatchResult
    let isTopMatch: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DishImageView(dish: result.dish)
                .frame(height: 230)
                .overlay(alignment: .topLeading) {
                    if result.mine == .crave && result.partner == .crave {
                        Label("You both crave it", systemImage: "star.fill")
                            .font(.ui(13, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(Theme.teal, in: Capsule())
                            .padding(14)
                    }
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(isTopMatch ? "TOP MATCH" : "MATCH")
                    .font(.ui(12, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(Theme.orangeText)
                Text(result.dish.name)
                    .font(.display(30, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                if !(result.mine == .crave && result.partner == .crave) {
                    Text(result.label)
                        .font(.ui(13, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

private struct MatchRow: View {
    let result: MatchResult
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            DishImageView(dish: result.dish)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(result.dish.name)
                    .font(.display(18, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(result.label)
                    .font(.ui(13, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Image(systemName: isSelected ? "eye.fill" : "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? Theme.orangeText : Theme.muted)
        }
        .padding(12)
        .background(isSelected ? Theme.orangeSoft : Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isSelected ? Theme.orange : Theme.line, lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(Rectangle())
    }
}

struct NoMatchView: View {
    @Environment(NyamStore.self) private var store

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "face.dashed")
                .font(.system(size: 50, weight: .regular))
                .foregroundStyle(Theme.muted)
                .frame(width: 132, height: 132)
                .background(Theme.softFill, in: Circle())
            Text("No match")
                .font(.display(28, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("You didn't both say yes to any dish today.")
                .font(.ui(16))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            VStack(spacing: 10) {
                Button("Swipe again") {
                    store.restartMyRound()
                }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    store.pendingAddDish = true
                    store.selectedTab = .menu
                } label: {
                    Label("Add a dish to the menu", systemImage: "plus")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(.top, 6)
            Text("\"Swipe again\" redoes only your swipes. Your partner's answers stay as they are.")
                .font(.ui(13))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            ReviewAnswersButton()
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

struct EmptyMenuView: View {
    @Environment(NyamStore.self) private var store

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("Your menu is empty")
                .font(.display(24, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Add a few dishes to start swiping.")
                .font(.ui(16))
                .foregroundStyle(Theme.muted)
            Button {
                store.pendingAddDish = true
                store.selectedTab = .menu
            } label: {
                Label("Add a dish", systemImage: "plus")
            }
            .buttonStyle(PrimaryButtonStyle())
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

struct SettingsView: View {
    @Environment(NyamStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var confirmUnlink = false

    var body: some View {
        NavigationStack {
            Form {
                if let code = store.householdCode {
                    Section {
                        LabeledContent("Pair code", value: code)
                        LabeledContent("Partner", value: store.partnerJoined ? "Linked" : "Not joined yet")
                        Button("Let partner link again") {
                            Task { await store.letPartnerRejoin() }
                        }
                    } header: {
                        Text("Linked phones")
                    } footer: {
                        Text("Use \"Let partner link again\" only if your partner's phone lost the link (for example after deleting the app). Then they enter the code again.")
                    }

                    Section {
                        Button("Unlink this phone", role: .destructive) {
                            confirmUnlink = true
                        }
                    }
                } else {
                    Section {
                        Button("Link with partner's phone") {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                store.showingPairing = true
                            }
                        }
                    } footer: {
                        Text("Your swipes are only on this phone until you link.")
                    }

                    Section {
                        Toggle("Pretend partner", isOn: Binding(
                            get: { store.demoPartnerEnabled },
                            set: { store.setDemoPartner($0) }
                        ))
                    } footer: {
                        Text("For testing on one phone. A pretend partner swipes randomly a few seconds after you finish.")
                    }
                }

                if let error = store.syncError {
                    Section("Sync problem") {
                        Text(error)
                            .foregroundStyle(Theme.danger)
                    }
                }

                Section {
                    Button("Start my swipes over") {
                        store.restartMyRound()
                        dismiss()
                    }
                } footer: {
                    Text("Only your own swipes are cleared.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Unlink this phone?", isPresented: $confirmUnlink, titleVisibility: .visible) {
                Button("Unlink", role: .destructive) {
                    store.unlink()
                }
            } message: {
                Text("This phone stops sharing swipes and dishes. You can link again later with the same code.")
            }
        }
    }
}
