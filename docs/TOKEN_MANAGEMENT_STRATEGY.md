# Token Management Strategy

This document explains the comprehensive token limit management strategy implemented in the application.

## Overview

The application uses a **proactive, multi-layered approach** to handle token limits gracefully, ensuring the LLM never refuses to respond due to token constraints.

## Strategy Components

### 1. Token Estimation (`lib/utils/token_estimator.dart`)

- **Approximate token counting** using character-based estimation (~4 chars/token)
- Accounts for special tokens (turn markers, formatting)
- Estimates tokens for:
  - Individual text strings
  - Chat history entries
  - Complete formatted prompts

### 2. Proactive History Management

**Before generating a response:**

- Estimates total token count for the prompt
- Calculates available token budget for history
- Truncates history **proactively** if it exceeds budget
- Uses **progressive degradation**: reduces history gradually (5 → 3 → 1 turns)

### 3. Multi-Layer Protection

#### Layer 1: Hard Limit Enforcement

- Never exceeds `maxHistoryTurns` (5 turns)
- Immediate truncation if history grows too large

#### Layer 2: Token Budget Management

- Reserves tokens for:
  - System prompt (~200 tokens)
  - User query (~300 tokens)
  - Safety buffer (~100 tokens)
- Calculates available budget for history
- Truncates history to fit within budget

#### Layer 3: Progressive Truncation

- Tries to keep preferred number of turns (3)
- Reduces to minimum (1 turn) if needed
- Preserves most recent conversation context

#### Layer 4: Query Truncation (Last Resort)

- If prompt still too long after history truncation
- Truncates the user's query itself
- Ensures response can always be generated

### 4. Enhanced Retry Logic

When token limit errors occur:

1. **First Retry**: Clear more history, keep minimum turns
2. **Second Retry**: Clear all history, use only current query
3. **Final Fallback**: Truncate query and retry with no history
4. **User-Friendly Error**: Clear message if all retries fail

### 5. Configuration (`lib/config/llm_config.dart`)

Centralized configuration for:

- Token limits (512, 1024, 1280, 2048, 4096)
- History management (max 5, preferred 3, minimum 1)
- Reserved token budgets
- Retry strategies

## Benefits

### Never Refuses to Respond

- Multiple fallback strategies ensure a response is always generated
- Even with very long queries, the system adapts

### Preserves Context When Possible

- Keeps recent conversation history when token budget allows
- Progressive degradation maintains as much context as feasible

###  Transparent to User

- History truncation happens automatically
- User doesn't need to manually clear conversation
- System handles edge cases gracefully

### Production-Ready

- Handles all edge cases
- Works across all platforms (web, Android, macOS)
- Configurable and maintainable

## Example Scenarios

### Scenario 1: Normal Conversation

- User asks questions, system responds
- History grows to 3-5 turns
- Token budget sufficient, no truncation needed

### Scenario 2: Long Conversation

- History reaches 5+ turns
- System proactively trims to 3 turns
- Recent context preserved

### Scenario 3: Very Long Query

- User asks extremely long question
- History truncated to minimum (1 turn)
- Query itself may be truncated if needed
- Response still generated successfully

### Scenario 4: Token Limit Error

- Model reports token limit error
- System automatically retries with reduced history
- Multiple fallback strategies ensure success

## Configuration

All settings are in `lib/config/llm_config.dart`:

```dart
// Adjust these based on your model's capabilities
maxHistoryTurns = 5        // Maximum history to keep
preferredHistoryTurns = 3  // Preferred history size
minHistoryTurns = 1        // Minimum to preserve

// Token budgets
reservedTokensForSystem = 200
reservedTokensForQuery = 300
tokenEstimationBuffer = 100
```

## Best Practices

1. **Monitor token usage** in debug mode to understand behavior
2. **Adjust limits** based on your model's context window
3. **Test with long conversations** to verify truncation works
4. **Consider model-specific limits** when setting max tokens

## Future Enhancements

Potential improvements:

- **Smart summarization**: Summarize old history instead of deleting
- **Token counting per model**: More accurate estimation per tokenizer
- **User notification**: Inform user when history is truncated
- **Configurable strategies**: Allow users to choose truncation approach
