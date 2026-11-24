import SwiftUI

/// Shows a dish photo, or a striped colored area when there is no photo yet.
struct DishImageView: View {
    @Environment(NyamStore.self) private var store
    let dish: Dish
    var showsPlaceholderLabel = false

    var body: some View {
        Rectangle()
            .fill(Theme.softFill)
            .overlay {
                if let image = store.photo(for: dish) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    StripedPlaceholder(tint: Theme.tint(for: dish.id), showsLabel: showsPlaceholderLabel)
                }
            }
            .clipped()
    }
}

struct StripedPlaceholder: View {
    let tint: Color
    var showsLabel = false

    var body: some View {
        ZStack {
            tint
            Canvas { context, size in
                let step: CGFloat = 32
                var x: CGFloat = -size.height
                while x < size.width + size.height {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: size.height))
                    path.addLine(to: CGPoint(x: x + size.height, y: 0))
                    context.stroke(path, with: .color(.white.opacity(0.4)), lineWidth: 11)
                    x += step
                }
            }
            if showsLabel {
                VStack(spacing: 8) {
                    Image(systemName: "camera")
                        .font(.system(size: 34, weight: .regular))
                    Text("YOUR PHOTO HERE")
                        .font(.ui(13, weight: .bold))
                        .tracking(0.8)
                }
                .foregroundStyle(Theme.inkSoft)
            }
        }
    }
}

struct CategoryChip: View {
    let category: DishCategory

    var body: some View {
        Text(category.title)
            .font(.ui(12, weight: .bold))
            .foregroundStyle(Theme.inkSoft)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(Theme.softFill, in: Capsule())
    }
}

struct StatusPill: View {
    let text: String
    let isDone: Bool

    var body: some View {
        HStack(spacing: 6) {
            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Theme.teal)
            } else {
                Circle()
                    .fill(Color(hex: 0xB9AEA2))
                    .frame(width: 8, height: 8)
            }
            Text(text)
                .font(.ui(13, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(Theme.surface, in: Capsule())
        .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
    }
}

/// Logo, app name and today's date at the top of the Today tab.
struct TodayHeader: View {
    @Environment(NyamStore.self) private var store
    @Binding var showSettings: Bool

    private static let dateStyle = Date.FormatStyle()
        .weekday(.wide)
        .month(.abbreviated)
        .day()
        .locale(Locale(identifier: "en_US"))

    var body: some View {
        HStack(spacing: 10) {
            Image("NyamLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text("Nyam")
                    .font(.display(22))
                    .foregroundStyle(Theme.ink)
                Text(Date.now, format: Self.dateStyle)
                    .font(.ui(13, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 8)
            StatusPill(
                text: store.partnerFinished ? "Partner: done" : "Partner: not done",
                isDone: store.partnerFinished
            )
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Settings")
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }
}
