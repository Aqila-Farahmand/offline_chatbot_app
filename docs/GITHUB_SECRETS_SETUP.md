# GitHub Secrets Setup Guide

This guide explains how to configure GitHub repository secrets for Firebase configuration in GitHub Actions workflows.

## When Are GitHub Secrets Required?

### **GitHub Secrets are ONLY needed if:**

- You want to use **GitHub Actions CI/CD** (automated builds, tests, deployments)
- You want to build your app automatically when you push code
- You want to run automated tests in the cloud

### **GitHub Secrets are NOT needed if:**

- You're only developing **locally** on your computer
- You're building the app manually on your machine
- You don't use GitHub Actions workflows

## Alternative: Local Development Setup

If you're **not using GitHub Actions**, you can set up Firebase configuration locally instead:

### Option 1: Use Local Config Files (Recommended for Local Development)

1. Download Firebase config files from [Firebase Console](https://console.firebase.google.com/):

   - `google-services.json` → Place in `android/app/`
   - `GoogleService-Info.plist` → Place in `ios/Runner/` and `macos/Runner/`

2. Generate `firebase_options.dart`:

   ```bash
   # Option A: Use FlutterFire CLI
   flutterfire configure

   # Option B: Use the setup script with local config file
   # 1. Copy .firebase.configs.example to .firebase.configs
   # 2. Fill in your Firebase values
   # 3. Run:
   ./scripts/load_env_and_setup.sh
   ```

See [Firebase Security Setup Guide](./FIREBASE_SECURITY_SETUP.md) for detailed local setup instructions.

---

## When You DO Need GitHub Secrets

If you want to use GitHub Actions for automated builds, follow the steps below.

## Step-by-Step Instructions

### 1. Navigate to Repository Settings

1. Go to your GitHub repository on GitHub.com
2. Click on the **Settings** tab (top navigation bar)
3. In the left sidebar, click on **Secrets and variables** → **Actions**

### 2. Add Repository Secrets

Click the **New repository secret** button and add each secret one by one:

#### Required Secrets

Add the following secrets (click "New repository secret" for each):

##### Common Firebase Project Settings

1. **`FIREBASE_PROJECT_ID`**

   - **Value**: Your Firebase project ID (e.g., `my-project-12345`)
   - **Where to find**: Firebase Console → Project Settings → General → Project ID

2. **`FIREBASE_PROJECT_NUMBER`**

   - **Value**: Your Firebase project number (e.g., `123456789012`)
   - **Where to find**: Firebase Console → Project Settings → General → Project number

3. **`FIREBASE_STORAGE_BUCKET`**
   - **Value**: Your Firebase storage bucket (e.g., `my-project-12345.firebasestorage.app`)
   - **Where to find**: Firebase Console → Project Settings → General → Storage bucket

##### Android Configuration

4. **`FIREBASE_API_KEY_ANDROID`**

   - **Value**: Android API key (starts with `AIzaSy...`)
   - **Where to find**:
     - Download `google-services.json` from Firebase Console → Project Settings → Your Android app
     - Open the file and find `"current_key"` in the `api_key` array
     - Or: Firebase Console → Project Settings → Your Android app → SDK setup and configuration

5. **`FIREBASE_MOBILE_SDK_APP_ID_ANDROID`**
   - **Value**: Android Mobile SDK App ID (format: `1:123456789012:android:abc123def456`)
   - **Where to find**:
     - In `google-services.json`, find `"mobilesdk_app_id"` in the `client` array
     - Or: Firebase Console → Project Settings → Your Android app

##### iOS Configuration

6. **`FIREBASE_API_KEY_IOS`**

   - **Value**: iOS API key (starts with `AIzaSy...`)
   - **Where to find**:
     - Download `GoogleService-Info.plist` from Firebase Console → Project Settings → Your iOS app
     - Open the file and find the `API_KEY` value
     - Or: Firebase Console → Project Settings → Your iOS app → SDK setup and configuration

7. **`FIREBASE_GOOGLE_APP_ID_IOS`**
   - **Value**: iOS Google App ID (format: `1:123456789012:ios:abc123def456`)
   - **Where to find**:
     - In `GoogleService-Info.plist`, find the `GOOGLE_APP_ID` value
     - Or: Firebase Console → Project Settings → Your iOS app

##### Web Configuration

8. **`FIREBASE_API_KEY_WEB`**

   - **Value**: Web API key (starts with `AIzaSy...`)
   - **Where to find**:
     - Firebase Console → Project Settings → General → Your apps → Web app
     - Or: In the Firebase config object shown in the console

9. **`FIREBASE_APP_ID_WEB`**

   - **Value**: Web App ID (format: `1:123456789012:web:abc123def456`)
   - **Where to find**: Firebase Console → Project Settings → General → Your apps → Web app

10. **`FIREBASE_AUTH_DOMAIN_WEB`**

    - **Value**: Auth domain (format: `your-project-id.firebaseapp.com`)
    - **Where to find**: Firebase Console → Project Settings → General → Your apps → Web app

11. **`FIREBASE_MEASUREMENT_ID_WEB`** (Optional but recommended)
    - **Value**: Google Analytics Measurement ID (format: `G-XXXXXXXXXX`)
    - **Where to find**: Firebase Console → Project Settings → General → Your apps → Web app
    - **Note**: Only needed if you're using Google Analytics

#### Optional Secrets (for macOS and Windows)

These are optional and will default to iOS/Web values if not set:

- `FIREBASE_API_KEY_MACOS` (defaults to `FIREBASE_API_KEY_IOS`)
- `FIREBASE_GOOGLE_APP_ID_MACOS` (defaults to `FIREBASE_GOOGLE_APP_ID_IOS`)
- `FIREBASE_API_KEY_WINDOWS` (defaults to `FIREBASE_API_KEY_WEB`)
- `FIREBASE_APP_ID_WINDOWS` (defaults to `FIREBASE_APP_ID_WEB`)
- `FIREBASE_AUTH_DOMAIN_WINDOWS` (defaults to `FIREBASE_AUTH_DOMAIN_WEB`)
- `FIREBASE_MEASUREMENT_ID_WINDOWS` (defaults to `FIREBASE_MEASUREMENT_ID_WEB`)

### 3. Verify Secrets Are Set

After adding all secrets, you should see them listed in the **Secrets** section. The values will be hidden (shown as `••••••••`).

**Important**: You cannot view the secret values after saving them. If you need to update a secret, delete it and create a new one.

## Quick Reference: All Required Secrets

Copy this list to track which secrets you've added:

```
 FIREBASE_PROJECT_ID
 FIREBASE_PROJECT_NUMBER
 FIREBASE_STORAGE_BUCKET
 FIREBASE_API_KEY_ANDROID
 FIREBASE_MOBILE_SDK_APP_ID_ANDROID
 FIREBASE_API_KEY_IOS
 FIREBASE_GOOGLE_APP_ID_IOS
 FIREBASE_API_KEY_WEB
 FIREBASE_APP_ID_WEB
 FIREBASE_AUTH_DOMAIN_WEB
 FIREBASE_MEASUREMENT_ID_WEB (optional)
```

## Finding Firebase Values

### Method 1: From Firebase Console (Recommended)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Click the gear icon → **Project settings**
4. Scroll down to **Your apps** section
5. Click on each app (Android, iOS, Web) to see the configuration values

### Method 2: From Downloaded Config Files

#### For Android:

1. Download `google-services.json` from Firebase Console
2. Open the file and extract:
   - `project_info.project_id` → `FIREBASE_PROJECT_ID`
   - `project_info.project_number` → `FIREBASE_PROJECT_NUMBER`
   - `project_info.storage_bucket` → `FIREBASE_STORAGE_BUCKET`
   - `client[0].api_key[0].current_key` → `FIREBASE_API_KEY_ANDROID`
   - `client[0].client_info.mobilesdk_app_id` → `FIREBASE_MOBILE_SDK_APP_ID_ANDROID`

#### For iOS:

1. Download `GoogleService-Info.plist` from Firebase Console
2. Open the file and extract:
   - `API_KEY` → `FIREBASE_API_KEY_IOS`
   - `GOOGLE_APP_ID` → `FIREBASE_GOOGLE_APP_ID_IOS`
   - `PROJECT_ID` → `FIREBASE_PROJECT_ID`
   - `GCM_SENDER_ID` → `FIREBASE_PROJECT_NUMBER`
   - `STORAGE_BUCKET` → `FIREBASE_STORAGE_BUCKET`

#### For Web:

1. In Firebase Console → Project Settings → Your apps → Web app
2. Copy values from the Firebase SDK configuration object:
   ```javascript
   const firebaseConfig = {
     apiKey: "...", // → FIREBASE_API_KEY_WEB
     authDomain: "...", // → FIREBASE_AUTH_DOMAIN_WEB
     projectId: "...", // → FIREBASE_PROJECT_ID
     storageBucket: "...", // → FIREBASE_STORAGE_BUCKET
     messagingSenderId: "...", // → FIREBASE_PROJECT_NUMBER
     appId: "...", // → FIREBASE_APP_ID_WEB
     measurementId: "...", // → FIREBASE_MEASUREMENT_ID_WEB
   };
   ```

## Testing the Setup

After adding all secrets:

1. Push a commit or create a pull request to trigger the workflow
2. Go to **Actions** tab in your GitHub repository
3. Check the workflow run logs
4. The "Setup Firebase Config" step should complete successfully
5. If it fails, check the error messages - they will indicate which secrets are missing

## Troubleshooting

### "Secret not found" error

- Verify the secret name matches exactly (case-sensitive)
- Ensure you're adding secrets to the correct repository
- Check that you clicked "Add secret" after entering the value

### "Firebase setup script failed" error

- Check that all required secrets are set (see list above)
- Verify the secret values are correct (no extra spaces, correct format)
- Check the workflow logs for specific error messages

### Secrets not accessible in workflow

- Ensure the workflow file uses the correct secret names
- Check that the workflow has permission to access secrets
- For pull requests from forks, secrets are not available by default (this is a GitHub security feature)

## Security Best Practices

1. **Never commit secrets**: Secrets should only be stored in GitHub Secrets, never in code or config files
2. **Use least privilege**: Only grant access to secrets where needed
3. **Rotate regularly**: Periodically rotate your Firebase API keys
4. **Monitor usage**: Check Firebase Console for unusual activity
5. **Restrict API keys**: Configure API key restrictions in Google Cloud Console

## Additional Resources

- [GitHub Docs: Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Firebase Console](https://console.firebase.google.com/)
- [Firebase Security Setup Guide](./FIREBASE_SECURITY_SETUP.md)
