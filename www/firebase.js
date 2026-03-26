/**
 * Backward-compatible wrapper that re-exports all modular plugin APIs
 * under the unified FirebasePlugin global, preserving the original API surface.
 */
var core = require("cordova-plugin-firebasex-core.FirebasexCorePlugin");
var analytics = require("cordova-plugin-firebasex-analytics.FirebasexAnalyticsPlugin");
var messaging = require("cordova-plugin-firebasex-messaging.FirebasexMessagingPlugin");
var auth = require("cordova-plugin-firebasex-auth.FirebasexAuthPlugin");
var crashlytics = require("cordova-plugin-firebasex-crashlytics.FirebasexCrashlyticsPlugin");
var firestore = require("cordova-plugin-firebasex-firestore.FirebasexFirestorePlugin");
var functions = require("cordova-plugin-firebasex-functions.FirebasexFunctionsPlugin");
var config = require("cordova-plugin-firebasex-config.FirebasexConfigPlugin");
var performance = require("cordova-plugin-firebasex-performance.FirebasexPerformancePlugin");

// Re-export all APIs under this unified module
var modules = [core, analytics, messaging, auth, crashlytics, firestore, functions, config, performance];
for (var i = 0; i < modules.length; i++) {
    var mod = modules[i];
    for (var key in mod) {
        if (mod.hasOwnProperty(key)) {
            exports[key] = mod[key];
        }
    }
}
