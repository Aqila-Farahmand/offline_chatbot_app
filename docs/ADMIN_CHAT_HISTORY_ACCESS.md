# Admin Access to Chat History in Cloud Firestore

## Overview

Admins can access all user chat history stored in Cloud Firestore through multiple methods.

## Data Location

**Collection**: `chat_logs`  
**Database**: Default Firestore database

## Access Methods

### 1. Admin Logs Screen (In-App)

**Location**: `/admin/logs` route  
**Access**: Admin button in app bar (only visible to admins)

**Features**:

- View all chat logs in real-time
- See last 1000 entries (configurable)
- Download as CSV
- Filter by scrolling/searching
- View metadata: timestamp, user ID, model, response time, platform

**Query**:

```dart
FirebaseFirestore.instance
  .collection('chat_logs')
  .orderBy('timestamp_iso', descending: true)
  .limit(1000)
```

### 2. Firebase Console (Web)

**URL**: https://console.firebase.google.com  
**Path**: Your Project → Firestore Database → `chat_logs` collection

**Features**:

- View all documents
- Filter by any field
- Export data
- Query builder
- Real-time updates

**Filtering Examples**:

- By user: Filter `uid` field
- By date: Filter `timestamp_iso` field
- By model: Filter `model_name` field
- By platform: Filter `platform` field

### 3. Firestore REST API

**Endpoint**: `https://firestore.googleapis.com/v1/projects/{project-id}/databases/(default)/documents/chat_logs`

**Authentication**: Use Firebase Admin SDK or service account

### 4. Firebase CLI

```bash
# Export all chat logs
firebase firestore:export gs://your-bucket/chat-logs-export

# Query specific logs
firebase firestore:query chat_logs --limit 100
```

## Data Structure

Each document in `chat_logs` contains:

```json
{
  "timestamp_iso": "2025-01-15T10:30:00.000Z",
  "uid": "user123",
  "model_name": "gemma-2b",
  "prompt_label": "medical_safety",
  "question": "What are the symptoms of flu?",
  "response": "Common flu symptoms include...",
  "response_time_ms": 1250,
  "platform": "web"
}
```

## Security Rules

Current rules allow:

- **Users**: Can create their own logs (write)
- **Users**: Can read their own logs
- **Admins**: Can read ALL logs (via `isAdmin()` function)

See `firestore.rules` for details.

## Querying Examples

### Get logs for specific user

```dart
FirebaseFirestore.instance
  .collection('chat_logs')
  .where('uid', isEqualTo: 'user123')
  .orderBy('timestamp_iso', descending: true)
  .get();
```

### Get logs from date range

```dart
FirebaseFirestore.instance
  .collection('chat_logs')
  .where('timestamp_iso', isGreaterThan: '2025-01-01')
  .where('timestamp_iso', isLessThan: '2025-01-31')
  .get();
```

### Get logs by model

```dart
FirebaseFirestore.instance
  .collection('chat_logs')
  .where('model_name', isEqualTo: 'gemma-2b')
  .get();
```

## Offline Behavior

When users are offline:

- Logs are queued locally by Firestore
- Automatically synced when connection is restored
- No data loss
- Timestamps reflect when the log was created (not when synced)

## Best Practices

1. **Regular Exports**: Export data periodically for backup
2. **Data Retention**: Consider implementing retention policies
3. **Privacy**: Ensure compliance with data protection regulations
4. **Monitoring**: Set up alerts for unusual activity
5. **Indexes**: Create composite indexes for complex queries

## Indexes Required

For the admin logs screen query, ensure this index exists:

- Collection: `chat_logs`
- Fields: `timestamp_iso` (Descending)

This is defined in `firestore.indexes.json`.
