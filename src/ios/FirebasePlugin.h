#import "AppDelegate.h"
#import "FirebaseWrapper.h"
#import <Cordova/CDV.h>
@import FirebaseFirestore;

/**
 * @interface FirebasePlugin
 * @abstract Main plugin class for Firebase implementation in Cordova.
 * @discussion This class handles all communication between the Cordova webview
 * and the Firebase SDK on iOS. It supports various Firebase features including
 * Analytics, Auth, Crashlytics, Cloud Messaging, Firestore, Remote Config,
 * Performance, Functions, and Installations.
 */
@interface FirebasePlugin : CDVPlugin

/**
 * @method setAutoInitEnabled:
 * @abstract Enables or disables auto-initialization of Firebase Cloud
 * Messaging.
 * @param command The Cordova command object containing the boolean 'enabled'
 * state.
 */
- (void)setAutoInitEnabled:(CDVInvokedUrlCommand *)command;

/**
 * @method isAutoInitEnabled:
 * @abstract Checks if auto-initialization of Firebase Cloud Messaging is
 * enabled.
 * @param command The Cordova command object.
 */
- (void)isAutoInitEnabled:(CDVInvokedUrlCommand *)command;

/**
 * @method sendPendingNotifications
 * @abstract Flushes the notification stack and sends any pending notifications
 * to the webview.
 */
- (void)sendPendingNotifications;

// Authentication

/**
 * @method verifyPhoneNumber:
 * @abstract Starts the phone number verification flow.
 * @param command The Cordova command object containing the phone number and
 * optional settings.
 */
- (void)verifyPhoneNumber:(CDVInvokedUrlCommand *)command;

/**
 * @method setLanguageCode:
 * @abstract Sets the language code for Firebase Auth operations (e.g., email
 * templates).
 * @param command The Cordova command object containing the language code
 * string.
 */
- (void)setLanguageCode:(CDVInvokedUrlCommand *)command;

/**
 * @method createUserWithEmailAndPassword:
 * @abstract Creates a new user account with the specified email and password.
 * @param command The Cordova command object containing email and password.
 */
- (void)createUserWithEmailAndPassword:(CDVInvokedUrlCommand *)command;

/**
 * @method signInUserWithEmailAndPassword:
 * @abstract Signs in a user with the specified email and password.
 * @param command The Cordova command object containing email and password.
 */
- (void)signInUserWithEmailAndPassword:(CDVInvokedUrlCommand *)command;

/**
 * @method authenticateUserWithEmailAndPassword:
 * @abstract Authenticates a user with email and password without immediately
 * signing them in.
 * @param command The Cordova command object.
 */
- (void)authenticateUserWithEmailAndPassword:(CDVInvokedUrlCommand *)command;

/**
 * @method signInUserWithCustomToken:
 * @abstract Signs in a user using a custom server-generated token.
 * @param command The Cordova command object containing the custom token.
 */
- (void)signInUserWithCustomToken:(CDVInvokedUrlCommand *)command;

/**
 * @method signInUserAnonymously:
 * @abstract Signs in a user anonymously.
 * @param command The Cordova command object.
 */
- (void)signInUserAnonymously:(CDVInvokedUrlCommand *)command;

/**
 * @method authenticateUserWithGoogle:
 * @abstract Performs Google Sign-In authentication.
 * @param command The Cordova command object.
 */
- (void)authenticateUserWithGoogle:(CDVInvokedUrlCommand *)command;

/**
 * @method authenticateUserWithApple:
 * @abstract Performs Apple Sign-In authentication.
 * @param command The Cordova command object.
 */
- (void)authenticateUserWithApple:(CDVInvokedUrlCommand *)command;

/**
 * @method authenticateUserWithMicrosoft:
 * @abstract Performs Microsoft Sign-In authentication via OAuth.
 * @param command The Cordova command object.
 */
- (void)authenticateUserWithMicrosoft:(CDVInvokedUrlCommand *)command;

/**
 * @method authenticateUserWithFacebook:
 * @abstract Performs Facebook Sign-In authentication.
 * @param command The Cordova command object containing the Facebook access
 * token.
 */
- (void)authenticateUserWithFacebook:(CDVInvokedUrlCommand *)command;

