# Privacy-First Data Collection

## Overview

MedicoAI is a prototype app that prioritizes **user privacy**. Chat history remote logging is **opt-in only** and designed for research purposes.

## Privacy Principles

1. **Opt-In by Default**: Remote logging is **disabled by default**
2. **Explicit Consent**: Users must explicitly consent before any data collection
3. **User Control**: Users can opt-out at any time
4. **Transparency**: Clear information about what data is collected and why
5. **Data Deletion**: Users can request deletion of their data

## How It Works

### Default Behavior

- **Remote logging is OFF by default**
- Chat history is **never** sent to Firestore without explicit user consent
- All chat functionality works normally regardless of consent status
- Privacy is the default, not an afterthought

### User Consent Flow

1. **User opens Settings** → Privacy & Data Collection section
2. **User sees privacy notice** explaining research data collection
3. **User toggles "Share Chat History for Research"**
4. **Consent dialog appears** with clear information:
   - What data is collected
   - Why it's collected (research purposes)
   - How it's used (anonymized, prototype improvement)
   - User rights (opt-out anytime)
5. **User clicks "I Consent"** → Remote logging enabled
6. **User can disable anytime** → Remote logging stops immediately

### Technical Implementation

```dart
// In chat_history_remote_logger.dart
static Future<void> logModelEvalRemote(...) async {
  // PRIVACY CHECK: Only log if user has given explicit consent
  final hasConsent = await PrivacyService.isRemoteLoggingEnabled();
  if (!hasConsent) {
    // Silently skip logging - this is expected behavior
    return;
  }
  // ... proceed with logging
}
```

## Privacy Settings UI

### Location
**Settings Screen** → **Privacy & Data Collection** section

### Features

1. **Privacy Notice**
   - Clear explanation of research data collection
   - Purpose: prototype improvement
   - User control emphasized

2. **Consent Toggle**
   - Switch to enable/disable remote logging
   - Shows current status
   - Requires explicit consent dialog before enabling

3. **Data Deletion Request**
   - Button to request data deletion
   - Disables logging immediately
   - Instructions to contact admin for deletion

## Data Collection Details

### What Data is Collected (if consented)

- `timestamp_iso`: When the chat occurred
- `uid`: User ID (for research correlation)
- `model_name`: Model used
- `prompt_label`: Prompt variant
- `question`: User's question
- `response`: Model's response
- `response_time_ms`: Response time
- `platform`: Platform (web, android, ios, etc.)

### Purpose

- **Research**: Improve prototype performance
- **Study**: Understand model behavior
- **Development**: Enhance user experience

### Data Handling

- **Anonymized**: User IDs are used for correlation only
- **Secure**: Stored in Firestore with proper security rules
- **Limited**: Only chat history, no personal information
- **Controlled**: Users can opt-out and request deletion

## User Rights

1. **Right to Consent**: Users choose whether to participate
2. **Right to Withdraw**: Users can opt-out anytime
3. **Right to Deletion**: Users can request data deletion
4. **Right to Information**: Clear explanation of data collection
5. **Right to Privacy**: Default is no data collection

## Compliance

This implementation follows privacy best practices:

-  **Opt-in by default** (not opt-out)
-  **Explicit consent** required
-  **Clear information** about data collection
-  **User control** over their data
-  **Data deletion** capability
-  **Transparency** about purpose

## Admin Access

Admins can access collected data through:

1. **Admin Logs Screen** (`/admin/logs`)
2. **Firebase Console** (Firestore Database)
3. **Firestore REST API**

**Note**: Admins should respect user privacy and only use data for stated research purposes.

## Implementation Files

- `lib/services/privacy_service.dart`: Privacy preferences management
- `lib/utils/chat_history_remote_logger.dart`: Privacy-checked logging
- `lib/screens/settings_screen.dart`: Privacy settings UI

## Future Enhancements

1. **Automatic data expiration**: Delete data after research period
2. **Anonymization**: Further anonymize user IDs
3. **Consent history**: Track when consent was given/withdrawn
4. **Data export**: Allow users to export their own data
5. **Privacy policy link**: Link to full privacy policy

