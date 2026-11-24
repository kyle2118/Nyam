import Foundation
import FirebaseAuth
import FirebaseFirestore

// What is stored in Firebase (Firestore):
//
// households/{CODE}                         members: [uid, uid], createdAt
// households/{CODE}/dishes/{dishId}         name, category, hasPhoto, photoVersion, ...
// households/{CODE}/photos/{dishId}         data (JPEG, ~200 KB), version
// households/{CODE}/rounds/{day}/swipes/{uid}   order, choices, history, done

struct Household: Codable {
    var members: [String]
    var createdAt: Date
}

struct RemoteDish: Codable {
    var name: String
    var category: DishCategory
    var hasPhoto: Bool
    var photoVersion: Int
    var hidesBuiltInPhoto: Bool?
    var createdAt: Date

    init(_ dish: Dish) {
        name = dish.name
        category = dish.category
        hasPhoto = dish.hasPhoto
        photoVersion = dish.photoVersion
        hidesBuiltInPhoto = dish.hidesBuiltInPhoto
        createdAt = dish.createdAt
    }

    func dish(id: String) -> Dish {
        Dish(
            id: id,
            name: name,
            category: category,
            hasPhoto: hasPhoto,
            photoVersion: photoVersion,
            createdAt: createdAt,
            hidesBuiltInPhoto: hidesBuiltInPhoto
        )
    }
}

struct RemotePhoto: Codable {
    var data: Data
    var version: Int
}

struct RemoteSwipes: Codable {
    var order: [String]
    var choices: [String: SwipeChoice]
    var history: [String]
    /// True when this person has swiped every dish in their deck.
    var done: Bool
    var updatedAt: Date
}

enum SyncError: LocalizedError {
    case codeNotFound
    case householdFull
    case couldNotCreateCode
    case anonymousSignInDisabled

    var errorDescription: String? {
        switch self {
        case .anonymousSignInDisabled:
            return "Anonymous sign-in is turned off in Firebase. Turn it on in Firebase console → Authentication → Sign-in method → Anonymous."
        case .codeNotFound: return "No pair with this code. Check the code and try again."
        case .householdFull: return "This code is already used by two phones."
        case .couldNotCreateCode: return "Couldn't create a code. Please try again."
        }
    }
}

/// Talks to Firebase: sends this phone's changes and listens for the partner's.
@MainActor
final class SyncService {
    let code: String
    let uid: String
    private(set) var day = ""

    var onHousehold: ((Household) -> Void)?
    var onDishes: (([Dish]) -> Void)?
    var onPhotoChanged: ((String, Data, Int) -> Void)?
    var onSwipes: (([String: RemoteSwipes]) -> Void)?
    var onError: ((String) -> Void)?

    private let household: DocumentReference
    private var listeners: [ListenerRegistration] = []
    private var swipesListener: ListenerRegistration?

    init(code: String, uid: String) {
        self.code = code
        self.uid = uid
        household = Firestore.firestore().collection("households").document(code)
    }

    // MARK: - Signing in and pairing

    /// Signs in without any account. The same id is kept on this phone.
    static func signIn() async throws -> String {
        if let user = Auth.auth().currentUser { return user.uid }
        do {
            let result = try await Auth.auth().signInAnonymously()
            return result.user.uid
        } catch let error as NSError where error.code == 17085 { // Firebase "admin restricted operation"
            // Firebase says this when Anonymous sign-in is turned off in the console.
            throw SyncError.anonymousSignInDisabled
        }
    }

    static func createHousehold(uid: String) async throws -> String {
        let households = Firestore.firestore().collection("households")
        for _ in 0..<10 {
            let code = randomCode()
            let ref = households.document(code)
            let existing = try await ref.getDocument()
            if existing.exists { continue }
            let data = try Firestore.Encoder().encode(Household(members: [uid], createdAt: Date()))
            try await ref.setData(data)
            return code
        }
        throw SyncError.couldNotCreateCode
    }

    static func joinHousehold(code: String, uid: String) async throws {
        let ref = Firestore.firestore().collection("households").document(code)
        let snapshot = try await ref.getDocument()
        guard snapshot.exists, let household = try? snapshot.data(as: Household.self) else {
            throw SyncError.codeNotFound
        }
        if household.members.contains(uid) { return }
        guard household.members.count < 2 else { throw SyncError.householdFull }
        try await ref.updateData(["members": FieldValue.arrayUnion([uid])])
    }

