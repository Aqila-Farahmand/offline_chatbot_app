#!/bin/bash

# Script to set up Firebase configuration files from environment variables or secure sources
# This script generates the native Firebase config files needed for Android/iOS builds

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Setting up Firebase configuration files...${NC}"

# Check if required environment variables are set
if [ -z "$FIREBASE_PROJECT_ID" ] || [ -z "$FIREBASE_API_KEY_ANDROID" ] || [ -z "$FIREBASE_API_KEY_IOS" ]; then
    echo -e "${YELLOW}Warning: Environment variables not set.${NC}"
    echo "Required variables:"
    echo "  - FIREBASE_PROJECT_ID"
    echo "  - FIREBASE_PROJECT_NUMBER"
    echo "  - FIREBASE_STORAGE_BUCKET"
    echo "  - FIREBASE_API_KEY_ANDROID"
    echo "  - FIREBASE_MOBILE_SDK_APP_ID_ANDROID"
    echo "  - FIREBASE_API_KEY_IOS"
    echo "  - FIREBASE_GOOGLE_APP_ID_IOS"
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

echo -e "${GREEN}✓ Firebase configuration files generated successfully!${NC}"
echo -e "${YELLOW}Note: These files are in .gitignore and should not be committed.${NC}"

