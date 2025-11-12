# Firebase Security - Quick Start

## If Files Are Already Committed

If your Firebase config files are already in git history, you need to remove them:

```bash
# 1. Remove from git tracking (but keep local files)
git rm --cached android/app/google-services.json
git rm --cached ios/Runner/GoogleService-Info.plist
git rm --cached macos/Runner/GoogleService-Info.plist

# 2. Commit the removal
git commit -m "Remove sensitive Firebase config files from version control"

# 3. (Optional) Remove from git history completely
# WARNING: This rewrites history and requires force push
./scripts/remove_sensitive_files_from_git.sh
```

## For New Setup

1. **Copy your Firebase config files** (download from Firebase Console):

   ```bash
   # Android
   cp /path/to/google-services.json android/app/google-services.json

   # iOS
   cp /path/to/GoogleService-Info.plist ios/Runner/GoogleService-Info.plist

   # macOS (if needed)
   cp /path/to/GoogleService-Info.plist macos/Runner/GoogleService-Info.plist
   ```

2. **Verify they're gitignored**:

   ```bash
   git status
   # These files should NOT appear
   ```

3. **Done!** Your files are now secure and won't be committed.

## 🔄 For CI/CD

Use environment variables with the setup script:

```bash
export FIREBASE_PROJECT_ID="your-project-id"
export FIREBASE_PROJECT_NUMBER="your-project-number"
# ... (see docs/FIREBASE_SECURITY_SETUP.md for full list)

./scripts/setup_firebase_config.sh
```

See [FIREBASE_SECURITY_SETUP.md](FIREBASE_SECURITY_SETUP.md) for complete documentation.
