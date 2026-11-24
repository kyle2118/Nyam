import SwiftUI

/// "My answers": every dish you've swiped today, with a way to change the answer.
struct ReviewView: View {
    @Environment(NyamStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    if store.swipedDishes.isEmpty {
                        Text("You haven't swiped any dishes yet today.")
                            .font(.ui(16))
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                            .padding(.top, 60)
                    } else {
                        Text("Tap a different answer to change it.")
                            .font(.ui(14))
                            .foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(store.swipedDishes) { dish in
                            ReviewRow(dish: dish)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("My answers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.bold)
                }
            }
        }
    }
}

private struct ReviewRow: View {
    @Environment(NyamStore.self) private var store
    let dish: Dish

    private var current: SwipeChoice? { store.myChoice(for: dish.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                DishImageView(dish: dish)
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(dish.name)
                        .font(.display(17, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(dish.category.title)
                        .font(.ui(13, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                choiceButton(.no, title: "No", systemImage: "xmark")
                choiceButton(.yes, title: "Yes", systemImage: "heart.fill")
                choiceButton(.crave, title: "Craving", systemImage: "star.fill")
            }
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line, lineWidth: 1))
        .sensoryFeedback(.selection, trigger: current)
    }

    private func choiceButton(_ choice: SwipeChoice, title: String, systemImage: String) -> some View {
        let isSelected = current == choice
        let fill: Color
        let text: Color
        switch choice {
        case .no:
            fill = Theme.inkSoft
            text = .white
        case .yes:
            fill = Theme.orange
            text = Theme.ink
        case .crave:
            fill = Theme.teal
            text = .white
        }

        return Button {
            store.changeChoice(for: dish.id, to: choice)
        } label: {
            Label(title, systemImage: systemImage)
                .font(.ui(14, weight: .bold))
                .foregroundStyle(isSelected ? text : Theme.muted)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(isSelected ? fill : Theme.surface, in: Capsule())
                .overlay(Capsule().stroke(isSelected ? fill : Theme.fieldBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
