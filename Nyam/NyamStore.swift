import SwiftUI
import Observation

enum AppTab: Hashable {
    case today
    case menu
}

enum TodayState {
    case emptyMenu
    case swiping
    case waitingForPartner
    case matches([MatchResult])
    case noMatch
}

/// Holds the menu, today's swipes and the partner's swipes.
/// Everything is saved on the phone. When the phones are linked, it is also shared through Firebase.
@MainActor
@Observable
final class NyamStore {
    private(set) var dishes: [Dish] = []
    private(set) var round = Round(day: "", order: [])
    /// nil means the partner hasn't finished today.
    private(set) var partnerChoices: [String: SwipeChoice]?
    private(set) var demoPartnerEnabled = true

    // Linking the two phones
    private(set) var householdCode: String?
    private(set) var partnerJoined = false
    private(set) var isLinking = false
    private(set) var syncError: String?
    /// Goes up when a photo arrives from the partner, so pictures refresh.
    private(set) var photoRevision = 0

    var selectedTab: AppTab = .today
    /// Set by the "Add a dish to the menu" button so the Menu tab opens the editor.
    var pendingAddDish = false
    /// Shows the "My answers" screen.
    var showingReview = false
    /// Shows the "link phones" screen.
    var showingPairing = false

    var isLinked: Bool { householdCode != nil }

    @ObservationIgnored private let storage = LocalStorage()
    @ObservationIgnored private let photoCache = NSCache<NSString, UIImage>()
    @ObservationIgnored private var demoTask: Task<Void, Never>?
    @ObservationIgnored private var sync: SyncService?
    @ObservationIgnored private var myUID: String?
    @ObservationIgnored private let defaults = UserDefaults.standard

    private enum Keys {
        static let householdCode = "householdCode"
        static let pairingSkipped = "pairingSkipped"
    }

    init() {
        if let saved = storage.load() {
            dishes = saved.dishes
            if let savedRound = saved.round { round = savedRound }
            partnerChoices = saved.partnerChoices
            demoPartnerEnabled = saved.demoPartnerEnabled
        } else {
            dishes = SeedMenu.dishes
        }
        storage.migrateLegacyPhotos(for: dishes)

        householdCode = defaults.string(forKey: Keys.householdCode)
        showingPairing = householdCode == nil && !defaults.bool(forKey: Keys.pairingSkipped)
        if isLinked { partnerChoices = nil }

        refreshDay()

        if let code = householdCode {
            Task { await reconnect(code: code) }
        }
    }

    // MARK: - Today

    /// Starts a new round when the day changes. Called on launch and when the app opens.
    func refreshDay() {
        let today = DayKey.today()
        if round.day != today {
            round = Round(day: today, order: dishes.map(\.id).shuffled())
            partnerChoices = nil
            demoTask?.cancel()
            demoTask = nil
            save()
        }
        sync?.listenToSwipes(day: round.day)
        pushMyRound()
        startDemoPartnerIfNeeded()
    }

    var deckDishes: [Dish] {
        round.order.compactMap { id in dishes.first { $0.id == id } }
    }

    var deckTotal: Int { deckDishes.count }

    var swipedCount: Int {
        deckDishes.filter { round.choices[$0.id] != nil }.count
    }

    var currentDish: Dish? {
        deckDishes.first { round.choices[$0.id] == nil }
    }

    var isMyRoundComplete: Bool {
        deckTotal > 0 && currentDish == nil
    }

    var partnerFinished: Bool { partnerChoices != nil }

    var todayState: TodayState {
        if deckTotal == 0 { return .emptyMenu }
        if !isMyRoundComplete { return .swiping }
        guard let partner = partnerChoices else { return .waitingForPartner }

        let results = deckDishes.compactMap { dish -> MatchResult? in
            guard let mine = round.choices[dish.id], mine.isPositive,
                  let theirs = partner[dish.id], theirs.isPositive else { return nil }
            return MatchResult(dish: dish, mine: mine, partner: theirs)
        }
        .sorted { first, second in
            if first.score != second.score { return first.score > second.score }
            return first.dish.name < second.dish.name
        }
        return results.isEmpty ? .noMatch : .matches(results)
    }

    func swipe(_ choice: SwipeChoice) {
        guard let dish = currentDish else { return }
        round.choices[dish.id] = choice
        round.history.append(dish.id)
        save()
        pushMyRound()
        startDemoPartnerIfNeeded()
    }

    func undo() {
        while let last = round.history.popLast() {
            round.choices[last] = nil
            if dishes.contains(where: { $0.id == last }) { break }
        }
        save()
        pushMyRound()
    }

    func myChoice(for dishID: String) -> SwipeChoice? {
        round.choices[dishID]
    }

