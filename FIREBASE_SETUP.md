# Firebase Configuration Setup

## IMPORTANT: Firebase Configuration Update Required

The Firebase configuration files have been updated with the new package name `com.manah.bms`, but you **MUST** regenerate these files from the Firebase Console for production use.

## Steps to Update Firebase Configuration

### 1. Go to Firebase Console
- Visit: https://console.firebase.google.com/
- Select your project: `bms-mobile-794f5`

### 2. Add Android App with New Package Name
1. Click the gear icon (Settings) → Project Settings
2. Under "Your apps", click "Add app"
3. Select Android
4. Enter package name: `com.manah.bms`
5. (Optional) Enter app nickname: `Smart BMS Android`
6. Click "Register app"
7. Download `google-services.json`
8. Replace the existing file at: `android/app/google-services.json`

### 3. Add iOS App with New Bundle Identifier
1. In the same Project Settings, click "Add app"
2. Select iOS
3. Enter bundle ID: `com.manah.bms`
4. (Optional) Enter app nickname: `Smart BMS iOS`
5. Click "Register app"
6. Download `GoogleService-Info.plist`
7. Replace the existing file at: `ios/Runner/GoogleService-Info.plist`

### 4. Update SHA-256 Fingerprint (Android)
After generating your release keystore, you'll need to add the SHA-256 fingerprint:

1. Generate your release keystore (see ANDROID_SIGNING.md)
2. Run this command to get the SHA-256 fingerprint:
   ```bash
   keytool -list -v -keystore path/to/your/keystore.jks -alias your_key_alias
   ```
3. Copy the SHA-256 certificate fingerprint
4. In Firebase Console → Project Settings → Your apps → Android app
5. Add the SHA-256 fingerprint to "SHA certificate fingerprints"

### 5. Enable Required Services
Ensure these services are enabled in Firebase Console:
- **Authentication** (Google Sign-In, Email/Password)
- **Cloud Firestore** (Database)
- **Cloud Messaging** (Push notifications)
- **Crashlytics** (Crash reporting - optional but recommended)

## Current Configuration Status

- ✅ Package name updated to `com.manah.bms`
- ✅ Bundle identifier updated to `com.manah.bms`
- ⚠️ Firebase config files need regeneration from console
- ⚠️ SHA-256 fingerprint needs to be added after keystore creation

## Notes

- The current `google-services.json` has been temporarily updated with the new package name
- This is a temporary workaround - you MUST regenerate the file from Firebase Console
- The certificate hash in the current config is from the debug keystore
- For production, use your release keystore's SHA-256 fingerprint
