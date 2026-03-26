# Firestore security rules strategy

Deploy these in the Firebase Console (Firestore → Rules). They are **not** applied automatically from this repo.

## Goals

- Users may **read only their own** document in `users` (`users/{userId}` where `userId` matches `request.auth.uid`).
- **No client** should be allowed to change their own `role` or create arbitrary admin accounts.
- Writes to `users` (creating or updating profiles) should go through **trusted paths**: Firebase Console (manual), **Admin SDK** in Cloud Functions, or a **Callable Function** that verifies the caller is an admin.

## Example rules (sketch)

Adjust collection names and admin checks to match how you set admin (e.g. custom claims from a backend).

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if false;
    }
  }
}
```

With `allow write: if false`, all client writes are denied; you manage documents in Console or via Admin SDK / Functions.

If you later add `allow create` for self-registration, do **not** allow setting `role` to admin from the client—default `role` server-side only.

## Why this matters

If rules allow any authenticated user to update `users/{uid}`, they can set `role` to `1` (admin) in the console or via a REST call. Application UI checks are not security; **rules (or trusted backends) are.**
