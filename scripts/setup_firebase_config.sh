#!/bin/bash

# Script to set up Firebase configuration files from environment variables or secure sources
# This script generates:
# 1. Native Firebase config files (google-services.json, GoogleService-Info.plist)
# 2. lib/firebase_options.dart (generated directly from .firebase.configs, no intermediate files needed)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Setting up Firebase configuration files...${NC}"

# Check if required environment variables are set
REQUIRED_VARS=(
    "FIREBASE_PROJECT_ID"
    "FIREBASE_PROJECT_NUMBER"
    "FIREBASE_STORAGE_BUCKET"
    "FIREBASE_API_KEY_ANDROID"
    "FIREBASE_MOBILE_SDK_APP_ID_ANDROID"
    "FIREBASE_API_KEY_IOS"
    "FIREBASE_GOOGLE_APP_ID_IOS"
    "FIREBASE_API_KEY_WEB"
    "FIREBASE_APP_ID_WEB"
    "FIREBASE_AUTH_DOMAIN_WEB"
)

MISSING_VARS=()
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo -e "${YELLOW}Warning: Some required environment variables are not set.${NC}"
    echo "Missing variables:"
    for var in "${MISSING_VARS[@]}"; do
        echo "  - $var"
    done
    echo ""
    echo "Required variables for all platforms:"
    echo "  - FIREBASE_PROJECT_ID"
    echo "  - FIREBASE_PROJECT_NUMBER"
    echo "  - FIREBASE_STORAGE_BUCKET"
    echo "  - FIREBASE_API_KEY_ANDROID"
    echo "  - FIREBASE_MOBILE_SDK_APP_ID_ANDROID"
    echo "  - FIREBASE_API_KEY_IOS"
    echo "  - FIREBASE_GOOGLE_APP_ID_IOS"
    echo "  - FIREBASE_API_KEY_WEB"
    echo "  - FIREBASE_APP_ID_WEB"
    echo "  - FIREBASE_AUTH_DOMAIN_WEB"
    echo "  - FIREBASE_MEASUREMENT_ID_WEB (optional)"
    echo ""
    echo "Optional variables:"
    echo "  - FIREBASE_API_KEY_MACOS (defaults to FIREBASE_API_KEY_IOS)"
    echo "  - FIREBASE_GOOGLE_APP_ID_MACOS (defaults to FIREBASE_GOOGLE_APP_ID_IOS)"
    echo "  - FIREBASE_API_KEY_WINDOWS (defaults to FIREBASE_API_KEY_WEB)"
    echo "  - FIREBASE_APP_ID_WINDOWS (defaults to FIREBASE_APP_ID_WEB)"
    echo "  - FIREBASE_AUTH_DOMAIN_WINDOWS (defaults to FIREBASE_AUTH_DOMAIN_WEB)"
    echo "  - FIREBASE_MEASUREMENT_ID_WINDOWS (defaults to FIREBASE_MEASUREMENT_ID_WEB)"
    echo ""
    echo -e "${YELLOW}Please set these variables or copy from example files manually.${NC}"
    exit 1
fi

# Generate Android google-services.json
echo -e "${GREEN}Generating android/app/google-services.json...${NC}"
cat > android/app/google-services.json << EOF
{
  "project_info": {
    "project_number": "${FIREBASE_PROJECT_NUMBER}",
    "project_id": "${FIREBASE_PROJECT_ID}",
    "storage_bucket": "${FIREBASE_STORAGE_BUCKET}"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "${FIREBASE_MOBILE_SDK_APP_ID_ANDROID}",
        "android_client_info": {
          "package_name": "it.aqila.farahmand.medicoai"
        }
      },
      "oauth_client": [],
      "api_key": [
        {
          "current_key": "${FIREBASE_API_KEY_ANDROID}"
        }
      ],
      "services": {
        "appinvite_service": {
          "other_platform_oauth_client": []
        }
      }
    }
  ],
  "configuration_version": "1"
}
EOF

# Generate iOS GoogleService-Info.plist
if [ -n "$FIREBASE_GOOGLE_APP_ID_IOS" ]; then
    echo -e "${GREEN}Generating ios/Runner/GoogleService-Info.plist...${NC}"
    cat > ios/Runner/GoogleService-Info.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>API_KEY</key>
	<string>${FIREBASE_API_KEY_IOS}</string>
	<key>GCM_SENDER_ID</key>
	<string>${FIREBASE_PROJECT_NUMBER}</string>
	<key>PLIST_VERSION</key>
	<string>1</string>
	<key>BUNDLE_ID</key>
	<string>it.aqila.farahmand.medicoai.ios</string>
	<key>PROJECT_ID</key>
	<string>${FIREBASE_PROJECT_ID}</string>
	<key>STORAGE_BUCKET</key>
	<string>${FIREBASE_STORAGE_BUCKET}</string>
	<key>IS_ADS_ENABLED</key>
	<false></false>
	<key>IS_ANALYTICS_ENABLED</key>
	<false></false>
	<key>IS_APPINVITE_ENABLED</key>
	<true></true>
	<key>IS_GCM_ENABLED</key>
	<true></true>
	<key>IS_SIGNIN_ENABLED</key>
	<true></true>
	<key>GOOGLE_APP_ID</key>
	<string>${FIREBASE_GOOGLE_APP_ID_IOS}</string>
</dict>
</plist>
EOF
fi

