# Backend setup (SQLite + Firebase)

Finora is local-first:

* **SQLite** (`sqflite`, file `finora.db`) is the on-device source of truth. The
  app reads and writes only to it, so everything works offline.
* **Firebase Authentication** (email/password) handles sign-in.
* **Cloud Firestore** holds each account's copy of the data. A background sync
  engine (`lib/core/sync/`) pushes queued local writes and pulls changes made on
  other devices, so the same account shows the same figures everywhere.

**Until Firebase is configured the app still runs, fully offline** (as a guest);
sign-in and cloud sync stay disabled and the log shows
`Firebase not configured — cloud sync disabled`.

## How the pieces fit

```
UI → repositories → SQLite boxes (AppDatabase / SqlBox)
                         │  every write is also queued in the outbox
                         ▼
                    SyncEngine ⇄ Firestore  users/{uid}/{categories|accounts|budgets|expenses}/{id}
```

* `lib/core/storage/` — `AppDatabase` opens one SQLite database; `SqlBox` is a
  named key/value collection inside it (table `kv_store`: `box`, `key`, `value`).
  Reads are served from memory, every write is persisted to SQLite first.
* `lib/core/sync/` — outbox queue, per-table cursors, account scoping, and the
  Firestore push/pull engine. `updated_at` is stamped by the Firestore server, so
  device clock skew can't hide changes. Deletes are tombstones (`deleted_at`).
* Guest data never leaves the device; each account's local data is stashed and
  restored on sign-out / sign-in (`SyncScopeStore`).

## 1. Create the Firebase project

1. <https://console.firebase.google.com> → **Add project**.
2. **Add app → Android**. Package name: `com.finora.app`.
   Debug builds use the suffix `.debug`, so also **add a second Android app**
   with package `com.finora.app.debug` (or add it to the same project and
   download the JSON again) — `google-services.json` must contain both clients.
3. Download **`google-services.json`** and place it at
   `android/app/google-services.json`. (It is gitignored.)
4. **Build → Authentication → Sign-in method → Email/Password → Enable.**
   Without this the app reports "Email/password sign-in is not enabled".
5. **Build → Firestore Database → Create database** (production mode, pick a
   region).
6. Publish the security rules in [`firestore.rules`](../firestore.rules) — paste
   them under *Firestore → Rules*, or with the CLI:

   ```bash
   npm i -g firebase-tools
   firebase login
   firebase use <your-project-id>
   firebase deploy --only firestore:rules
   ```

   The rules let a signed-in user touch only `users/{their-uid}/**`.

7. For release builds, add your release keystore's **SHA-1/SHA-256** under
   *Project settings → Your apps* (needed by some Firebase features; email/password
   works without it).

The Gradle build applies the `google-services` plugin only when
`android/app/google-services.json` exists, so a fresh clone still builds.

## 2. Run

```bash
flutter pub get
flutter run
```

Sign up in the app, add an expense, then sign in on a second device (or
reinstall) — the data appears after the first sync round. Watch the sync chip
and the log lines prefixed `SyncEngine:`.

## Data model in Firestore

Each document keeps the same JSON shape as the local rows, plus:

| Field        | Meaning                                              |
| ------------ | ---------------------------------------------------- |
| `id`         | Row id (also the document id)                        |
| `user_id`    | Owner uid (pinned by the engine before every push)   |
| `updated_at` | Firestore server timestamp — drives the pull cursor  |
| `deleted_at` | Set when the row was deleted (tombstone), else absent |

The pull query is a single-field `orderBy('updated_at')`, so no composite index
is needed.

## Password reset / email verification

* **Forgot password** sends Firebase's reset email; the new password is chosen
  on Firebase's hosted page (not inside the app).
* **Sign-up** sends a verification email; the verification screen's "I've
  verified" button reloads the user and re-checks.
* Changing the password of the signed-in user may require a recent sign-in
  (`requires-recent-login`).

## Existing data from the Hive/Supabase version

The previous build stored data in Hive boxes and Supabase. Those are no longer
read: this version starts with an empty SQLite database and an empty Firestore.