    /// Dishes you've already swiped today, in the order you saw them.
    var swipedDishes: [Dish] {
        deckDishes.filter { round.choices[$0.id] != nil }
    }

    /// Changes an answer you already gave, from the "My answers" screen.
    func changeChoice(for dishID: String, to choice: SwipeChoice) {
        guard round.choices[dishID] != nil else { return }
        round.choices[dishID] = choice
        save()
        pushMyRound()
    }

    /// Clears only this person's swipes. The partner's answers stay.
    func restartMyRound() {
        round = Round(day: DayKey.today(), order: dishes.map(\.id).shuffled())
        save()
        pushMyRound()
        startDemoPartnerIfNeeded()
    }

    private func pushMyRound() {
        guard let sync, !round.day.isEmpty else { return }
        sync.saveSwipes(round, done: isMyRoundComplete)
    }

    // MARK: - Pretend partner (only before the phones are linked)

    func setDemoPartner(_ enabled: Bool) {
        demoPartnerEnabled = enabled
        demoTask?.cancel()
        demoTask = nil
        if !enabled && !isLinked { partnerChoices = nil }
        save()
        startDemoPartnerIfNeeded()
    }

    private func startDemoPartnerIfNeeded() {
        guard !isLinked, demoPartnerEnabled, isMyRoundComplete, partnerChoices == nil, demoTask == nil else { return }
        demoTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled, let self else { return }
            self.finishDemoPartner()
        }
    }

    private func finishDemoPartner() {
        demoTask = nil
        guard !isLinked, demoPartnerEnabled, partnerChoices == nil else { return }
        var picks: [String: SwipeChoice] = [:]
        for dish in dishes {
            let roll = Double.random(in: 0..<1)
            picks[dish.id] = roll < 0.15 ? .crave : (roll < 0.5 ? .yes : .no)
        }
        partnerChoices = picks
        save()
    }

    // MARK: - Linking phones

    func createPairCode() async {
        isLinking = true
        syncError = nil
        defer { isLinking = false }
        do {
            let uid = try await SyncService.signIn()
            let code = try await SyncService.createHousehold(uid: uid)
            let localDishes = dishes
            link(code: code, uid: uid)
            await uploadLocalMenu(localDishes)
        } catch {
            syncError = error.localizedDescription
        }
    }

    func joinPair(code rawCode: String) async {
        let code = rawCode.uppercased().filter { $0.isLetter || $0.isNumber }
        guard code.count == 6 else {
            syncError = "The code has 6 letters and numbers."
            return
        }
        isLinking = true
        syncError = nil
        defer { isLinking = false }
        do {
            let uid = try await SyncService.signIn()
            try await SyncService.joinHousehold(code: code, uid: uid)
            let localDishes = dishes
            link(code: code, uid: uid)
            await uploadLocalMenu(localDishes)
        } catch {
            syncError = error.localizedDescription
        }
    }

    func skipPairing() {
        defaults.set(true, forKey: Keys.pairingSkipped)
        showingPairing = false
    }

    /// Stops sharing on this phone. The data stays on the phone and in Firebase.
    func unlink() {
        sync?.stop()
        sync = nil
        myUID = nil
        householdCode = nil
        partnerJoined = false
        partnerChoices = nil
        syncError = nil
        defaults.removeObject(forKey: Keys.householdCode)
        defaults.set(true, forKey: Keys.pairingSkipped)
        save()
    }

    func letPartnerRejoin() async {
        do {
            try await sync?.letPartnerRejoin()
        } catch {
            syncError = error.localizedDescription
        }
    }

    private func reconnect(code: String) async {
        do {
            let uid = try await SyncService.signIn()
            link(code: code, uid: uid)
        } catch {
            syncError = error.localizedDescription
        }
    }

    private func link(code: String, uid: String) {
        householdCode = code
        defaults.set(code, forKey: Keys.householdCode)
        myUID = uid
        syncError = nil
        demoTask?.cancel()
        demoTask = nil
        partnerChoices = nil

        let service = SyncService(code: code, uid: uid)
        service.onHousehold = { [weak self] household in
            self?.partnerJoined = household.members.count > 1
        }
        service.onDishes = { [weak self] remoteDishes in
            self?.applyRemoteDishes(remoteDishes)
        }
        service.onPhotoChanged = { [weak self] id, data, version in
            self?.applyRemotePhoto(id: id, data: data, version: version)
        }
        service.onSwipes = { [weak self] swipes in
            self?.applyRemoteSwipes(swipes)
        }
        service.onError = { [weak self] message in
            self?.syncError = message
        }
        sync?.stop()
        sync = service
        service.start(day: round.day)
        pushMyRound()
        save()
    }

    /// After linking, sends dishes that only this phone has (with photos) to the shared menu.
    private func uploadLocalMenu(_ localDishes: [Dish]) async {
        guard let sync else { return }
        do {
            let remoteIDs = try await sync.remoteDishIDs()
            for dish in localDishes where !remoteIDs.contains(dish.id) {
                sync.saveDish(dish)
                if dish.hasPhoto, let data = storage.photoData(id: dish.id, version: dish.photoVersion) {
                    sync.savePhoto(id: dish.id, data: data, version: dish.photoVersion)
                }
            }
        } catch {
            syncError = error.localizedDescription
        }
    }

    private func applyRemoteDishes(_ remoteDishes: [Dish]) {
        dishes = remoteDishes.sorted { $0.createdAt < $1.createdAt }
        save()
    }

    private func applyRemotePhoto(id: String, data: Data, version: Int) {
        storage.savePhoto(data, id: id, version: version)
        photoRevision += 1
    }

    private func applyRemoteSwipes(_ swipes: [String: RemoteSwipes]) {
        guard let uid = myUID else { return }

        if let partner = swipes.first(where: { $0.key != uid })?.value, partner.done {
            partnerChoices = partner.choices
        } else {
            partnerChoices = nil
        }

        // This phone lost its answers (for example after reinstalling): take them back.
        if let mine = swipes[uid], round.history.isEmpty, round.choices.isEmpty, !mine.history.isEmpty {
            round = Round(day: round.day, order: mine.order, choices: mine.choices, history: mine.history)
        }
        save()
    }

    // MARK: - Menu

    func addDish(name: String, category: DishCategory, image: UIImage?) {
        let wasComplete = isMyRoundComplete
        var dish = Dish(name: name, category: category)
        var photoData: Data?
        if let image, let data = PhotoTools.compressedJPEG(from: image) {
            dish.hasPhoto = true
            dish.photoVersion = 1
            storage.savePhoto(data, id: dish.id, version: dish.photoVersion)
            photoData = data
        }
        dishes.append(dish)

        // If you're still swiping today, the new dish joins today's deck.
        // Otherwise it shows up in the next round.
        if !wasComplete {
            let start = round.order.firstIndex { round.choices[$0] == nil } ?? round.order.count
            round.order.insert(dish.id, at: Int.random(in: start...round.order.count))
            pushMyRound()
        }
        save()

        sync?.saveDish(dish)
        if let photoData {
            sync?.savePhoto(id: dish.id, data: photoData, version: dish.photoVersion)
        }
    }

    func updateDish(id: String, name: String, category: DishCategory, newImage: UIImage?, removePhoto: Bool) {
        guard let index = dishes.firstIndex(where: { $0.id == id }) else { return }
        dishes[index].name = name
        dishes[index].category = category
        var newPhotoData: Data?
        if let newImage, let data = PhotoTools.compressedJPEG(from: newImage) {
            dishes[index].hasPhoto = true
            dishes[index].photoVersion += 1
            storage.savePhoto(data, id: id, version: dishes[index].photoVersion)
            newPhotoData = data
        } else if removePhoto {
            storage.deletePhoto(id: id)
            dishes[index].hasPhoto = false
            dishes[index].hidesBuiltInPhoto = true
            dishes[index].photoVersion += 1
            sync?.deletePhoto(id: id)
        }
        let dish = dishes[index]
        save()

        sync?.saveDish(dish)
        if let newPhotoData {
            sync?.savePhoto(id: id, data: newPhotoData, version: dish.photoVersion)
        }
    }

    func deleteDish(id: String) {
        storage.deletePhoto(id: id)
        dishes.removeAll { $0.id == id }
        save()
        sync?.deleteDish(id: id)
    }

    /// Your own photo if you added one, otherwise the built-in photo (starting dishes only).
    func photo(for dish: Dish) -> UIImage? {
        _ = photoRevision // refresh when a photo arrives from the partner
        guard dish.hasPhoto else {
            if dish.hidesBuiltInPhoto == true { return nil }
            return UIImage(named: dish.id)
        }
        let key = "\(dish.id)#\(dish.photoVersion)" as NSString
        if let cached = photoCache.object(forKey: key) { return cached }
        guard let image = storage.loadPhoto(id: dish.id, version: dish.photoVersion) else { return nil }
        photoCache.setObject(image, forKey: key)
        return image
    }

    // MARK: - Saving

    private func save() {
        storage.save(SavedState(
            dishes: dishes,
            round: round,
            partnerChoices: isLinked ? nil : partnerChoices,
            demoPartnerEnabled: demoPartnerEnabled
        ))
    }
}
