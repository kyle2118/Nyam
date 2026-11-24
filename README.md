# Nyam

**Tinder for food, for two.** Every day we decide what to eat. Instead of arguing, we both swipe through our dishes on our own phones, and Nyam shows the dishes we both want.

An iOS app built for personal use on two iPhones, not published on the App Store, and free to run.

## Features

- **Daily round:** every day each person gets all the dishes in their own random order.
- **Swipe:** right for yes, left for no, up when you're craving it. Undo goes back one card.
- **My answers:** review today's swipes and change any answer.
- **Matches:** results appear when both people have finished. Dishes you both crave come first. Tap any match to see its photo.
- **No match:** swipe again (only your own answers are reset) or add a new dish to the menu.
- **Menu:** add, edit and delete dishes, grouped into main dishes and soups. Photos can come from the photo library, the camera, or the clipboard.
- **Sync:** two phones link once with a 6-character pair code. Swipes, dishes and photos are shared live through Firebase, and everything still works offline.
- **Names as typed:** dish names are shown exactly as entered (Kyrgyz, Russian or English). The rest of the app is in English.

## Tech

- SwiftUI, iOS 18+, Xcode 26
- Firebase (free Spark plan):
  - **Authentication:** anonymous sign-in, so there are no accounts or passwords.
  - **Cloud Firestore:** shared data, real-time listeners and offline cache.
- Photos are shrunk to about 1000 px / 200 KB and stored in Firestore, so Firebase Storage (which needs a paid plan) isn't used.

### Data in Firestore

```
households/{CODE}                             members: [uid, uid], createdAt
households/{CODE}/dishes/{dishId}             name, category, hasPhoto, photoVersion, ...
households/{CODE}/photos/{dishId}             data (JPEG), version
households/{CODE}/rounds/{yyyy-MM-dd}/swipes/{uid}   order, choices, history, done
```

`firestore.rules` lets only the two members of a household read or write its data. A code accepts a second phone only while it has room.

### Project layout

```
Nyam/
  NyamApp.swift          app entry, Firebase setup
  NyamStore.swift        app state: menu, today's round, matches, linking
  SyncService.swift      Firebase reads, writes and live listeners
  LocalStorage.swift     on-device cache (JSON + photos) and photo compression
  Models.swift           Dish, Round, MatchResult, starting menu
  Theme.swift            colors, fonts, button styles
  Views/                 Today (swipe, waiting, matches), Menu, dish editor,
                         My answers, pairing, settings
  Assets.xcassets        app icon, logo, built-in dish photos
firestore.rules          Firestore security rules
```

## Setup

### 1. Firebase
1. Create a project at [console.firebase.google.com](https://console.firebase.google.com) (Google Analytics not needed).
2. **Add app → iOS** with the bundle ID set in Xcode (Signing & Capabilities).
3. Download `GoogleService-Info.plist` and put it in the `Nyam/` folder (next to `NyamApp.swift`).
   This file is **not in the repository** (it's in `.gitignore`) because it belongs to one Firebase project.
   The app can't start without it, so every setup needs its own.
4. **Firestore → Create database** in production mode, then paste `firestore.rules` into the **Rules** tab and click **Publish**.
5. **Authentication → Sign-in method → Anonymous → Enable**.

### 2. Run in Xcode
1. Open `Nyam.xcodeproj`. Xcode downloads the Firebase package the first time.
2. **Signing & Capabilities:** choose your team. A free Apple ID ("Personal Team") works.
   If the bundle ID is taken, change it here and in Firebase.
3. Pick a simulator or an iPhone and press **Run**.

### 3. Install on iPhones (free Apple ID)
1. Connect the iPhone and tap **Trust This Computer**.
2. On the iPhone: **Settings → Privacy & Security → Developer Mode → On**, then restart.
3. Run from Xcode with the iPhone selected.
4. On the iPhone: **Settings → General → VPN & Device Management** → your Apple ID → **Trust**.

The second phone can use a different Apple ID, because the app is signed with yours.
With a free Apple ID the app stops opening after **7 days**. Run it from Xcode again to renew it; the data is kept.

### 4. Link the phones
On the first phone tap **Create a pair code**. On the second, enter the code and tap **Join**.
Before linking, a "Pretend partner" (in Settings) lets you test on one phone.