    /// 6 characters without look-alikes such as 0/O and 1/I.
    static func randomCode() -> String {
        let characters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in characters.randomElement() ?? "A" })
    }

    // MARK: - Listening

    func start(day: String) {
        stop()

        listeners.append(household.addSnapshotListener { [weak self] snapshot, error in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let error { self.report(error); return }
                guard let snapshot, let household = try? snapshot.data(as: Household.self) else { return }
                self.onHousehold?(household)
            }
        })

        listeners.append(household.collection("dishes").addSnapshotListener { [weak self] snapshot, error in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let error { self.report(error); return }
                guard let snapshot else { return }
                // An empty answer from the phone's cache before the server replies: ignore it.
                if snapshot.metadata.isFromCache && snapshot.isEmpty { return }
                let dishes = snapshot.documents.compactMap { document in
                    (try? document.data(as: RemoteDish.self))?.dish(id: document.documentID)
                }
                self.onDishes?(dishes)
            }
        })

        listeners.append(household.collection("photos").addSnapshotListener { [weak self] snapshot, error in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let error { self.report(error); return }
                guard let snapshot else { return }
                for change in snapshot.documentChanges where change.type != .removed {
                    if let photo = try? change.document.data(as: RemotePhoto.self) {
                        self.onPhotoChanged?(change.document.documentID, photo.data, photo.version)
                    }
                }
            }
        })

        listenToSwipes(day: day)
    }

    /// Follows the swipes of the given day. Called again when the day changes.
    func listenToSwipes(day: String) {
        if day == self.day && swipesListener != nil { return }
        self.day = day
        swipesListener?.remove()
        swipesListener = household.collection("rounds").document(day).collection("swipes")
            .addSnapshotListener { [weak self] snapshot, error in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if let error { self.report(error); return }
                    guard let snapshot else { return }
                    var result: [String: RemoteSwipes] = [:]
                    for document in snapshot.documents {
                        if let swipes = try? document.data(as: RemoteSwipes.self) {
                            result[document.documentID] = swipes
                        }
                    }
                    self.onSwipes?(result)
                }
            }
    }

    func stop() {
        listeners.forEach { $0.remove() }
        listeners = []
        swipesListener?.remove()
        swipesListener = nil
        day = ""
    }

    // MARK: - Sending changes
    // Writes are saved on the phone right away and sent when there's internet.

    func remoteDishIDs() async throws -> Set<String> {
        let snapshot = try await household.collection("dishes").getDocuments()
        return Set(snapshot.documents.map(\.documentID))
    }

    func saveDish(_ dish: Dish) {
        do {
            try household.collection("dishes").document(dish.id)
                .setData(from: RemoteDish(dish), completion: completion)
        } catch {
            report(error)
        }
    }

    func deleteDish(id: String) {
        household.collection("dishes").document(id).delete(completion: completion)
        household.collection("photos").document(id).delete(completion: completion)
    }

    func savePhoto(id: String, data: Data, version: Int) {
        do {
            try household.collection("photos").document(id)
                .setData(from: RemotePhoto(data: data, version: version), completion: completion)
        } catch {
            report(error)
        }
    }

    func deletePhoto(id: String) {
        household.collection("photos").document(id).delete(completion: completion)
    }

    func saveSwipes(_ round: Round, done: Bool) {
        let swipes = RemoteSwipes(
            order: round.order,
            choices: round.choices,
            history: round.history,
            done: done,
            updatedAt: Date()
        )
        do {
            try household.collection("rounds").document(round.day).collection("swipes").document(uid)
                .setData(from: swipes, completion: completion)
        } catch {
            report(error)
        }
    }

    /// Removes the partner, so a phone (for example a reinstalled one) can join again.
    func letPartnerRejoin() async throws {
        try await household.updateData(["members": [uid]])
    }

    // MARK: - Errors

    private var completion: (Error?) -> Void {
        { [weak self] error in
            guard let error else { return }
            MainActor.assumeIsolated {
                self?.report(error)
            }
        }
    }

    private func report(_ error: Error) {
        onError?(error.localizedDescription)
    }
}
