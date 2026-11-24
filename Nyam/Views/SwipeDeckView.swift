import SwiftUI

struct SwipeDeckView: View {
    @Environment(NyamStore.self) private var store
    @State private var offset: CGSize = .zero
    @State private var isAnimatingOut = false
    @State private var feedbackTrigger = 0

    var body: some View {
        VStack(spacing: 0) {
            progressRow
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

            ZStack {
                // A second "card" peeking from behind, so it feels like a deck.
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Theme.deckShadow)
                    .padding(.horizontal, 10)
                    .offset(y: 12)

                if let dish = store.currentDish {
                    SwipeCard(dish: dish, offset: offset)
                        .id(dish.id)
                        .offset(offset)
                        .rotationEffect(.degrees(Double(offset.width / 18)))
                        .gesture(dragGesture)
                        .accessibilityElement(children: .combine)
                        .accessibilityHint("Swipe right for yes, left for no, up if you're craving it")
                        .accessibilityAction(named: "Yes") { store.swipe(.yes) }
                        .accessibilityAction(named: "No") { store.swipe(.no) }
                        .accessibilityAction(named: "Craving it") { store.swipe(.crave) }
                }
            }
            .padding(.horizontal, 20)

            HStack {
                Text("← No · Yes →\n↑ Craving it")
                    .font(.ui(13, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(3)
                Spacer()
                Button {
                    store.showingReview = true
                } label: {
                    Image(systemName: "checklist")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(width: 44, height: 44)
                        .background(Theme.surface, in: Circle())
                        .overlay(Circle().stroke(Theme.fieldBorder, lineWidth: 1))
                }
                .accessibilityLabel("Review my answers")
                .disabled(store.swipedCount == 0)
                .opacity(store.swipedCount == 0 ? 0.4 : 1)
                Button {
                    store.undo()
                    feedbackTrigger += 1
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                        .font(.ui(14, weight: .bold))
                        .foregroundStyle(Theme.inkSoft)
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                        .background(Theme.surface, in: Capsule())
                        .overlay(Capsule().stroke(Theme.fieldBorder, lineWidth: 1))
                }
                .disabled(store.swipedCount == 0)
                .opacity(store.swipedCount == 0 ? 0.4 : 1)
            }
            .padding(.horizontal, 24)
            .padding(.top, 26)
            .padding(.bottom, 14)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: feedbackTrigger)
    }

    private var progressRow: some View {
        HStack(spacing: 10) {
            ProgressView(value: Double(store.swipedCount), total: Double(max(store.deckTotal, 1)))
                .tint(Theme.orange)
            Text("\(min(store.swipedCount + 1, store.deckTotal)) / \(store.deckTotal)")
                .font(.ui(13, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
                .monospacedDigit()
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isAnimatingOut else { return }
                offset = value.translation
            }
            .onEnded { value in
                guard !isAnimatingOut else { return }
                let moved = value.translation
                let flung = value.predictedEndTranslation
                let goingUp = moved.height < 0 && abs(moved.height) > abs(moved.width)

                let choice: SwipeChoice?
                if goingUp && (moved.height < -110 || flung.height < -450) {
                    choice = .crave
                } else if moved.width > 100 || flung.width > 350 {
                    choice = .yes
                } else if moved.width < -100 || flung.width < -350 {
                    choice = .no
                } else {
                    choice = nil
                }

                guard let choice else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        offset = .zero
                    }
                    return
                }

                let flyAway: CGSize
                switch choice {
                case .yes: flyAway = CGSize(width: 650, height: moved.height)
                case .no: flyAway = CGSize(width: -650, height: moved.height)
                case .crave: flyAway = CGSize(width: moved.width, height: -1000)
                }

                isAnimatingOut = true
                withAnimation(.easeIn(duration: 0.22)) {
                    offset = flyAway
                } completion: {
                    store.swipe(choice)
                    offset = .zero
                    isAnimatingOut = false
                    feedbackTrigger += 1
                }
            }
    }
}

private struct SwipeCard: View {
    let dish: Dish
    let offset: CGSize

    private var goingUp: Bool {
        offset.height < 0 && abs(offset.height) > abs(offset.width)
    }

    private func strength(_ value: CGFloat) -> Double {
        Double(min(max(value / 100, 0), 1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DishImageView(dish: dish, showsPlaceholderLabel: true)
                .overlay(alignment: .topLeading) {
                    Stamp(text: "YES", color: Theme.orangeText, angle: -12)
                        .opacity(goingUp ? 0 : strength(offset.width))
                        .padding(20)
                }
                .overlay(alignment: .topTrailing) {
                    Stamp(text: "NO", color: Theme.inkSoft, angle: 12)
                        .opacity(goingUp ? 0 : strength(-offset.width))
                        .padding(20)
                }
                .overlay(alignment: .bottom) {
                    Stamp(text: "CRAVING", color: Theme.teal, angle: 0)
                        .opacity(goingUp ? strength(-offset.height) : 0)
                        .padding(20)
                }

            VStack(alignment: .leading, spacing: 8) {
                CategoryChip(category: dish.category)
                Text(dish.name)
                    .font(.display(30, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 22)
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Theme.line, lineWidth: 1))
        .shadow(color: Color(hex: 0x32231A).opacity(0.12), radius: 17, x: 0, y: 14)
    }
}

private struct Stamp: View {
    let text: String
    let color: Color
    let angle: Double

    var body: some View {
        Text(text)
            .font(.display(24, weight: .heavy))
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(color, lineWidth: 3))
            .rotationEffect(.degrees(angle))
            .allowsHitTesting(false)
    }
}