/**
 * @method authenticateUserWithOAuth:
 * @abstract Performs authentication with arbitrary OAuth providers.
 * @param command The Cordova command object containing provider ID, custom
 * parameters, and scopes.
 */
- (void)authenticateUserWithOAuth:(CDVInvokedUrlCommand *)command;

/**
 * @method signInWithCredential:
 * @abstract Signs in a user with a provided credential object.
 * @param command The Cordova command object containing the credential details.
 */
- (void)signInWithCredential:(CDVInvokedUrlCommand *)command;

/**
 * @method linkUserWithCredential:
 * @abstract Links the current user with a provided credential.
 * @param command The Cordova command object.
 */
- (void)linkUserWithCredential:(CDVInvokedUrlCommand *)command;

/**
 * @method unlinkUserWithProvider:
 * @abstract Unlinks the current user from a specified provider.
 * @param command The Cordova command object containing the provider ID.
 */
- (void)unlinkUserWithProvider:(CDVInvokedUrlCommand *)command;

/**
 * @method reauthenticateWithCredential:
 * @abstract Re-authenticates the current user with a provided credential.
 * @param command The Cordova command object.
 */
- (void)reauthenticateWithCredential:(CDVInvokedUrlCommand *)command;

/**
 * @method isUserSignedIn:
 * @abstract Checks if a user is currently signed in.
 * @param command The Cordova command object.
 */
- (void)isUserSignedIn:(CDVInvokedUrlCommand *)command;

/**
 * @method signOutUser:
 * @abstract Signs out the current user.
 * @param command The Cordova command object.
 */
- (void)signOutUser:(CDVInvokedUrlCommand *)command;

/**
 * @method getCurrentUser:
 * @abstract Retrieves information about the currently signed-in user.
 * @param command The Cordova command object.
 */
- (void)getCurrentUser:(CDVInvokedUrlCommand *)command;

/**
 * @method reloadCurrentUser:
 * @abstract Reloads the current user's profile data from Firebase.
 * @param command The Cordova command object.
 */
- (void)reloadCurrentUser:(CDVInvokedUrlCommand *)command;

/**
 * @method updateUserProfile:
 * @abstract Updates the current user's display name and/or photo URL.
 * @param command The Cordova command object containing the new profile data.
 */
- (void)updateUserProfile:(CDVInvokedUrlCommand *)command;

/**
 * @method updateUserEmail:
 * @abstract Updates the current user's email address.
 * @param command The Cordova command object containing the new email.
 */
- (void)updateUserEmail:(CDVInvokedUrlCommand *)command;

/**
 * @method verifyBeforeUpdateEmail:
 * @abstract Sends a verification email before updating the user's email
 * address.
 * @param command The Cordova command object.
 */
- (void)verifyBeforeUpdateEmail:(CDVInvokedUrlCommand *)command;

/**
 * @method sendUserEmailVerification:
 * @abstract Sends a verification email to the current user.
 * @param command The Cordova command object containing optional action code
 * settings.
 */
- (void)sendUserEmailVerification:(CDVInvokedUrlCommand *)command;

/**
 * @method updateUserPassword:
 * @abstract Updates the current user's password.
 * @param command The Cordova command object containing the new password.
 */
- (void)updateUserPassword:(CDVInvokedUrlCommand *)command;

/**
 * @method sendUserPasswordResetEmail:
 * @abstract Sends a password reset email to the specified email address.
 * @param command The Cordova command object containing the email address.
 */
- (void)sendUserPasswordResetEmail:(CDVInvokedUrlCommand *)command;

/**
 * @method deleteUser:
 * @abstract Deletes the current user's account.
 * @param command The Cordova command object.
 */
- (void)deleteUser:(CDVInvokedUrlCommand *)command;

/**
 * @method useAuthEmulator:
 * @abstract Configures Firebase Auth to use a local emulator.
 * @param command The Cordova command object containing host and port.
 */
- (void)useAuthEmulator:(CDVInvokedUrlCommand *)command;

/**
 * @method getClaims:
 * @abstract Retrieves the custom claims and ID token result for the current
 * user.
 * @param command The Cordova command object.
 */
- (void)getClaims:(CDVInvokedUrlCommand *)command;

