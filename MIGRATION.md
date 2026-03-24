# Migration Guide: cordova-plugin-firebasex → Modular Plugins

This guide covers migrating from the original monolithic `cordova-plugin-firebasex` plugin to the new modular plugin architecture.

## Table of Contents

- [Introduction](#introduction)
- [Modular Plugin Overview](#modular-plugin-overview)
- [Migration Paths](#migration-paths)
  - [Path A: Drop-in Wrapper (Minimal Changes)](#path-a-drop-in-wrapper-minimal-changes)
  - [Path B: Individual Modular Plugins (Recommended)](#path-b-individual-modular-plugins-recommended)
- [Updating Your Code](#updating-your-code)
  - [API Globals Reference](#api-globals-reference)
  - [Code Examples](#code-examples)
- [Plugin Variables](#plugin-variables)
  - [Variables by Plugin](#variables-by-plugin)
  - [Variable Resolution Order](#variable-resolution-order)
  - [Preserving Custom Variable Values](#preserving-custom-variable-values)
- [Breaking Changes](#breaking-changes)
- [Plugin Documentation](#plugin-documentation)

---

## Introduction

The original `cordova-plugin-firebasex` bundled all Firebase services — Analytics, Messaging, Auth, Crashlytics, Firestore, Functions, Remote Config, Performance, and In-App Messaging — into a single monolithic plugin. Every app that used the plugin included the native SDKs for **all** services, regardless of which ones were actually used.

The new modular architecture splits the plugin into focused packages:

- **Smaller app size** — Only the native Firebase SDKs you actually use are included in your binary. Apps that only need Messaging and Analytics can avoid bundling Firestore, Auth, and other unused SDKs.
- **Faster builds** — Fewer native dependencies means shorter compilation and linking times, particularly on iOS where CocoaPods resolution is a bottleneck.
- **Flexible dependency management** — Each plugin can be versioned and updated independently. You can upgrade Crashlytics without risking changes to Messaging, for example.
- **Clearer project structure** — Each plugin has a focused scope, making it easier to understand configuration and troubleshoot issues.

---

## Modular Plugin Overview

| Plugin | Description |
|--------|-------------|
| `cordova-plugin-firebasex-core` | Firebase initialization, installations, shared utilities. **Required by all other plugins.** |
| `cordova-plugin-firebasex-analytics` | Event logging, user properties, screen tracking, consent management. |
| `cordova-plugin-firebasex-messaging` | Push notifications (FCM), token management, notification channels, badge counts. |
| `cordova-plugin-firebasex-auth` | Email/password, phone, Google Sign-In, Apple Sign-In, anonymous auth, custom tokens, MFA. |
| `cordova-plugin-firebasex-crashlytics` | Crash reporting, non-fatal exceptions, custom keys/logs. |
| `cordova-plugin-firebasex-firestore` | Document CRUD, collection queries, real-time listeners, batch operations. |
| `cordova-plugin-firebasex-functions` | HTTPS callable Cloud Functions. |
| `cordova-plugin-firebasex-config` | Remote Config — fetch, activate, and read remote values. |
| `cordova-plugin-firebasex-performance` | Performance Monitoring — custom traces, HTTP metrics. |
| `cordova-plugin-firebasex-inappmessaging` | In-App Messaging (native SDK only, no JS API). |

---

## Migration Paths

### Path A: Drop-in Wrapper (Minimal Changes)

If you want to migrate with **zero code changes**, use the wrapper plugin. It installs all 10 modular plugins behind the scenes and re-exports their APIs under the original `FirebasePlugin` global.

#### Step 1: Remove the old plugin

```bash
cordova plugin remove cordova-plugin-firebasex --nosave
```

Note: The `--nosave` flag prevents changes to `config.xml` and `package.json`, preserving your existing plugin variable entries.

#### Step 2: Install the wrapper

```bash
cordova plugin add cordova-plugin-firebasex@20.0.0
```

> **Note:** Version 20.0.0+ of `cordova-plugin-firebasex` is the modular wrapper. It declares dependencies on all 10 sub-plugins and re-exports their APIs.

If you were passing plugin variables at install time, the wrapper accepts all the same variables and forwards them to the appropriate sub-plugins:

```bash
cordova plugin add cordova-plugin-firebasex@20.0.0 \
  --variable FIREBASE_ANALYTICS_WITHOUT_ADS=true \
  --variable IOS_ENABLE_APPLE_SIGNIN=true
```

#### Step 3: Build and test

Your existing code using `FirebasePlugin.*` will continue to work with no changes.

---

### Path B: Individual Modular Plugins (Recommended)

For the full benefits of the modular architecture, install only the plugins you need.

#### Step 1: Remove the old plugin

```bash
cordova plugin remove cordova-plugin-firebasex
```

#### Step 2: Identify which services you use

Review your code for the Firebase features you actually call. Common patterns:

| If you call... | You need... |
|----------------|-------------|
| `getToken()`, `onMessageReceived()`, `subscribe()` | `cordova-plugin-firebasex-messaging` |
| `logEvent()`, `setScreenName()`, `setUserProperty()` | `cordova-plugin-firebasex-analytics` |
| `signInWithEmailAndPassword()`, `getCurrentUser()` | `cordova-plugin-firebasex-auth` |
| `logError()`, `setCrashlyticsCustomKey()` | `cordova-plugin-firebasex-crashlytics` |
| `fetchDocumentInFirestoreCollection()` | `cordova-plugin-firebasex-firestore` |
| `callFunction()` | `cordova-plugin-firebasex-functions` |
| `fetch()`, `activateFetched()`, `getValue()` | `cordova-plugin-firebasex-config` |
| `startTrace()`, `stopTrace()` | `cordova-plugin-firebasex-performance` |

#### Step 3: Install your chosen plugins

The `core` plugin is automatically installed as a dependency — you don't need to install it explicitly.

```bash
# Example: only Messaging and Analytics
cordova plugin add cordova-plugin-firebasex-messaging \
  --variable IOS_FCM_ENABLED=true

cordova plugin add cordova-plugin-firebasex-analytics \
  --variable FIREBASE_ANALYTICS_WITHOUT_ADS=true
```

#### Step 4: Update your code

Replace references from the old `FirebasePlugin` global to the new modular globals. See [Updating Your Code](#updating-your-code) below.

#### Step 5: Build and test

```bash
cordova build android
cordova build ios
```

---

## Updating Your Code

### API Globals Reference

When using individual modular plugins (Path B), each plugin exposes its own JavaScript global:

| Old Global | New Global | Plugin |
|------------|-----------|--------|
| `FirebasePlugin` | `FirebasexCore` | `cordova-plugin-firebasex-core` |
| `FirebasePlugin` | `FirebasexAnalytics` | `cordova-plugin-firebasex-analytics` |
| `FirebasePlugin` | `FirebasexMessaging` | `cordova-plugin-firebasex-messaging` |
| `FirebasePlugin` | `FirebasexAuth` | `cordova-plugin-firebasex-auth` |
| `FirebasePlugin` | `FirebasexCrashlytics` | `cordova-plugin-firebasex-crashlytics` |
| `FirebasePlugin` | `FirebasexFirestore` | `cordova-plugin-firebasex-firestore` |
| `FirebasePlugin` | `FirebasexFunctions` | `cordova-plugin-firebasex-functions` |
| `FirebasePlugin` | `FirebasexConfig` | `cordova-plugin-firebasex-config` |
| `FirebasePlugin` | `FirebasexPerformance` | `cordova-plugin-firebasex-performance` |

> **Note:** The `cordova-plugin-firebasex-inappmessaging` plugin has no JS API — it only includes the native SDK.

### Code Examples

**Before (monolithic):**

```javascript
// All calls go through a single global
FirebasePlugin.getToken(function(token) {
    console.log("FCM token: " + token);
}, function(error) {
    console.error(error);
});

FirebasePlugin.logEvent("select_content", { content_type: "page", item_id: "home" });

FirebasePlugin.signInWithEmailAndPassword("user@example.com", "password123",
    function(user) { console.log("Signed in: " + JSON.stringify(user)); },
    function(error) { console.error(error); }
);

FirebasePlugin.logError("Something went wrong", function() {
    console.log("Error logged to Crashlytics");
});
```

**After (modular):**

```javascript
// Each service has its own global
FirebasexMessaging.getToken(function(token) {
    console.log("FCM token: " + token);
}, function(error) {
    console.error(error);
});

FirebasexAnalytics.logEvent("select_content", { content_type: "page", item_id: "home" });

FirebasexAuth.signInWithEmailAndPassword("user@example.com", "password123",
    function(user) { console.log("Signed in: " + JSON.stringify(user)); },
    function(error) { console.error(error); }
);

FirebasexCrashlytics.logError("Something went wrong", function() {
    console.log("Error logged to Crashlytics");
});
```

> **Tip:** If you use the wrapper plugin (Path A), you don't need to change any code — `FirebasePlugin.*` continues to work.

---

## Plugin Variables

### Variables by Plugin

Each modular plugin defines its own set of configurable variables. Below is the complete reference.

#### Core (`cordova-plugin-firebasex-core`)

| Variable | Default | Description |
|----------|---------|-------------|
| `ANDROID_FIREBASE_CORE_VERSION` | `21.1.1` | Android Firebase BoM / core SDK version. |
| `ANDROID_FIREBASE_INSTALLATIONS_VERSION` | `18.0.0` | Android Firebase Installations SDK version. |
| `ANDROID_GSON_VERSION` | `2.13.2` | Google Gson library version for Android. |
| `IOS_FIREBASE_SDK_VERSION` | `12.9.0` | iOS Firebase SDK version (CocoaPods). |

#### Analytics (`cordova-plugin-firebasex-analytics`)

| Variable | Default | Description |
|----------|---------|-------------|
| `ANDROID_FIREBASE_ANALYTICS_VERSION` | `23.0.0` | Android Firebase Analytics SDK version. |
| `ANDROID_PLAY_SERVICES_TAGMANAGER_VERSION` | `18.3.0` | Android Play Services Tag Manager version. |
| `IOS_FIREBASE_SDK_VERSION` | `12.9.0` | iOS Firebase SDK version (for analytics pods). |
| `IOS_GOOGLE_TAG_MANAGER_VERSION` | `9.0.0` | iOS Google Tag Manager pod version. |
| `FIREBASE_ANALYTICS_COLLECTION_ENABLED` | `true` | Enable/disable analytics collection at startup. |
| `FIREBASE_ANALYTICS_WITHOUT_ADS` | `false` | Use `FirebaseAnalyticsWithoutAdIdSupport` pod (no IDFA). |
| `GOOGLE_ANALYTICS_ADID_COLLECTION_ENABLED` | `true` | Enable advertising ID collection. |
| `GOOGLE_ANALYTICS_DEFAULT_ALLOW_ANALYTICS_STORAGE` | `true` | Default consent for analytics storage. |
| `GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_STORAGE` | `true` | Default consent for ad storage. |
| `GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_USER_DATA` | `true` | Default consent for ad user data. |
| `GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS` | `true` | Default consent for ad personalization. |
| `IOS_ON_DEVICE_CONVERSION_ANALYTICS` | `false` | Enable on-device conversion analytics (iOS). |

#### Messaging (`cordova-plugin-firebasex-messaging`)

| Variable | Default | Description |
|----------|---------|-------------|
| `ANDROID_FIREBASE_MESSAGING_VERSION` | `25.0.1` | Android Firebase Messaging SDK version. |
| `ANDROID_ICON_ACCENT` | `#FFFFFF` | Default accent color for Android notification icons. |
| `FIREBASE_FCM_AUTOINIT_ENABLED` | `true` | Auto-initialize FCM on app launch. |
| `FIREBASE_MESSAGING_IMMEDIATE_PAYLOAD_DELIVERY` | `false` | Deliver notification payloads immediately (iOS). |
| `IOS_FCM_ENABLED` | `true` | Enable FCM on iOS. |
| `IOS_ENABLE_CRITICAL_ALERTS_ENABLED` | `false` | Enable critical alerts capability (iOS). |
| `IOS_FIREBASE_SDK_VERSION` | `12.9.0` | iOS Firebase SDK version (for messaging pod). |

#### Auth (`cordova-plugin-firebasex-auth`)

| Variable | Default | Description |
|----------|---------|-------------|
| `ANDROID_FIREBASE_AUTH_VERSION` | `24.0.1` | Android Firebase Auth SDK version. |
| `ANDROID_PLAY_SERVICES_AUTH_VERSION` | `21.5.1` | Android Play Services Auth version. |
| `ANDROID_CREDENTIALS_VERSION` | `1.5.0` | AndroidX Credentials library version. |
| `ANDROID_GOOGLEID_VERSION` | `1.2.0` | Google Identity library version. |
| `IOS_FIREBASE_SDK_VERSION` | `12.9.0` | iOS Firebase SDK version (for auth pod). |
| `SETUP_RECAPTCHA_VERIFICATION` | `false` | Add reversed client ID URL scheme for reCAPTCHA. |
| `IOS_ENABLE_APPLE_SIGNIN` | `false` | Add Apple Sign-In entitlement (iOS). |
| `IOS_GOOGLE_SIGIN_VERSION` | `9.0.0` | GoogleSignIn pod version (iOS). |

#### Crashlytics (`cordova-plugin-firebasex-crashlytics`)

| Variable | Default | Description |
|----------|---------|-------------|
| `ANDROID_FIREBASE_CRASHLYTICS_VERSION` | `20.0.4` | Android Firebase Crashlytics SDK version. |
| `ANDROID_FIREBASE_CRASHLYTICS_NDK_VERSION` | `20.0.4` | Android Firebase Crashlytics NDK version. |
| `IOS_FIREBASE_SDK_VERSION` | `12.9.0` | iOS Firebase SDK version (for crashlytics pod). |
| `FIREBASE_CRASHLYTICS_COLLECTION_ENABLED` | `true` | Enable/disable Crashlytics at startup. |

#### Performance (`cordova-plugin-firebasex-performance`)

| Variable | Default | Description |
|----------|---------|-------------|
| `ANDROID_FIREBASE_PERF_VERSION` | `22.0.2` | Android Firebase Performance SDK version. |
| `IOS_FIREBASE_SDK_VERSION` | `12.9.0` | iOS Firebase SDK version (for performance pod). |
| `FIREBASE_PERFORMANCE_COLLECTION_ENABLED` | `true` | Enable/disable performance collection. |
| `ANDROID_FIREBASE_PERFORMANCE_MONITORING` | `false` | Add Firebase Perf Gradle plugin (Android). |
| `ANDROID_FIREBASE_PERF_GRADLE_PLUGIN_VERSION` | `2.0.1` | Firebase Perf Gradle plugin version. |

#### Firestore (`cordova-plugin-firebasex-firestore`)

| Variable | Default | Description |
|----------|---------|-------------|
| `ANDROID_FIREBASE_FIRESTORE_VERSION` | `26.1.0` | Android Firebase Firestore SDK version. |
| `ANDROID_GRPC_OKHTTP` | `1.75.0` | Android gRPC OkHttp version (Firestore dependency). |
| `ANDROID_GSON_VERSION` | `2.13.2` | Google Gson library version (Firestore dependency). |
| `IOS_FIREBASE_SDK_VERSION` | `12.9.0` | iOS Firebase SDK version (for firestore pod). |
| `IOS_USE_PRECOMPILED_FIRESTORE_POD` | `false` | Use precompiled Firestore pod for faster builds. |

#### Functions (`cordova-plugin-firebasex-functions`)

| Variable | Default | Description |
|----------|---------|-------------|
| `ANDROID_FIREBASE_FUNCTIONS_VERSION` | `22.1.0` | Android Firebase Functions SDK version. |
| `ANDROID_GSON_VERSION` | `2.13.2` | Google Gson library version (Functions dependency). |
| `IOS_FIREBASE_SDK_VERSION` | `12.9.0` | iOS Firebase SDK version (for functions pod). |

#### Config (`cordova-plugin-firebasex-config`)

| Variable | Default | Description |
|----------|---------|-------------|
| `ANDROID_FIREBASE_CONFIG_VERSION` | `23.0.1` | Android Firebase Remote Config SDK version. |
| `IOS_FIREBASE_SDK_VERSION` | `12.9.0` | iOS Firebase SDK version (for config pod). |

#### In-App Messaging (`cordova-plugin-firebasex-inappmessaging`)

| Variable | Default | Description |
|----------|---------|-------------|
| `ANDROID_FIREBASE_INAPPMESSAGING_VERSION` | `22.0.2` | Android Firebase In-App Messaging SDK version. |
| `IOS_FIREBASE_SDK_VERSION` | `12.9.0-beta` | iOS Firebase SDK version (for inappmessaging pod). |

### Variable Resolution Order

Plugin variables are resolved using a layered override strategy (later layers take precedence):

1. **`plugin.xml` defaults** — Default values declared in each plugin's `<preference>` elements.
2. **`config.xml` overrides** — Values specified in `<plugin><variable>` elements in the project's `config.xml`.
3. **`package.json` overrides** — Values specified under `cordova.plugins` in the project's `package.json` (highest priority for build-time hooks).
4. **CLI variables** — Values passed via `--variable` at install time (highest priority for install-time hooks).

When using the **wrapper plugin**, variables specified under the wrapper's plugin ID (`cordova-plugin-firebasex`) in `config.xml` or `package.json` are also recognized by all modular plugins. The modular plugin's own ID takes precedence if both are present. This means existing `config.xml` entries like:

```xml
<plugin name="cordova-plugin-firebasex" spec="^20.0.0">
    <variable name="FIREBASE_ANALYTICS_WITHOUT_ADS" value="true" />
    <variable name="IOS_ENABLE_APPLE_SIGNIN" value="true" />
</plugin>
```

...will still be picked up by both the wrapper and the individual modular plugins.

### Preserving Custom Variable Values

If you have custom plugin variable values in your project, make sure they are preserved during migration.

**Check your `config.xml`** for any `<variable>` elements under the old plugin entry:

```xml
<!-- Look for this in your config.xml -->
<plugin name="cordova-plugin-firebasex" spec="...">
    <variable name="FIREBASE_ANALYTICS_WITHOUT_ADS" value="true" />
    <variable name="SETUP_RECAPTCHA_VERIFICATION" value="true" />
    <!-- etc. -->
</plugin>
```

**Check your `package.json`** for variable overrides:

```json
{
  "cordova": {
    "plugins": {
      "cordova-plugin-firebasex": {
        "FIREBASE_ANALYTICS_WITHOUT_ADS": "true",
        "SETUP_RECAPTCHA_VERIFICATION": "true"
      }
    }
  }
}
```

**When using the wrapper (Path A):** Your existing `config.xml` and `package.json` entries under the `cordova-plugin-firebasex` name will continue to work. The wrapper forwards variables to sub-plugins at install time, and each sub-plugin's hook scripts also check for variables under the wrapper's plugin ID as a fallback.

**When using individual plugins (Path B):** Move your variable values to the appropriate modular plugin entries:

```xml
<!-- config.xml — modular style -->
<plugin name="cordova-plugin-firebasex-analytics" spec="...">
    <variable name="FIREBASE_ANALYTICS_WITHOUT_ADS" value="true" />
</plugin>
<plugin name="cordova-plugin-firebasex-auth" spec="...">
    <variable name="SETUP_RECAPTCHA_VERIFICATION" value="true" />
</plugin>
```

```json
// package.json — modular style
{
  "cordova": {
    "plugins": {
      "cordova-plugin-firebasex-analytics": {
        "FIREBASE_ANALYTICS_WITHOUT_ADS": "true"
      },
      "cordova-plugin-firebasex-auth": {
        "SETUP_RECAPTCHA_VERIFICATION": "true"
      }
    }
  }
}
```

Alternatively, pass variables at install time with `--variable`:

```bash
cordova plugin add cordova-plugin-firebasex-analytics \
  --variable FIREBASE_ANALYTICS_WITHOUT_ADS=true
```

---

## Breaking Changes

### When using the wrapper (Path A)

- **Minimum platform versions:** The modular plugins require Cordova 12+, cordova-android 14+, and cordova-ios 7+. Ensure your project meets these requirements before upgrading.
- **No other breaking changes.** The wrapper preserves the `FirebasePlugin` global and all method signatures.

### When using individual plugins (Path B)

- **JavaScript globals have changed.** `FirebasePlugin` is no longer available. Each plugin registers its own global (e.g., `FirebasexMessaging`, `FirebasexAnalytics`). You must update all call sites. See [API Globals Reference](#api-globals-reference).
- **Method signatures are unchanged.** All methods accept the same arguments and return the same values as before. Only the object you call them on changes.
- **Plugin variables must be reassigned.** Variables previously set for `cordova-plugin-firebasex` need to be moved to the appropriate modular plugin entries in your `config.xml` and/or `package.json`. See [Preserving Custom Variable Values](#preserving-custom-variable-values).
- **Minimum platform versions** apply as described above.

### General notes

- **`GoogleService-Info.plist` and `google-services.json`** are still required in your project root. The core plugin handles copying them to the platform directories.
- **Custom FCM receivers** (`FirebasePluginMessageReceiver` subclasses) still work. The messaging plugin includes the receiver manager infrastructure.
- **Notification icons and accent colors** are configured via the messaging plugin's `ANDROID_ICON_ACCENT` variable and resource files, just as before.

---

## Plugin Documentation

For detailed API documentation and configuration options, refer to each plugin's README:

| Plugin | Documentation |
|--------|---------------|
| Core | [cordova-plugin-firebasex-core/README.md](https://github.com/dpa99c/cordova-plugin-firebasex-core/README.md) |
| Analytics | [cordova-plugin-firebasex-analytics/README.md](https://github.com/dpa99c/cordova-plugin-firebasex-analytics/README.md) |
| Messaging | [cordova-plugin-firebasex-messaging/README.md](https://github.com/dpa99c/cordova-plugin-firebasex-messaging/README.md) |
| Auth | [cordova-plugin-firebasex-auth/README.md](https://github.com/dpa99c/cordova-plugin-firebasex-auth/README.md) |
| Crashlytics | [cordova-plugin-firebasex-crashlytics/README.md](https://github.com/dpa99c/cordova-plugin-firebasex-crashlytics/README.md) |
| Firestore | [cordova-plugin-firebasex-firestore/README.md](https://github.com/dpa99c/cordova-plugin-firebasex-firestore/README.md) |
| Functions | [cordova-plugin-firebasex-functions/README.md](https://github.com/dpa99c/cordova-plugin-firebasex-functions/README.md) |
| Config | [cordova-plugin-firebasex-config/README.md](https://github.com/dpa99c/cordova-plugin-firebasex-config/README.md) |
| Performance | [cordova-plugin-firebasex-performance/README.md](https://github.com/dpa99c/cordova-plugin-firebasex-performance/README.md) |
| In-App Messaging | [cordova-plugin-firebasex-inappmessaging/README.md](https://github.com/dpa99c/cordova-plugin-firebasex-inappmessaging/README.md) |
| Wrapper (backward-compat) | [cordova-plugin-firebasex/README.md](./README.md) |
