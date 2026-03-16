# PGP Chat — Quick Start Guide

---

## 1. Create Account
- Open app → tap **Sign Up**
- Enter username + password (min 8 chars)

## 2. Generate Your PGP Key
After signup you'll be guided to key generation:
- Enter your **Name** and **Email**
- Set a **passphrase** — this protects your key, **write it down and keep it safe**
- Tap **Generate** → wait ~10 seconds

## 3. Add a Contact
- Open the **drawer menu** (top-left) → **Contacts**
- Tap the **person+ icon** → type the username you want to chat with
- They must also have the app with a PGP key generated

## 4. Start a Chat
- On the home screen tap the **pencil icon**
- Search for a contact and tap their name
- Type your message and tap **Send**
- Messages are **end-to-end encrypted** — only you and the recipient can read them

## 5. Send an Image
- In a chat tap the **📎 attachment icon**
- Pick an image from your gallery
- It uploads and sends encrypted automatically

## 6. Features Overview

| Feature | Where |
|---|---|
| Auto-delete messages | Drawer → Auto Delete |
| Manage devices/sessions | Drawer → Device Management |
| View/export PGP key | Drawer → Manage PGP |
| Add/block contacts | Drawer → Contacts |
| Recover password | Login → "Forgot password?" |

## 7. Important Notes
- 🔑 **Never lose your PGP passphrase** — it cannot be recovered
- 🔒 Messages are encrypted on your device before sending
- 🗑️ Auto-delete is ON by default (24h) — messages delete themselves
- 📵 If you reset your PGP key, **all chat history is wiped**

## 8. Firebase Push Notifications Setup

To enable message push notifications, complete these one-time steps:

1. Create a Firebase project and add Android + iOS apps.
2. Place Android config file at:
	- `pgpchat/android/app/google-services.json`
3. Place iOS config file at:
	- `pgpchat/ios/Runner/GoogleService-Info.plist`
4. In Firebase Console, enable Cloud Messaging for the project.
5. For backend server credentials, create a service account JSON in Firebase.
6. Configure backend env with one of these options:
	- `FIREBASE_SERVICE_ACCOUNT_JSON={...full json...}`
	- `FIREBASE_SERVICE_ACCOUNT_PATH=/absolute/path/to/service-account.json`
7. Restart backend so Firebase Admin initializes.
8. Run app, login, and send a message from another account/device to test delivery.

---
*PGP Chat — your messages are private by design.*
