# Web App Token Management Implementation

This document confirms that the comprehensive token management strategy is fully implemented in the web app.

## Implementation Status

**Fully Implemented** - All token management features are active in the web app.

## Components Verified

### 1. Token Estimation (`lib/utils/token_estimator.dart`)

- Used in `llm_service_web.dart`
- Estimates tokens for prompts, history, and queries
- Accounts for special tokens and formatting

### 2. Configuration (`lib/config/llm_config.dart`)

- All constants used in web service
- Token limits, history management, retry configuration
- Max tokens selector uses LLMConfig constants

### 3. Proactive History Truncation

- `_truncateHistoryIfNeeded()` method implemented
-  Hard limit enforcement (max 5 turns)
-  Token budget calculation
-  Progressive degradation (5 → 3 → 1 turns)

### 4. Enhanced Retry Logic

-  Multi-attempt retry with progressive history reduction
-  Final fallback with query truncation
-  User-friendly error messages

### 5. Max Tokens Configuration

-  `setMaxTokens()` method with validation
-  `reinitialize()` method for applying changes
-   Max tokens selector widget uses LLMConfig
-  JavaScript bridge accepts and uses maxTokens

## Integration Points

### Web Service (`lib/services/llm_service_web.dart`)

```dart
// Token management is applied in generateResponse():
1. _truncateHistoryIfNeeded(prompt)  // Proactive truncation
2. TokenEstimator.estimateFormattedPromptTokens()  // Safety check
3. TokenEstimator.truncateToTokenLimit()  // Query truncation if needed
4. Enhanced retry loop with progressive degradation
```

### JavaScript Bridge (`web/mediapipe_text.js`)

```javascript
// maxTokens is passed from Dart and used in initialization:
maxTokens: maxTokens,  // Set in baseCreateOptions
```

### UI Component (`lib/widgets/max_tokens_selector.dart`)

```dart
// Uses LLMConfig constants:
- LLMConfig.maxTokensSmall (512)
- LLMConfig.maxTokensMedium (1024)
- LLMConfig.maxTokensLarge (1280)
- LLMConfig.maxTokensVeryLarge (2048)
- LLMConfig.maxTokensExtreme (4096)
```

## Flow Diagram

```
User sends message
    ↓
_truncateHistoryIfNeeded()
    ├─ Hard limit check (max 5 turns)
    ├─ Token budget calculation
    └─ Progressive truncation if needed
    ↓
Format prompt with history
    ↓
Token estimation safety check
    ├─ If > 90% of maxTokens
    └─ Truncate query if needed
    ↓
Generate response
    ├─ Success → Return response
    └─ Token error → Retry with reduced history
        ├─ Retry 1: Clear more history
        ├─ Retry 2: Clear all history
        └─ Fallback: Truncate query + no history
```

## Configuration

All settings are centralized in `lib/config/llm_config.dart`:

- **Token Limits**: 512, 1024, 1280, 2048, 4096
- **History Management**: Max 5, Preferred 3, Minimum 1
- **Reserved Tokens**: System (200), Query (300), Buffer (100)
- **Retry Strategy**: Max 2 attempts, clear history on retry

## Testing Checklist

To verify token management is working:

1.  Long conversation (5+ turns) → History truncated automatically
2.  Very long query → Query truncated if needed
3.  Token limit error → Automatic retry with reduced history
4.  Max tokens setting → Applied on reinitialization
5.  All platforms → Strategy works on web, Android, macOS

## Notes

- **Reinitialization**: When maxTokens changes, call `LLMService.reinitialize()` to apply
- **History Tracking**: `historyWasTruncated` flag available for user feedback (future feature)
- **Debug Mode**: Token estimation and truncation logged in debug mode

## Future Enhancements

- User notification when history is truncated
- Smart summarization instead of deletion
- Model-specific token counting
- Real-time token usage display