/**
 * @method enrollSecondAuthFactor:
 * @abstract Enrolls a second factor (e.g., SMS) for multi-factor
 * authentication.
 * @param command The Cordova command object.
 */
- (void)enrollSecondAuthFactor:(CDVInvokedUrlCommand *)command;

/**
 * @method verifySecondAuthFactor:
 * @abstract Verifies a second factor during a multi-factor auth challenge.
 * @param command The Cordova command object.
 */
- (void)verifySecondAuthFactor:(CDVInvokedUrlCommand *)command;

/**
 * @method listEnrolledSecondAuthFactors:
 * @abstract Lists all enrolled second factors for the current user.
 * @param command The Cordova command object.
 */
- (void)listEnrolledSecondAuthFactors:(CDVInvokedUrlCommand *)command;

/**
 * @method unenrollSecondAuthFactor:
 * @abstract Unenrolls a specified second factor.
 * @param command The Cordova command object containing the factor index.
 */
- (void)unenrollSecondAuthFactor:(CDVInvokedUrlCommand *)command;

// Remote notifications

/**
 * @method getId:
 * @abstract Retrieves the Firebase installation ID.
 * @param command The Cordova command object.
 */
- (void)getId:(CDVInvokedUrlCommand *)command;

/**
 * @method getToken:
 * @abstract Retrieves the FCM registration token.
 * @param command The Cordova command object.
 */
- (void)getToken:(CDVInvokedUrlCommand *)command;

/**
 * @method getAPNSToken:
 * @abstract Retrieves the current APNS token.
 * @param command The Cordova command object.
 */
- (void)getAPNSToken:(CDVInvokedUrlCommand *)command;

/**
 * @method hexadecimalStringFromData:
 * @abstract Converts binary data to a hexadecimal string representation.
 * @param data The NSData to convert.
 * @return A hexadecimal string.
 */
- (NSString *)hexadecimalStringFromData:(NSData *)data;

/**
 * @method grantPermission:
 * @abstract Requests permission for remote notifications.
 * @param command The Cordova command object.
 */
- (void)grantPermission:(CDVInvokedUrlCommand *)command;

/**
 * @method hasPermission:
 * @abstract Checks if the app has permission for remote notifications.
 * @param command The Cordova command object.
 */
- (void)hasPermission:(CDVInvokedUrlCommand *)command;

/**
 * @method grantCriticalPermission:
 * @abstract Requests permission for critical alerts (iOS 12+).
 * @param command The Cordova command object.
 */
- (void)grantCriticalPermission:(CDVInvokedUrlCommand *)command;

/**
 * @method hasCriticalPermission:
 * @abstract Checks if the app has permission for critical alerts.
 * @param command The Cordova command object.
 */
- (void)hasCriticalPermission:(CDVInvokedUrlCommand *)command;

/**
 * @method setBadgeNumber:
 * @abstract Sets the application icon badge number.
 * @param command The Cordova command object containing the badge number.
 */
- (void)setBadgeNumber:(CDVInvokedUrlCommand *)command;

/**
 * @method getBadgeNumber:
 * @abstract Retrieves the current application icon badge number.
 * @param command The Cordova command object.
 */
- (void)getBadgeNumber:(CDVInvokedUrlCommand *)command;

/**
 * @method subscribe:
 * @abstract Subscribes to an FCM topic.
 * @param command The Cordova command object containing the topic name.
 */
- (void)subscribe:(CDVInvokedUrlCommand *)command;

/**
 * @method unsubscribe:
 * @abstract Unsubscribes from an FCM topic.
 * @param command The Cordova command object containing the topic name.
 */
- (void)unsubscribe:(CDVInvokedUrlCommand *)command;

/**
 * @method unregister:
 * @abstract Unregisters the current FCM token.
 * @param command The Cordova command object.
 */
- (void)unregister:(CDVInvokedUrlCommand *)command;

/**
 * @method onOpenSettings:
 * @abstract Registers a callback for when notification settings are opened from
 * the system settings.
 * @param command The Cordova command object.
 */
- (void)onOpenSettings:(CDVInvokedUrlCommand *)command;

/**
 * @method onMessageReceived:
 * @abstract Registers a callback for when a notification is received.
 * @param command The Cordova command object.
 */
- (void)onMessageReceived:(CDVInvokedUrlCommand *)command;

