import SwiftUI
import PhotosUI

struct DishEditorView: View {
    @Environment(NyamStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let target: EditorTarget

    @State private var name = ""
    @State private var category: DishCategory = .main
    @State private var newImage: UIImage?
    @State private var removePhoto = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var confirmDelete = false
    @State private var showPasteHelp = false
    @State private var didLoad = false

    private var existing: Dish? {
        if case .edit(let dish) = target { return dish }
        return nil
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The photo to show right now: a newly picked one, or the saved one.
    private var shownImage: UIImage? {
        if let newImage { return newImage }
        if removePhoto { return nil }
        if let existing { return store.photo(for: existing) }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    photoSection
                    nameSection
                    categorySection
                    if existing != nil {
                        Button("Delete dish", role: .destructive) {
                            confirmDelete = true
                        }
                        .font(.ui(16, weight: .bold))
                        .foregroundStyle(Theme.danger)
                        .frame(maxWidth: .infinity, minHeight: 48)
                    }
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(existing == nil ? "New dish" : "Edit dish")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.bold)
                        .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                if let existing {
                    name = existing.name
                    category = existing.category
                }
            }
            .onChange(of: pickerItem) { _, item in
                Task { await loadPicked(item) }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    newImage = image
                    removePhoto = false
                }
                .ignoresSafeArea()
            }
            .confirmationDialog("Delete this dish?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let existing { store.deleteDish(id: existing.id) }
                    dismiss()
                }
            } message: {
                Text("It will be removed from the menu.")
            }
            .alert("Nothing to paste", isPresented: $showPasteHelp) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Copy an image first (for example, long-press a photo in Safari and choose Copy), then tap Paste.")
            }
        }
    }

    // MARK: - Sections

    private var photoSection: some View {
        VStack(spacing: 12) {
            ZStack {
                if let shownImage {
                    Color.clear
                        .overlay {
                            Image(uiImage: shownImage)
                                .resizable()
                                .scaledToFill()
                        }
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Theme.softFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(Theme.fieldBorder, style: StrokeStyle(lineWidth: 2, dash: [7, 6]))
                        )
                    Image(systemName: "photo")
                        .font(.system(size: 38))
                        .foregroundStyle(Theme.muted)
                }
            }
            .frame(height: 250)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            HStack(spacing: 8) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    photoButtonLabel("Photos", systemImage: "photo.on.rectangle")
                }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showCamera = true
                    } label: {
                        photoButtonLabel("Camera", systemImage: "camera")
                    }
                }
                Button {
                    if let image = UIPasteboard.general.image {
                        newImage = image
                        removePhoto = false
                    } else {
                        showPasteHelp = true
                    }
                } label: {
                    photoButtonLabel("Paste", systemImage: "doc.on.clipboard")
                }
            }

            if shownImage != nil {
                Button("Remove photo") {
                    newImage = nil
                    pickerItem = nil
                    removePhoto = true
                }
                .font(.ui(14, weight: .bold))
                .foregroundStyle(Theme.muted)
                .frame(minHeight: 44)
            }
        }
    }

    private func photoButtonLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.ui(14, weight: .bold))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.fieldBorder, lineWidth: 1))
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name")
                .font(.ui(15, weight: .bold))
                .foregroundStyle(Theme.ink)
            TextField("e.g. Ашлям-фу or Pizza", text: $name)
                .font(.ui(18))
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled()
                .padding(.horizontal, 18)
                .frame(height: 54)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.fieldBorder, lineWidth: 1.5))
            Text("Shown exactly as you type it, in Kyrgyz, Russian or English")
                .font(.ui(13))
                .foregroundStyle(Theme.muted)
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category")
                .font(.ui(15, weight: .bold))
                .foregroundStyle(Theme.ink)
            Picker("Category", selection: $category) {
                ForEach(DishCategory.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Actions

    private func loadPicked(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        newImage = image
        removePhoto = false
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        if let existing {
            store.updateDish(
                id: existing.id,
                name: trimmedName,
                category: category,
                newImage: newImage,
                removePhoto: removePhoto
            )
        } else {
            store.addDish(name: trimmedName, category: category, image: newImage)
        }
        dismiss()
    }
}

/// Opens the iPhone camera and returns the photo.
struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
