#!/bin/bash

# Script to set up Firebase configuration files from environment variables or secure sources
# This script generates:
# 1. Native Firebase config files (google-services.json, GoogleService-Info.plist)
# 2. Dart config files (web_config.dart, android_config.dart, ios_config.dart, macos_config.dart, windows_config.dart)

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

# Generate Dart config files
echo -e "${GREEN}Generating Dart config files...${NC}"

# Set defaults for optional variables
MACOS_API_KEY=${FIREBASE_API_KEY_MACOS:-$FIREBASE_API_KEY_IOS}
MACOS_APP_ID=${FIREBASE_GOOGLE_APP_ID_MACOS:-$FIREBASE_GOOGLE_APP_ID_IOS}
WINDOWS_API_KEY=${FIREBASE_API_KEY_WINDOWS:-$FIREBASE_API_KEY_WEB}
WINDOWS_APP_ID=${FIREBASE_APP_ID_WINDOWS:-$FIREBASE_APP_ID_WEB}
WINDOWS_AUTH_DOMAIN=${FIREBASE_AUTH_DOMAIN_WINDOWS:-$FIREBASE_AUTH_DOMAIN_WEB}
WINDOWS_MEASUREMENT_ID=${FIREBASE_MEASUREMENT_ID_WINDOWS:-$FIREBASE_MEASUREMENT_ID_WEB}

# Generate web_config.dart
echo -e "${GREEN}Generating lib/config/firebase/web_config.dart...${NC}"
cat > lib/config/firebase/web_config.dart << EOF
class WebConfig {
  static const String apiKey = '${FIREBASE_API_KEY_WEB}';
  static const String appId = '${FIREBASE_APP_ID_WEB}';
  static const String messagingSenderId = '${FIREBASE_PROJECT_NUMBER}';
  static const String projectId = '${FIREBASE_PROJECT_ID}';
  static const String authDomain = '${FIREBASE_AUTH_DOMAIN_WEB}';
  static const String storageBucket = '${FIREBASE_STORAGE_BUCKET}';
  static const String measurementId = '${FIREBASE_MEASUREMENT_ID_WEB}';
}
EOF

# Generate android_config.dart
echo -e "${GREEN}Generating lib/config/firebase/android_config.dart...${NC}"
cat > lib/config/firebase/android_config.dart << EOF
class AndroidConfig {
  static const String apiKey = '${FIREBASE_API_KEY_ANDROID}';
  static const String appId = '${FIREBASE_MOBILE_SDK_APP_ID_ANDROID}';
  static const String messagingSenderId = '${FIREBASE_PROJECT_NUMBER}';
  static const String projectId = '${FIREBASE_PROJECT_ID}';
  static const String storageBucket = '${FIREBASE_STORAGE_BUCKET}';
}
EOF

# Generate ios_config.dart
echo -e "${GREEN}Generating lib/config/firebase/ios_config.dart...${NC}"
cat > lib/config/firebase/ios_config.dart << EOF
class IosConfig {
  static const String apiKey = '${FIREBASE_API_KEY_IOS}';
  static const String appId = '${FIREBASE_GOOGLE_APP_ID_IOS}';
  static const String messagingSenderId = '${FIREBASE_PROJECT_NUMBER}';
  static const String projectId = '${FIREBASE_PROJECT_ID}';
  static const String storageBucket = '${FIREBASE_STORAGE_BUCKET}';
  static const String iosBundleId = 'it.aqila.farahmand.medicoai.ios';
}
EOF

# Generate macos_config.dart
echo -e "${GREEN}Generating lib/config/firebase/macos_config.dart...${NC}"
cat > lib/config/firebase/macos_config.dart << EOF
class MacosConfig {
  static const String apiKey = '${MACOS_API_KEY}';
  static const String appId = '${MACOS_APP_ID}';
  static const String messagingSenderId = '${FIREBASE_PROJECT_NUMBER}';
  static const String projectId = '${FIREBASE_PROJECT_ID}';
  static const String storageBucket = '${FIREBASE_STORAGE_BUCKET}';
  static const String iosBundleId = 'it.aqila.farahmand.medicoai.macos';
}
EOF

# Generate windows_config.dart
echo -e "${GREEN}Generating lib/config/firebase/windows_config.dart...${NC}"
cat > lib/config/firebase/windows_config.dart << EOF
class WindowsConfig {
  static const String apiKey = '${WINDOWS_API_KEY}';
  static const String appId = '${WINDOWS_APP_ID}';
  static const String messagingSenderId = '${FIREBASE_PROJECT_NUMBER}';
  static const String projectId = '${FIREBASE_PROJECT_ID}';
  static const String authDomain = '${WINDOWS_AUTH_DOMAIN}';
  static const String storageBucket = '${FIREBASE_STORAGE_BUCKET}';
  static const String measurementId = '${WINDOWS_MEASUREMENT_ID}';
}
EOF

echo -e "${GREEN}✓ Firebase configuration files generated successfully!${NC}"
echo -e "${YELLOW}Note: These files are in .gitignore and should not be committed.${NC}"