/**
 * @method onTokenRefresh:
 * @abstract Registers a callback for when the FCM token is refreshed.
 * @param command The Cordova command object.
 */
- (void)onTokenRefresh:(CDVInvokedUrlCommand *)command;

/**
 * @method onApnsTokenReceived:
 * @abstract Registers a callback for when the APNS token is received.
 * @param command The Cordova command object.
 */
- (void)onApnsTokenReceived:(CDVInvokedUrlCommand *)command;

/**
 * @method sendOpenNotificationSettings
 * @abstract Sends the 'open notification settings' event to the webview.
 */
- (void)sendOpenNotificationSettings;

/**
 * @method sendNotification:
 * @abstract Internal method to send a notification payload to the webview.
 * @param userInfo The notification dictionary.
 */
- (void)sendNotification:(NSDictionary *)userInfo;

/**
 * @method sendToken:
 * @abstract Internal method to send a new FCM token to the webview.
 * @param token The new token string.
 */
- (void)sendToken:(NSString *)token;

/**
 * @method sendApnsToken:
 * @abstract Internal method to send a new APNS token to the webview.
 * @param token The new APNS token string.
 */
- (void)sendApnsToken:(NSString *)token;

/**
 * @method clearAllNotifications:
 * @abstract Clears all notifications from the notification center and resets
 * the badge.
 * @param command The Cordova command object.
 */
- (void)clearAllNotifications:(CDVInvokedUrlCommand *)command;

// Analytics

/**
 * @method setAnalyticsCollectionEnabled:
 * @abstract Enables or disables automatic analytics collection.
 * @param command The Cordova command object.
 */
- (void)setAnalyticsCollectionEnabled:(CDVInvokedUrlCommand *)command;

/**
 * @method isAnalyticsCollectionEnabled:
 * @abstract Checks if automatic analytics collection is enabled.
 * @param command The Cordova command object.
 */
- (void)isAnalyticsCollectionEnabled:(CDVInvokedUrlCommand *)command;

/**
 * @method setAnalyticsConsentMode:
 * @abstract Sets the analytics consent mode (GDPR compliance).
 * @param command The Cordova command object containing consent settings.
 */
- (void)setAnalyticsConsentMode:(CDVInvokedUrlCommand *)command;

/**
 * @method logEvent:
 * @abstract Logs a custom analytics event.
 * @param command The Cordova command object containing event name and
 * parameters.
 */
- (void)logEvent:(CDVInvokedUrlCommand *)command;

/**
 * @method setScreenName:
 * @abstract Logs a screen view analytics event.
 * @param command The Cordova command object containing the screen name.
 */
- (void)setScreenName:(CDVInvokedUrlCommand *)command;

/**
 * @method setUserId:
 * @abstract Sets the user ID for analytics.
 * @param command The Cordova command object containing the user ID.
 */
- (void)setUserId:(CDVInvokedUrlCommand *)command;

/**
 * @method setUserProperty:
 * @abstract Sets a custom user property for analytics.
 * @param command The Cordova command object containing property name and value.
 */
- (void)setUserProperty:(CDVInvokedUrlCommand *)command;

/**
 * @method initiateOnDeviceConversionMeasurement:
 * @abstract Initiates on-device conversion measurement.
 * @param command The Cordova command object.
 */
- (void)initiateOnDeviceConversionMeasurement:(CDVInvokedUrlCommand *)command;

// Crashlytics

/**
 * @method setCrashlyticsCollectionEnabled:
 * @abstract Enables or disables automatic crash reporting.
 * @param command The Cordova command object.
 */
- (void)setCrashlyticsCollectionEnabled:(CDVInvokedUrlCommand *)command;

/**
 * @method isCrashlyticsCollectionEnabled:
 * @abstract Checks if automatic crash reporting is enabled.
 * @param command The Cordova command object.
 */
- (void)isCrashlyticsCollectionEnabled:(CDVInvokedUrlCommand *)command;

/**
 * @method didCrashOnPreviousExecution:
 * @abstract Checks if the app crashed during its previous execution.
 * @param command The Cordova command object.
 */
- (void)didCrashOnPreviousExecution:(CDVInvokedUrlCommand *)command;

