import SwiftUI

enum EditorTarget: Identifiable {
    case new
    case edit(Dish)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let dish): return dish.id
        }
    }
}

struct MenuView: View {
    @Environment(NyamStore.self) private var store
    @State private var editor: EditorTarget?

    private var mainDishes: [Dish] { store.dishes.filter { $0.category == .main } }
    private var soups: [Dish] { store.dishes.filter { $0.category == .soup } }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.dishes.count == 1 ? "1 dish" : "\(store.dishes.count) dishes")
                        .font(.ui(13, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                    Text("Menu")
                        .font(.display(28))
                        .foregroundStyle(Theme.ink)
                }
                Spacer()
                Button {
                    editor = .new
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 48, height: 48)
                        .background(Theme.orange, in: Circle())
                }
                .accessibilityLabel("Add dish")
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 12)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    section(title: "Main dishes", dishes: mainDishes)
                    section(title: "Soups", dishes: soups)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .sheet(item: $editor) { target in
            DishEditorView(target: target)
        }
        .onChange(of: store.pendingAddDish, initial: true) { _, wantsAdd in
            if wantsAdd {
                store.pendingAddDish = false
                editor = .new
            }
        }
    }

    @ViewBuilder
    private func section(title: String, dishes: [Dish]) -> some View {
        if !dishes.isEmpty {
            Text(title.uppercased())
                .font(.ui(12, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(Theme.muted)
                .padding(.top, 10)
                .padding(.leading, 4)
            ForEach(dishes) { dish in
                Button {
                    editor = .edit(dish)
                } label: {
                    MenuRow(dish: dish)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct MenuRow: View {
    @Environment(NyamStore.self) private var store
    let dish: Dish

    var body: some View {
        HStack(spacing: 14) {
            DishImageView(dish: dish)
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(dish.name)
                    .font(.display(16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(store.photo(for: dish) != nil ? dish.category.title : "\(dish.category.title) · No photo yet")
                    .font(.ui(13, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.muted)
        }
        .padding(10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line, lineWidth: 1))
        .contentShape(Rectangle())
    }
}
