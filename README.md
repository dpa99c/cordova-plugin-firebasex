# cordova-plugin-firebasex

The repo now contains a backward-compatible wrapper meta-plugin that installs all `cordova-plugin-firebasex` modular plugins.

*********

# DEPRECATED
As of v20, this original monolithic FirebaseX plugin is deprecated in favour the new modular plugin architecture.

*********

# Modular Plugins

- [cordova-plugin-firebasex-core](https://github.com/dpa99c/cordova-plugin-firebasex-core/) - Firebase initialization, config file handling
- [cordova-plugin-firebasex-analytics](https://github.com/dpa99c/cordova-plugin-firebasex-analytics/) - Firebase Analytics
- [cordova-plugin-firebasex-auth](https://github.com/dpa99c/cordova-plugin-firebasex-auth/) - Firebase Authentication
- [cordova-plugin-firebasex-config](https://github.com/dpa99c/cordova-plugin-firebasex-config/) - Firebase Remote Config
- [cordova-plugin-firebasex-crashlytics](https://github.com/dpa99c/cordova-plugin-firebasex-crashlytics/) - Firebase Crashlytics
- [cordova-plugin-firebasex-firestore](https://github.com/dpa99c/cordova-plugin-firebasex-firestore/) - Firebase Firestore
- [cordova-plugin-firebasex-functions](https://github.com/dpa99c/cordova-plugin-firebasex-functions/) - Firebase Cloud Functions
- [cordova-plugin-firebasex-inappmessaging](https://github.com/dpa99c/cordova-plugin-firebasex-inappmessaging/) - Firebase In-App Messaging
- [cordova-plugin-firebasex-messaging](https://github.com/dpa99c/cordova-plugin-firebasex-messaging/) - Firebase Cloud Messaging
- [cordova-plugin-firebasex-performance](https://github.com/dpa99c/cordova-plugin-firebasex-performance/) - Firebase Performance Monitoring

You are encouraged to [migrate to the new modular plugins](./MIGRATION.md) for better performance, smaller app size, and more flexible dependency management.

If you wish to use this monolithic version of the plugin, you can still install it as `cordova-plugin-firebasex@19` - see [the legacy documentation](./README.legacy.md) for details on the API and plugin variables of the monolithic plugin.
However there will be no further updates or fixes to this monolithic plugin.

*********

## Installation

```bash
cordova plugin add cordova-plugin-firebasex@latest
```

This installs all of the above modular plugins and re-exports their APIs under the unified `FirebasePlugin` global, maintaining backward compatibility with the original monolithic plugin.

On iOS, `cordova-ios@8+` uses Swift Package Manager for the Firebase SDK dependencies exposed by the modular plugins. No Podfile or `pod install` step is required on that path, and you should open the generated `App.xcodeproj` in Xcode. `cordova-ios@7.x` continues to use the retained CocoaPods fallback.

## Migration to Modular Plugins

See [the migration guide](./MIGRATION.md) for more details on migrating to the new modular plugins and how to manage plugin variables in the new architecture.

## API
When using this wrapper, all methods are available on the `FirebasePlugin` global, maintaining full backward compatibility with the monolithic plugin.

```javascript
// Same API as before
FirebasePlugin.getToken(function(token) {
    console.log("FCM token: " + token);
});
```

## Plugin variables
This wrapper plugin re-exports all plugin variables as defined for the original monolithic plugin, and passes them through to the modular plugins.
This means that all plugin variables defined in your `config.xml`/`package.json` for the original monolithic plugin will still be picked up and applied to the relevant modular plugins.

On iOS, the shared `IOS_FIREBASE_SDK_VERSION`, `IOS_GOOGLE_TAG_MANAGER_VERSION`, and `IOS_GOOGLE_SIGIN_VERSION` values now drive Swift Package Manager manifests for `cordova-ios@8+`. `IOS_USE_PRECOMPILED_FIRESTORE_POD` only affects the CocoaPods fallback path and is ignored when Swift Package Manager is active.

## Legacy plugin documentation

For documentation on the API and plugin variables of the monolithic plugin, see the [legacy documentation](./README.legacy.md).