/**
 * @method setCrashlyticsCustomKey:
 * @abstract Sets a custom key-value pair for crash reports.
 * @param command The Cordova command object.
 */
- (void)setCrashlyticsCustomKey:(CDVInvokedUrlCommand *)command;

/**
 * @method logError:
 * @abstract Logs a non-fatal error to Crashlytics.
 * @param command The Cordova command object containing error message and
 * optional stack trace.
 */
- (void)logError:(CDVInvokedUrlCommand *)command;

/**
 * @method logMessage:
 * @abstract Logs a custom message to Crashlytics breadcrumbs.
 * @param command The Cordova command object containing the message.
 */
- (void)logMessage:(CDVInvokedUrlCommand *)command;

/**
 * @method sendCrash:
 * @abstract Forces a native crash for testing purposes.
 * @param command The Cordova command object.
 */
- (void)sendCrash:(CDVInvokedUrlCommand *)command;

/**
 * @method setCrashlyticsUserId:
 * @abstract Sets a custom user ID for crash reports.
 * @param command The Cordova command object containing the user ID.
 */
- (void)setCrashlyticsUserId:(CDVInvokedUrlCommand *)command;

// Remote config

/**
 * @method fetch:
 * @abstract Fetches remote configuration values from the server.
 * @param command The Cordova command object with optional expiration time.
 */
- (void)fetch:(CDVInvokedUrlCommand *)command;

/**
 * @method activateFetched:
 * @abstract Activates the last-fetched remote configuration values.
 * @param command The Cordova command object.
 */
- (void)activateFetched:(CDVInvokedUrlCommand *)command;

/**
 * @method getValue:
 * @abstract Retrieves a remote configuration value for the specified key.
 * @param command The Cordova command object containing the key.
 */
- (void)getValue:(CDVInvokedUrlCommand *)command;

/**
 * @method getInfo:
 * @abstract Retrieves information about the current remote configuration state.
 * @param command The Cordova command object.
 */
- (void)getInfo:(CDVInvokedUrlCommand *)command;

/**
 * @method fetchAndActivate:
 * @abstract Combined fetch and activate operation for remote configuration.
 * @param command The Cordova command object.
 */
- (void)fetchAndActivate:(CDVInvokedUrlCommand *)command;

/**
 * @method getAll:
 * @abstract Retrieves all remote configuration values.
 * @param command The Cordova command object.
 */
- (void)getAll:(CDVInvokedUrlCommand *)command;

/**
 * @method resetRemoteConfig:
 * @abstract Resets all remote configuration values to defaults.
 * @param command The Cordova command object.
 */
- (void)resetRemoteConfig:(CDVInvokedUrlCommand *)command;

/**
 * @method setConfigSettings:
 * @abstract Configures remote configuration settings (e.g., timeout).
 * @param command The Cordova command object.
 */
- (void)setConfigSettings:(CDVInvokedUrlCommand *)command;

/**
 * @method setDefaults:
 * @abstract Sets default remote configuration values.
 * @param command The Cordova command object.
 */
- (void)setDefaults:(CDVInvokedUrlCommand *)command;

// Performance

/**
 * @method setPerformanceCollectionEnabled:
 * @abstract Enables or disables automatic performance monitoring.
 * @param command The Cordova command object.
 */
- (void)setPerformanceCollectionEnabled:(CDVInvokedUrlCommand *)command;

/**
 * @method isPerformanceCollectionEnabled:
 * @abstract Checks if automatic performance monitoring is enabled.
 * @param command The Cordova command object.
 */
- (void)isPerformanceCollectionEnabled:(CDVInvokedUrlCommand *)command;

/**
 * @method startTrace:
 * @abstract Starts a custom performance trace.
 * @param command The Cordova command object containing the trace name.
 */
- (void)startTrace:(CDVInvokedUrlCommand *)command;

/**
 * @method incrementCounter:
 * @abstract Increments a metric in an active performance trace.
 * @param command The Cordova command object containing trace name and metric
 * name.
 */
- (void)incrementCounter:(CDVInvokedUrlCommand *)command;

/**
 * @method stopTrace:
 * @abstract Stops an active performance trace.
 * @param command The Cordova command object containing the trace name.
 */
- (void)stopTrace:(CDVInvokedUrlCommand *)command;

