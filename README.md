# cordova-plugin-firebasex

Backward-compatible wrapper meta-plugin that installs all `cordova-plugin-firebasex` modular plugins and re-exports their APIs under the unified `FirebasePlugin` global.

## Installation

```bash
cordova plugin add cordova-plugin-firebasex
```

This installs all modular plugins:
- `cordova-plugin-firebasex-core` - Firebase initialization, config file handling
- `cordova-plugin-firebasex-analytics` - Google Analytics
- `cordova-plugin-firebasex-messaging` - Cloud Messaging (FCM)
- `cordova-plugin-firebasex-auth` - Authentication
- `cordova-plugin-firebasex-crashlytics` - Crashlytics
- `cordova-plugin-firebasex-firestore` - Cloud Firestore
- `cordova-plugin-firebasex-functions` - Cloud Functions
- `cordova-plugin-firebasex-config` - Remote Config
- `cordova-plugin-firebasex-performance` - Performance Monitoring
- `cordova-plugin-firebasex-inappmessaging` - In-App Messaging

## Migration to Modular Plugins

Instead of installing this wrapper, you can install only the plugins you need:

```bash
# Install only what you need
cordova plugin add cordova-plugin-firebasex-messaging
cordova plugin add cordova-plugin-firebasex-analytics
```

Each modular plugin exposes its own JavaScript global (e.g., `FirebasexMessagingPlugin`, `FirebasexAnalyticsPlugin`).

## API

When using this wrapper, all methods are available on the `FirebasePlugin` global, maintaining full backward compatibility with the monolithic plugin.

```javascript
// Same API as before
FirebasePlugin.getToken(function(token) {
    console.log("FCM token: " + token);
});
```