# Generate macOS GoogleService-Info.plist (optional, uses same config as iOS if not specified)
if [ -n "$FIREBASE_GOOGLE_APP_ID_MACOS" ] || [ -n "$FIREBASE_GOOGLE_APP_ID_IOS" ]; then
    MACOS_APP_ID=${FIREBASE_GOOGLE_APP_ID_MACOS:-$FIREBASE_GOOGLE_APP_ID_IOS}
    MACOS_API_KEY=${FIREBASE_API_KEY_MACOS:-$FIREBASE_API_KEY_IOS}
    echo -e "${GREEN}Generating macos/Runner/GoogleService-Info.plist...${NC}"
    cat > macos/Runner/GoogleService-Info.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>API_KEY</key>
	<string>${MACOS_API_KEY}</string>
	<key>GCM_SENDER_ID</key>
	<string>${FIREBASE_PROJECT_NUMBER}</string>
	<key>PLIST_VERSION</key>
	<string>1</string>
	<key>BUNDLE_ID</key>
	<string>it.aqila.farahmand.medicoai</string>
	<key>PROJECT_ID</key>
	<string>${FIREBASE_PROJECT_ID}</string>
	<key>STORAGE_BUCKET</key>
	<string>${FIREBASE_STORAGE_BUCKET}</string>
	<key>IS_ADS_ENABLED</key>
	<false></false>
	<key>IS_ANALYTICS_ENABLED</key>
	<false></false>
	<key>IS_APPINVITE_ENABLED</key>
	<true></true>
	<key>IS_GCM_ENABLED</key>
	<true></true>
	<key>IS_SIGNIN_ENABLED</key>
	<true></true>
	<key>GOOGLE_APP_ID</key>
	<string>${MACOS_APP_ID}</string>
</dict>
</plist>
EOF
fi

# Generate firebase_options.dart directly from environment variables
# This eliminates the need for intermediate config files in lib/config/firebase/
echo -e "${GREEN}Generating lib/firebase_options.dart...${NC}"

# Set defaults for optional variables
MACOS_API_KEY=${FIREBASE_API_KEY_MACOS:-$FIREBASE_API_KEY_IOS}
MACOS_APP_ID=${FIREBASE_GOOGLE_APP_ID_MACOS:-$FIREBASE_GOOGLE_APP_ID_IOS}
WINDOWS_API_KEY=${FIREBASE_API_KEY_WINDOWS:-$FIREBASE_API_KEY_WEB}
WINDOWS_APP_ID=${FIREBASE_APP_ID_WINDOWS:-$FIREBASE_APP_ID_WEB}
WINDOWS_AUTH_DOMAIN=${FIREBASE_AUTH_DOMAIN_WINDOWS:-$FIREBASE_AUTH_DOMAIN_WEB}
WINDOWS_MEASUREMENT_ID=${FIREBASE_MEASUREMENT_ID_WINDOWS:-$FIREBASE_MEASUREMENT_ID_WEB}

cat > lib/firebase_options.dart << EOF
// File generated from .firebase.configs
// WARNING: This file contains REAL Firebase API keys and credentials
// DO NOT edit manually - changes will be overwritten
// Regenerate with: ./scripts/load_env_and_setup.sh
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the setup script again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: '${FIREBASE_API_KEY_WEB}',
    appId: '${FIREBASE_APP_ID_WEB}',
    messagingSenderId: '${FIREBASE_PROJECT_NUMBER}',
    projectId: '${FIREBASE_PROJECT_ID}',
    authDomain: '${FIREBASE_AUTH_DOMAIN_WEB}',
    storageBucket: '${FIREBASE_STORAGE_BUCKET}',
    measurementId: '${FIREBASE_MEASUREMENT_ID_WEB}',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: '${FIREBASE_API_KEY_ANDROID}',
    appId: '${FIREBASE_MOBILE_SDK_APP_ID_ANDROID}',
    messagingSenderId: '${FIREBASE_PROJECT_NUMBER}',
    projectId: '${FIREBASE_PROJECT_ID}',
    storageBucket: '${FIREBASE_STORAGE_BUCKET}',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: '${FIREBASE_API_KEY_IOS}',
    appId: '${FIREBASE_GOOGLE_APP_ID_IOS}',
    messagingSenderId: '${FIREBASE_PROJECT_NUMBER}',
    projectId: '${FIREBASE_PROJECT_ID}',
    storageBucket: '${FIREBASE_STORAGE_BUCKET}',
    iosBundleId: 'it.aqila.farahmand.medicoai.ios',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: '${MACOS_API_KEY}',
    appId: '${MACOS_APP_ID}',
    messagingSenderId: '${FIREBASE_PROJECT_NUMBER}',
    projectId: '${FIREBASE_PROJECT_ID}',
    storageBucket: '${FIREBASE_STORAGE_BUCKET}',
    iosBundleId: 'it.aqila.farahmand.medicoai.macos',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: '${WINDOWS_API_KEY}',
    appId: '${WINDOWS_APP_ID}',
    messagingSenderId: '${FIREBASE_PROJECT_NUMBER}',
    projectId: '${FIREBASE_PROJECT_ID}',
    authDomain: '${WINDOWS_AUTH_DOMAIN}',
    storageBucket: '${FIREBASE_STORAGE_BUCKET}',
    measurementId: '${WINDOWS_MEASUREMENT_ID}',
  );
}
EOF

echo -e "${GREEN}✓ Firebase configuration files generated successfully!${NC}"
echo -e "${YELLOW}Note: These files are in .gitignore and should not be committed.${NC}"