// Firestore

/**
 * @method addDocumentToFirestoreCollection:
 * @abstract Adds a new document to a Firestore collection.
 * @param command The Cordova command object containing document data and
 * collection name.
 */
- (void)addDocumentToFirestoreCollection:(CDVInvokedUrlCommand *)command;

/**
 * @method setDocumentInFirestoreCollection:
 * @abstract Sets or overwrites a document in a Firestore collection.
 * @param command The Cordova command object.
 */
- (void)setDocumentInFirestoreCollection:(CDVInvokedUrlCommand *)command;

/**
 * @method updateDocumentInFirestoreCollection:
 * @abstract Updates fields in a Firestore document.
 * @param command The Cordova command object.
 */
- (void)updateDocumentInFirestoreCollection:(CDVInvokedUrlCommand *)command;

/**
 * @method deleteDocumentFromFirestoreCollection:
 * @abstract Deletes a document from a Firestore collection.
 * @param command The Cordova command object.
 */
- (void)deleteDocumentFromFirestoreCollection:(CDVInvokedUrlCommand *)command;

/**
 * @method documentExistsInFirestoreCollection:
 * @abstract Checks if a document exists in a Firestore collection.
 * @param command The Cordova command object.
 */
- (void)documentExistsInFirestoreCollection:(CDVInvokedUrlCommand *)command;

/**
 * @method fetchDocumentInFirestoreCollection:
 * @abstract Fetches a single document from a Firestore collection.
 * @param command The Cordova command object.
 */
- (void)fetchDocumentInFirestoreCollection:(CDVInvokedUrlCommand *)command;

/**
 * @method fetchFirestoreCollection:
 * @abstract Fetches multiple documents from a Firestore collection with
 * optional filters.
 * @param command The Cordova command object.
 */
- (void)fetchFirestoreCollection:(CDVInvokedUrlCommand *)command;

/**
 * @method listenToDocumentInFirestoreCollection:
 * @abstract Starts listening for changes to a Firestore document.
 * @param command The Cordova command object.
 */
- (void)listenToDocumentInFirestoreCollection:(CDVInvokedUrlCommand *)command;

/**
 * @method listenToFirestoreCollection:
 * @abstract Starts listening for changes to a Firestore collection.
 * @param command The Cordova command object.
 */
- (void)listenToFirestoreCollection:(CDVInvokedUrlCommand *)command;

/**
 * @method removeFirestoreListener:
 * @abstract Removes an active Firestore listener.
 * @param command The Cordova command object containing the listener ID.
 */
- (void)removeFirestoreListener:(CDVInvokedUrlCommand *)command;

// Functions

/**
 * @method functionsHttpsCallable:
 * @abstract Calls a Firebase Cloud Function via HTTPS.
 * @param command The Cordova command object containing function name and
 * arguments.
 */
- (void)functionsHttpsCallable:(CDVInvokedUrlCommand *)command;

// Installations

/**
 * @method getInstallationId:
 * @abstract Retrieves the Firebase installation ID.
 * @param command The Cordova command object.
 */
- (void)getInstallationId:(CDVInvokedUrlCommand *)command;

/**
 * @method getInstallationToken:
 * @abstract Retrieves the Firebase installation auth token.
 * @param command The Cordova command object.
 */
- (void)getInstallationToken:(CDVInvokedUrlCommand *)command;

/**
 * @method deleteInstallationId:
 * @abstract Deletes the current Firebase installation ID.
 * @param command The Cordova command object.
 */
- (void)deleteInstallationId:(CDVInvokedUrlCommand *)command;

// Internals

/**
 * @method firebasePlugin
 * @abstract Returns the current singleton instance of the FirebasePlugin.
 * @return The active FirebasePlugin instance.
 */
+ (FirebasePlugin *)firebasePlugin;

/**
 * @method appleSignInNonce
 * @abstract Returns the nonce used for the current Apple Sign-In flow.
 * @return The sign-in nonce string.
 */
+ (NSString *)appleSignInNonce;

/**
 * @method setFirestore:
 * @abstract Sets the Firestore instance to be used by the plugin.
 * @param firestoreInstance The FIRFirestore instance.
 */
+ (void)setFirestore:(FIRFirestore *)firestoreInstance;

