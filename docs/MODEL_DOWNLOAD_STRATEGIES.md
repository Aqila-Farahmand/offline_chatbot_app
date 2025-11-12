# Model Download Strategies for All Platforms

This document outlines the best practices and strategies for model downloads across all platforms, with special focus on web platform challenges.

## Overview

The application supports model downloads on multiple platforms:

- **Native Platforms** (iOS, Android, macOS, Windows, Linux): Direct file system downloads
- **Web Platform**: Browser-based storage with Cache API

## Current Implementation

### Native Platforms

**Method**: Direct file system download

- Uses `dart:io` to download models directly to device storage
- Models stored in platform-specific directories
- No CORS issues
- Supports large files (limited by device storage)

**Location**:

- Android: `/data/local/tmp/llm/` or app-specific directory
- iOS: App documents directory
- Desktop: User's documents or app data directory

### Web Platform

**Method**: Cache API Storage

- Downloads models via HTTP and stores in browser Cache API
- Works offline after initial download
- Subject to CORS restrictions
- Storage limits vary by browser (typically 10-50% of disk space)

**Challenges**:

1. **CORS Issues**: Some hosting providers block direct downloads
2. **Storage Limits**: Browser cache has size limitations
3. **Network Errors**: Downloads can fail due to network issues

## Recommended Solutions

### 1. **Hybrid Approach (Current Implementation)**

#### For Web:

- **Primary**: Direct download from URLs (works when CORS allows)
- **Fallback**: Manual file upload option
- **Storage**: Cache API (can be upgraded to IndexedDB for larger limits)

#### For Native:

- Direct file system download (no changes needed)

### 2. **Manual Upload (Implemented)**

Users can upload model files they download externally:

- Click "Upload Model File" button
- Select `.gguf`, `.task`, or `.litertlm` file
- File is stored in browser cache
- Works offline after upload

**Use Cases**:

- CORS blocks direct downloads
- Authentication required (HuggingFace gated models)
- Custom model files
- Large files that fail to download in browser

### 3. **Backend Proxy (Future Enhancement)**

For production deployments, consider a backend proxy:

```dart
// Example: Proxy endpoint
static const String proxyUrl = 'https://your-backend.com/api/download-model';

// Download via proxy instead of direct URL
final response = await http.get(Uri.parse('$proxyUrl?url=${Uri.encodeComponent(modelInfo.url)}'));
```

**Benefits**:

- Avoids CORS issues
- Can add authentication
- Can cache models server-side
- Can compress/optimize models

**Implementation**:

1. Create backend endpoint that proxies model downloads
2. Update `model_downloader.dart` to use proxy when available
3. Fall back to direct download if proxy fails

### 4. **CDN with CORS (Alternative)**

Host models on a CDN that supports CORS:

- AWS S3 with CORS enabled
- Cloudflare R2
- Google Cloud Storage with CORS

**Configuration Example (S3)**:

```json
[
  {
    "AllowedHeaders": ["*"],
    "AllowedMethods": ["GET", "HEAD"],
    "AllowedOrigins": ["*"],
    "ExposeHeaders": []
  }
]
```

### 5. **Service Worker Enhancement (Future)**

Enhance service worker to handle model requests:

```javascript
// service_worker.js
self.addEventListener("fetch", (event) => {
  const url = new URL(event.request.url);

  // Intercept model download requests
  if (url.pathname.startsWith("/api/download-model")) {
    event.respondWith(
      fetch(event.request).then((response) => {
        // Cache the model
        const clone = response.clone();
        caches.open("model-cache").then((cache) => {
          cache.put(event.request, clone);
        });
        return response;
      })
    );
  }
});
```

## Best Practices

### For Web Applications

1. **Always Provide Fallback**: If direct download fails, offer manual upload
2. **Clear Error Messages**: Explain CORS issues and provide solutions
3. **Progress Indicators**: Show download progress for large files
4. **Storage Management**: Warn users about storage limits
5. **Offline Support**: Ensure downloaded models work offline

### For Native Applications

1. **Check Storage Space**: Verify sufficient space before downloading
2. **Resume Downloads**: Implement resume capability for large files
3. **Background Downloads**: Allow downloads to continue in background
4. **Error Recovery**: Handle network interruptions gracefully

## Error Handling

### Common Errors and Solutions

#### CORS Error

```
Error: Network/CORS error: Unable to download from [URL]
```

**Solutions**:

1. Use manual upload option
2. Configure backend proxy
3. Host models on CORS-enabled CDN

#### Authentication Required

```
Error: Authentication Required: This model requires a Hugging Face account
```

**Solutions**:

1. Create HuggingFace account
2. Accept model terms
3. Download manually and upload via app

#### Storage Full

```
Error: The file may be too large for browser storage
```

**Solutions**:

1. Clear browser cache
2. Use smaller model
3. Use native app instead of web

## Implementation Details

### Storage Service (`model_storage_web.dart`)

Provides unified interface for model storage:

- `storeModel()`: Store a model file
- `getModel()`: Retrieve a model file
- `hasModel()`: Check if model exists
- `deleteModel()`: Remove a model
- `listModels()`: List all stored models

### Upload Service (`model_upload_web.dart`)

Handles manual file uploads:

- Uses `file_picker` package
- Validates file types (`.gguf`, `.task`, `.litertlm`)
- Stores in Cache API
- Provides progress callbacks

### Download Service (`model_downloader.dart`)

Handles model downloads:

- Platform-specific implementations
- Progress tracking
- Error handling with helpful messages
- Fallback suggestions

## Future Enhancements

1. **IndexedDB Migration**: Move from Cache API to IndexedDB for larger storage
2. **Chunked Downloads**: Break large files into chunks
3. **Resume Downloads**: Resume interrupted downloads
4. **Background Sync**: Download models in background
5. **Model Compression**: Compress models before storage
6. **CDN Integration**: Direct CDN integration with CORS
7. **Progressive Download**: Stream models as they download

## Testing

### Web Platform Testing

1. Test direct downloads from HuggingFace
2. Test CORS error handling
3. Test manual upload functionality
4. Test offline model access
5. Test storage limits

### Native Platform Testing

1. Test file system downloads
2. Test storage space handling
3. Test network interruption recovery
4. Test background downloads

## Troubleshooting

### Web Downloads Fail

1. Check browser console for CORS errors
2. Try manual upload instead
3. Check network connectivity
4. Verify model URL is accessible
5. Check browser storage limits

### Models Not Appearing

1. Refresh model list
2. Check storage permissions
3. Verify file format is supported
4. Check browser console for errors

### Storage Issues

1. Clear browser cache
2. Check available storage space
3. Delete unused models
4. Use smaller model files

## Conclusion

The current implementation provides a robust solution for model downloads across all platforms. The manual upload option ensures web users can always add models, even when direct downloads fail. Future enhancements can further improve the user experience with better storage options and download reliability.
