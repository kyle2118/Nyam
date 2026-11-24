import UIKit

/// Everything the app saves on this phone.
struct SavedState: Codable {
    var dishes: [Dish]
    var round: Round?
    var partnerChoices: [String: SwipeChoice]?
    var demoPartnerEnabled: Bool
}

/// Saves data as a JSON file and photos as JPEG files in the app's Documents folder.
/// When the phones are linked, this is a copy of what's in Firebase, so the app opens instantly.
final class LocalStorage {
    private let stateURL: URL
    private let photosFolder: URL

    init() {
        let fileManager = FileManager.default
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        stateURL = documents.appendingPathComponent("nyam-state.json")
        photosFolder = documents.appendingPathComponent("Photos", isDirectory: true)
        try? fileManager.createDirectory(at: photosFolder, withIntermediateDirectories: true)
    }

    func load() -> SavedState? {
        guard let data = try? Data(contentsOf: stateURL) else { return nil }
        return try? JSONDecoder().decode(SavedState.self, from: data)
    }

    func save(_ state: SavedState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: stateURL, options: .atomic)
    }

    // MARK: - Photos (one file per dish, named with its version)

    private func photoURL(id: String, version: Int) -> URL {
        photosFolder.appendingPathComponent("\(id)_v\(version).jpg")
    }

    private func legacyPhotoURL(id: String) -> URL {
        photosFolder.appendingPathComponent("\(id).jpg")
    }

    func savePhoto(_ data: Data, id: String, version: Int) {
        deletePhoto(id: id)
        try? data.write(to: photoURL(id: id, version: version), options: .atomic)
    }

    func loadPhoto(id: String, version: Int) -> UIImage? {
        UIImage(contentsOfFile: photoURL(id: id, version: version).path)
    }

    func photoData(id: String, version: Int) -> Data? {
        try? Data(contentsOf: photoURL(id: id, version: version))
    }

    func deletePhoto(id: String) {
        let fileManager = FileManager.default
        let names = (try? fileManager.contentsOfDirectory(atPath: photosFolder.path)) ?? []
        for name in names where name == "\(id).jpg" || name.hasPrefix("\(id)_v") {
            try? fileManager.removeItem(at: photosFolder.appendingPathComponent(name))
        }
    }

    /// Photos saved by the first version of the app had no version in their name.
    func migrateLegacyPhotos(for dishes: [Dish]) {
        let fileManager = FileManager.default
        for dish in dishes where dish.hasPhoto {
            let old = legacyPhotoURL(id: dish.id)
            let new = photoURL(id: dish.id, version: dish.photoVersion)
            if fileManager.fileExists(atPath: old.path) && !fileManager.fileExists(atPath: new.path) {
                try? fileManager.moveItem(at: old, to: new)
            }
        }
    }
}

enum PhotoTools {
    /// Shrinks a photo to at most 1000 px on its longest side and about 200 KB,
    /// small enough to store in Firebase and share between phones.
    static func compressedJPEG(from image: UIImage, maxDimension: CGFloat = 1000, maxBytes: Int = 200_000) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }

        var quality: CGFloat = 0.75
        var data = resized.jpegData(compressionQuality: quality)
        while let current = data, current.count > maxBytes, quality > 0.3 {
            quality -= 0.1
            data = resized.jpegData(compressionQuality: quality)
        }
        return data
    }
}