/**
 * @method handlePluginExceptionWithContext: :
 * @abstract Handles a native exception and sends an error response to the
 * webview.
 * @param exception The caught exception.
 * @param command The active Cordova command.
 */
- (void)handlePluginExceptionWithContext:(NSException *)
                               exception:(CDVInvokedUrlCommand *)command;

/**
 * @method handlePluginExceptionWithoutContext:
 * @abstract Handles a native exception without an active command context.
 * @param exception The caught exception.
 */
- (void)handlePluginExceptionWithoutContext:(NSException *)exception;

/**
 * @method _logError:
 * @abstract Logs an error message to the console.
 * @param msg The error message.
 */
- (void)_logError:(NSString *)msg;

/**
 * @method _logInfo:
 * @abstract Logs an informational message to the console.
 * @param msg The info message.
 */
- (void)_logInfo:(NSString *)msg;

/**
 * @method _logMessage:
 * @abstract Logs a message to the console.
 * @param msg The log message.
 */
- (void)_logMessage:(NSString *)msg;

/**
 * @method _shouldEnableCrashlytics
 * @abstract Checks if crash reporting should be enabled based on settings.
 * @return YES if crashlytics should be enabled.
 */
- (BOOL)_shouldEnableCrashlytics;

/**
 * @method saveAuthCredential:
 * @abstract Saves a Firebase credential object and returns an integer ID for
 * retrieval by the webview.
 * @param authCredential The FIRAuthCredential to save.
 * @return A unique key for the saved credential.
 */
- (NSNumber *)saveAuthCredential:(FIRAuthCredential *)authCredential;

/**
 * @method executeGlobalJavascript:
 * @abstract Executes a string of Javascript in the webview context.
 * @param jsString The Javascript to execute.
 */
- (void)executeGlobalJavascript:(NSString *)jsString;

/**
 * @method createChannel:
 * @abstract Creates a notification channel (Android stub on iOS).
 * @param command The Cordova command object.
 */
- (void)createChannel:(CDVInvokedUrlCommand *)command;

/**
 * @method setDefaultChannel:
 * @abstract Sets the default notification channel (Android stub on iOS).
 * @param command The Cordova command object.
 */
- (void)setDefaultChannel:(CDVInvokedUrlCommand *)command;

/**
 * @method deleteChannel:
 * @abstract Deletes a notification channel (Android stub on iOS).
 * @param command The Cordova command object.
 */
- (void)deleteChannel:(CDVInvokedUrlCommand *)command;

/**
 * @method listChannels:
 * @abstract Lists all notification channels (Android stub on iOS).
 * @param command The Cordova command object.
 */
- (void)listChannels:(CDVInvokedUrlCommand *)command;

/**
 * @property isFCMEnabled
 * @abstract Indicates if Firebase Cloud Messaging is enabled for this
 * application.
 */
@property(nonatomic, readonly) BOOL isFCMEnabled;

/**
 * @property notificationCallbackId
 * @abstract The Cordova callback ID for notification events.
 */
@property(nonatomic, copy) NSString *notificationCallbackId;

/**
 * @property openSettingsCallbackId
 * @abstract The Cordova callback ID for notification settings events.
 */
@property(nonatomic, copy) NSString *openSettingsCallbackId;

/**
 * @property tokenRefreshCallbackId
 * @abstract The Cordova callback ID for FCM token refresh events.
 */
@property(nonatomic, copy) NSString *tokenRefreshCallbackId;

/**
 * @property apnsTokenRefreshCallbackId
 * @abstract The Cordova callback ID for APNS token refresh events.
 */
@property(nonatomic, copy) NSString *apnsTokenRefreshCallbackId;

/**
 * @property appleSignInCallbackId
 * @abstract The Cordova callback ID for Apple Sign-In events.
 */
@property(nonatomic, copy) NSString *appleSignInCallbackId;

/**
 * @property notificationStack
 * @abstract Array of pending notifications waitning to be sent to the webview.
 */
@property(nonatomic, retain) NSMutableArray *notificationStack;

/**
 * @property installationIDObserver
 * @abstract Observer for Firebase Installation ID changes.
 */
@property(nonatomic, nullable) id<NSObject> installationIDObserver;

@end
