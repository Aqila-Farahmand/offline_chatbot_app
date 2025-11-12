# Chat History Remote Logger - Implementation & Offline Behavior

## How It Works

### Current Implementation

The `ChatHistoryRemoteLogger` is designed to **never block offline functionality**. Here's how:

1. **Fire-and-Forget Pattern**

   ```dart
   // In app_state.dart
   ChatHistoryRemoteLogger.logModelEvalRemote(...)
     .catchError((e) => print('Remote logging error: $e'));
   ```

   - Called with `.catchError()` - errors never propagate
   - Doesn't await the result
   - UI continues immediately

2. **Timeout Protection**

   - 5-second timeout prevents indefinite waiting
   - When timeout occurs, Firestore queues the write locally
   - Syncs automatically when connection is restored

3. **Error Handling**

   - All exceptions are caught and logged
   - Never throws to calling code
   - App continues working normally

4. **Firestore Offline Persistence**
   - Firestore SDK automatically enables offline persistence
   - Writes are queued locally when offline
   - Automatically synced when online
   - No user action required

## Why It Shouldn't Block Offline Mode

### Design Principles

1. **Non-Blocking**: Uses `.catchError()` - never blocks the UI thread
2. **Quick Timeout**: 5 seconds max wait, then continues
3. **Silent Failures**: All errors are caught, never thrown
4. **Offline Queue**: Firestore handles queuing automatically

### Flow Diagram

```
User sends message
    ↓
LLM generates response (local, offline-capable)
    ↓
Response shown to user immediately
    ↓
[Parallel, non-blocking]
    ├─ Local CSV logging (offline-capable)
    └─ Remote Firestore logging (fire-and-forget)
        ├─ Online: Write succeeds immediately
        ├─ Offline: Write queued locally (5s timeout)
        └─ When online: Queued writes sync automatically
```

## If You're Experiencing Blocking

### Potential Causes

1. **Firebase Initialization**: Check if `Firebase.initializeApp()` is blocking
   - Solution: Already has timeout protection
2. **Network Detection**: Firestore might be trying to connect
   - Solution: Firestore handles this gracefully with offline persistence
3. **Long Timeout**: 5 seconds might feel like blocking
   - Solution: Can reduce timeout, but Firestore queues writes anyway

### Verification

To verify it's not blocking:

1. Turn off network
2. Send a chat message
3. Response should appear immediately
4. Check console for timeout message (expected)

## Admin Access to Chat History

### Method 1: Admin Logs Screen (In-App)

**Access**: Admin button in app bar → `/admin/logs`

**Features**:

- Real-time view of all chat logs
- Last 1000 entries
- Download as CSV
- View by user, model, date, platform

**Query Used**:

```dart
FirebaseFirestore.instance
  .collection('chat_logs')
  .orderBy('timestamp_iso', descending: true)
  .limit(1000)
```

### Method 2: Firebase Console

1. Go to https://console.firebase.google.com
2. Select your project
3. Navigate to **Firestore Database**
4. Open `chat_logs` collection
5. View, filter, and export data

**Filtering Options**:

- By user: `uid` field
- By date: `timestamp_iso` field
- By model: `model_name` field
- By platform: `platform` field

### Method 3: Firestore REST API

```bash
GET https://firestore.googleapis.com/v1/projects/{project-id}/databases/(default)/documents/chat_logs
```

### Method 4: Firebase CLI

```bash
# Export all logs
firebase firestore:export gs://your-bucket/chat-logs

# Query specific logs
firebase firestore:query chat_logs --limit 100
```

## Data Structure

Each document in `chat_logs`:

```json
{
  "timestamp_iso": "2025-01-15T10:30:00.000Z",
  "uid": "user123",
  "model_name": "gemma-2b",
  "prompt_label": "medical_safety",
  "question": "What are flu symptoms?",
  "response": "Common symptoms include...",
  "response_time_ms": 1250,
  "platform": "web"
}
```

## Security

- **Users**: Can only create their own logs
- **Users**: Can only read their own logs
- **Admins**: Can read ALL logs (via Firestore rules)

## Offline Behavior

When users are offline:

1. Chat works normally (local LLM)
2. Remote logging times out after 5 seconds
3. Firestore queues the write locally
4. When connection restored, writes sync automatically
5. No data loss
6. Timestamps reflect creation time, not sync time

## Best Practices

1. **Monitor Logs**: Regularly check admin logs screen
2. **Export Data**: Download CSV periodically for backup
3. **Privacy**: Ensure compliance with data regulations
4. **Retention**: Consider implementing data retention policies
5. **Indexes**: Ensure Firestore indexes are created (see `firestore.indexes.json`)
