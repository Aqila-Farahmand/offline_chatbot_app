# Firebase Security Setup Guide

This document explains how to securely manage Firebase configuration files and API keys in this project.

## Security Strategy

### Problem

Firebase configuration files (`google-services.json`, `GoogleService-Info.plist`) contain API keys and project information that should not be committed to version control.

### Solution

1. **Native config files are gitignored**: The actual Firebase config files are excluded from version control
2. **Template files provided**: Example files (`.example`) are provided as templates
3. **Environment variable support**: CI/CD can use environment variables to generate configs
4. **Secure config loading**: Flutter code uses config files from `lib/config/firebase/` which are also gitignored

## Setup Instructions

### For Local Development

1. **Get your Firebase config files**:

   - Download `google-services.json` from [Firebase Console](https://console.firebase.google.com/) → Project Settings → Your Android app
   - Download `GoogleService-Info.plist` from Firebase Console → Project Settings → Your iOS app

2. **Place the files**:

   ```bash
   # Android
   cp /path/to/downloaded/google-services.json android/app/google-services.json

   # iOS
   cp /path/to/downloaded/GoogleService-Info.plist ios/Runner/GoogleService-Info.plist
   ```

3. **Verify they're gitignored**:
   ```bash
   git status
   # These files should NOT appear in the output
   ```

### For CI/CD (Automated Builds)

Use the provided setup script with environment variables:

```bash
# Set required environment variables
export FIREBASE_PROJECT_ID="your-project-id"
export FIREBASE_PROJECT_NUMBER="your-project-number"
export FIREBASE_STORAGE_BUCKET="your-storage-bucket"
export FIREBASE_API_KEY_ANDROID="your-android-api-key"
export FIREBASE_MOBILE_SDK_APP_ID_ANDROID="your-android-app-id"
export FIREBASE_API_KEY_IOS="your-ios-api-key"
export FIREBASE_GOOGLE_APP_ID_IOS="your-ios-app-id"

# Run the setup script
./scripts/setup_firebase_config.sh
```

**For GitHub Actions**, add these as secrets in your repository settings and reference them in your workflow:

```yaml
- name: Setup Firebase Config
  env:
    FIREBASE_PROJECT_ID: ${{ secrets.FIREBASE_PROJECT_ID }}
    FIREBASE_PROJECT_NUMBER: ${{ secrets.FIREBASE_PROJECT_NUMBER }}
    FIREBASE_STORAGE_BUCKET: ${{ secrets.FIREBASE_STORAGE_BUCKET }}
    FIREBASE_API_KEY_ANDROID: ${{ secrets.FIREBASE_API_KEY_ANDROID }}
    FIREBASE_MOBILE_SDK_APP_ID_ANDROID: ${{ secrets.FIREBASE_MOBILE_SDK_APP_ID_ANDROID }}
    FIREBASE_API_KEY_IOS: ${{ secrets.FIREBASE_API_KEY_IOS }}
    FIREBASE_GOOGLE_APP_ID_IOS: ${{ secrets.FIREBASE_GOOGLE_APP_ID_IOS }}
  run: ./scripts/setup_firebase_config.sh
```

## Security Best Practices

### 1. API Key Restrictions

Even though these API keys are client-side, you should restrict them in Firebase Console:

- Go to [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → Credentials
- Click on your API key
- Under "Application restrictions":
  - **Android**: Restrict by package name (`it.aqila.farahmand.medicoai`)
  - **iOS**: Restrict by bundle ID (`it.aqila.farahmand.medicoai.ios`)
  - **Web**: Restrict by HTTP referrer (your domain)
- Under "API restrictions": Limit to only Firebase services you use

### 2. Firestore Security Rules

Ensure your Firestore security rules are properly configured:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Only authenticated users can read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Add more restrictive rules as needed
  }
}
```

### 3. Firebase App Check

Consider enabling [Firebase App Check](https://firebase.google.com/docs/app-check) for additional security:

- Helps protect your backend resources from abuse
- Validates that requests come from your authentic app

### 4. Never Commit Sensitive Files

The following files are gitignored and should NEVER be committed:

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `macos/Runner/GoogleService-Info.plist`
- `lib/config/firebase/*.dart` (contains API keys)
- `lib/config/admin_config.dart` (contains admin credentials)

## File Structure

```
project/
├── android/app/
│   ├── google-services.json          # Gitignored - actual config
│   └── google-services.json.example  # Template file (committed)
├── ios/Runner/
│   ├── GoogleService-Info.plist      # Gitignored - actual config
│   └── GoogleService-Info.plist.example  # Template file (committed)
├── lib/config/firebase/              # Gitignored - contains API keys
│   ├── android_config.dart
│   ├── ios_config.dart
│   └── ...
└── scripts/
    └── setup_firebase_config.sh      # Script to generate configs from env vars
```

## Troubleshooting

### Build fails with "google-services.json not found"

- Ensure you've copied the file to `android/app/google-services.json`
- Verify the file is not gitignored (it should be, but check it exists locally)

### "API key not valid" errors

- Check that API key restrictions allow your app's package name/bundle ID
- Verify the API key is correct in your config files
- Ensure Firebase services are enabled in Firebase Console

### Config files keep getting committed

- Check `.gitignore` includes the files
- If files were previously committed, remove them from git:
  ```bash
  git rm --cached android/app/google-services.json
  git rm --cached ios/Runner/GoogleService-Info.plist
  ```

## Additional Resources

- [Firebase Security Rules](https://firebase.google.com/docs/rules)
- [Firebase App Check](https://firebase.google.com/docs/app-check)
- [API Key Best Practices](https://cloud.google.com/docs/authentication/api-keys)
