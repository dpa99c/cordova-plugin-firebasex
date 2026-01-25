#import "FirebasePlugin.h"
#import "AppDelegate+FirebasePlugin.h"
#import "AppDelegate.h"
#import "FirebasePluginMessageReceiverManager.h"
#import <Cordova/CDV.h>
#import <GoogleSignIn/GoogleSignIn.h>
@import FirebaseMessaging;
@import FirebaseAnalytics;
@import FirebaseRemoteConfig;
@import FirebasePerformance;
@import FirebaseCore;
@import FirebaseAuth;
@import FirebaseFunctions;
@import UserNotifications;
@import CommonCrypto;
@import AuthenticationServices;

@implementation FirebasePlugin

@synthesize openSettingsCallbackId;
@synthesize notificationCallbackId;
@synthesize tokenRefreshCallbackId;
@synthesize apnsTokenRefreshCallbackId;
@synthesize appleSignInCallbackId;
@synthesize notificationStack;

static NSString *const LOG_TAG = @"FirebasePlugin[native]";
static NSInteger const kNotificationStackSize = 32;
static NSString *const FIREBASE_CRASHLYTICS_COLLECTION_ENABLED =
    @"FIREBASE_CRASHLYTICS_COLLECTION_ENABLED"; // preference
static NSString *const FirebaseCrashlyticsCollectionEnabled =
    @"FirebaseCrashlyticsCollectionEnabled"; // plist
static NSString *const FIREBASE_ANALYTICS_COLLECTION_ENABLED =
    @"FIREBASE_ANALYTICS_COLLECTION_ENABLED";
static NSString *const FIREBASE_PERFORMANCE_COLLECTION_ENABLED =
    @"FIREBASE_PERFORMANCE_COLLECTION_ENABLED";

static NSString *const GOOGLE_ANALYTICS_ADID_COLLECTION_ENABLED =
    @"GOOGLE_ANALYTICS_ADID_COLLECTION_ENABLED";
static NSString *const GOOGLE_ANALYTICS_DEFAULT_ALLOW_ANALYTICS_STORAGE =
    @"GOOGLE_ANALYTICS_DEFAULT_ALLOW_ANALYTICS_STORAGE";
static NSString *const GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_STORAGE =
    @"GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_STORAGE";
static NSString *const GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_USER_DATA =
    @"GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_USER_DATA";
static NSString
    *const GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS =
        @"GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS";

static NSString *const FIREBASEX_IOS_FCM_ENABLED = @"FIREBASEX_IOS_FCM_ENABLED";

static FirebasePlugin *firebasePlugin;
static BOOL pluginInitialized = NO;
static BOOL registeredForRemoteNotifications = NO;
static BOOL openSettingsEmitted = NO;
static BOOL immediateMessagePayloadDelivery = NO;
static NSMutableDictionary *authCredentials;
static NSString *currentNonce; // used for Apple Sign In
static FIRFirestore *firestore;
static NSUserDefaults *preferences;
static NSDictionary *googlePlist;
static NSMutableDictionary *firestoreListeners;
static NSString *currentInstallationId;
static NSMutableDictionary *traces;
static FIRMultiFactorResolver *multiFactorResolver;
static FIROAuthProvider *oauthProvider;
static NSMutableArray *pendingGlobalJS = nil;

/**
 * Returns the current singleton instance of the FirebasePlugin.
 *
 * @return The active FirebasePlugin instance.
 */
+ (FirebasePlugin *)firebasePlugin {
  return firebasePlugin;
}

/**
 * Returns the nonce used for the current Apple Sign-In flow.
 *
 * @return The sign-in nonce string.
 */
+ (NSString *)appleSignInNonce {
  return currentNonce;
}

+ (void)setFirestore:(FIRFirestore *)firestoreInstance {
  firestore = firestoreInstance;
}

- (void)applicationLaunchedWithUrl:(NSNotification *)notification {
  NSURL *url = [notification object];
  [[GIDSignIn sharedInstance] handleURL:url];
}

// @override abstract
/**
 * Initializes the plugin instance.
 * Sets up initial preferences, Firebase SDK, and global state.
 */
- (void)pluginInitialize {
  NSLog(@"Starting Firebase plugin");
  firebasePlugin = self;

  @try {
    preferences = [NSUserDefaults standardUserDefaults];
    googlePlist = [NSMutableDictionary
        dictionaryWithContentsOfFile:[[NSBundle mainBundle]
                                         pathForResource:@"GoogleService-Info"
                                                  ofType:@"plist"]];
    immediateMessagePayloadDelivery = [[[NSBundle mainBundle]
        objectForInfoDictionaryKey:
            @"FIREBASE_MESSAGING_IMMEDIATE_PAYLOAD_DELIVERY"] boolValue];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(applicationLaunchedWithUrl:)
               name:CDVPluginHandleOpenURLNotification
             object:nil];

    if ([self getGooglePlistFlagWithDefaultValue:
                  FIREBASE_ANALYTICS_COLLECTION_ENABLED
                                    defaultValue:YES]) {
      [self setPreferenceFlag:FIREBASE_ANALYTICS_COLLECTION_ENABLED flag:YES];
    }

    if ([self getGooglePlistFlagWithDefaultValue:
                  FIREBASE_PERFORMANCE_COLLECTION_ENABLED
                                    defaultValue:YES]) {
      [self setPreferenceFlag:FIREBASE_PERFORMANCE_COLLECTION_ENABLED flag:YES];
    }

    if ([self getGooglePlistFlagWithDefaultValue:
                  FirebaseCrashlyticsCollectionEnabled
                                    defaultValue:YES]) {
      [self setPreferenceFlag:FIREBASE_CRASHLYTICS_COLLECTION_ENABLED flag:YES];
    }

    if ([self getGooglePlistFlagWithDefaultValue:
                  GOOGLE_ANALYTICS_ADID_COLLECTION_ENABLED
                                    defaultValue:YES]) {
      [self setPreferenceFlag:GOOGLE_ANALYTICS_ADID_COLLECTION_ENABLED
                         flag:YES];
    }

    if ([self getGooglePlistFlagWithDefaultValue:
                  GOOGLE_ANALYTICS_DEFAULT_ALLOW_ANALYTICS_STORAGE
                                    defaultValue:YES]) {
      [self setPreferenceFlag:GOOGLE_ANALYTICS_DEFAULT_ALLOW_ANALYTICS_STORAGE
                         flag:YES];
    }

    if ([self getGooglePlistFlagWithDefaultValue:
                  GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_STORAGE
                                    defaultValue:YES]) {
      [self setPreferenceFlag:GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_STORAGE
                         flag:YES];
    }

    if ([self getGooglePlistFlagWithDefaultValue:
                  GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_USER_DATA
                                    defaultValue:YES]) {
      [self setPreferenceFlag:GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_USER_DATA
                         flag:YES];
    }

    if ([self getGooglePlistFlagWithDefaultValue:
                  GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS
                                    defaultValue:YES]) {
      [self setPreferenceFlag:
                GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS
                         flag:YES];
    }

    // We don't need `setPreferenceFlag` here as we don't allow to change this
    // at runtime.
    _isFCMEnabled =
        [self getGooglePlistFlagWithDefaultValue:FIREBASEX_IOS_FCM_ENABLED
                                    defaultValue:YES];
    if (!self.isFCMEnabled) {
      [self _logInfo:@"Firebase Cloud Messaging is disabled, see "
                     @"IOS_FCM_ENABLED variable of the plugin"];
    }

    // Set actionable categories if pn-actions.json exist in bundle
    [self setActionableNotifications];

    // Check for permission and register for remote notifications if granted
    if (self.isFCMEnabled) {
      [self _hasPermission:^(BOOL result){
      }];
    }

    authCredentials = [[NSMutableDictionary alloc] init];
    firestoreListeners = [[NSMutableDictionary alloc] init];
    traces = [[NSMutableDictionary alloc] init];

    pluginInitialized = YES;
    [self executePendingGlobalJavascript];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithoutContext:exception];
  }
}

// Dynamic actions from pn-actions.json
/**
 * Configures actionable notifications from a pn-actions.json file if it exists
 * in the bundle.
 */
- (void)setActionableNotifications {

  @try {

    // Initialize installation ID change listener
    __weak __auto_type weakSelf = self;
    self.installationIDObserver = [[NSNotificationCenter defaultCenter]
        addObserverForName:FIRInstallationIDDidChangeNotification
                    object:nil
                     queue:nil
                usingBlock:^(NSNotification *_Nonnull notification) {
                  [weakSelf sendNewInstallationId];
                }];

    // The part related to installation ID is not specific to FCM, that's why it
    // was moved above.
    if (!self.isFCMEnabled) {
      return;
    }

    // Parse JSON
    NSString *path = [[NSBundle mainBundle] pathForResource:@"pn-actions"
                                                     ofType:@"json"];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data == nil)
      return;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data
                                                         options:kNilOptions
                                                           error:nil];

    // Assign actions for categories
    NSMutableSet *categories = [[NSMutableSet alloc] init];
    NSArray *actionsArray = [dict objectForKey:@"PushNotificationActions"];
    for (NSDictionary *item in actionsArray) {
      NSMutableArray *buttons = [NSMutableArray new];
      NSString *category = [item objectForKey:@"category"];

      NSArray *actions = [item objectForKey:@"actions"];
      for (NSDictionary *action in actions) {
        NSString *actionId = [action objectForKey:@"id"];
        NSString *actionTitle = [action objectForKey:@"title"];
        UNNotificationActionOptions options = UNNotificationActionOptionNone;

        id mode = [action objectForKey:@"foreground"];
        if (mode != nil && (([mode isKindOfClass:[NSString class]] &&
                             [mode isEqualToString:@"true"]) ||
                            [mode boolValue])) {
          options |= UNNotificationActionOptionForeground;
        }
        id destructive = [action objectForKey:@"destructive"];
        if (destructive != nil &&
            (([destructive isKindOfClass:[NSString class]] &&
              [destructive isEqualToString:@"true"]) ||
             [destructive boolValue])) {
          options |= UNNotificationActionOptionDestructive;
        }

        [buttons addObject:[UNNotificationAction
                               actionWithIdentifier:actionId
                                              title:NSLocalizedString(
                                                        actionTitle, nil)
                                            options:options]];
      }

      [categories
          addObject:
              [UNNotificationCategory
                  categoryWithIdentifier:category
                                 actions:buttons
                       intentIdentifiers:@[]
                                 options:UNNotificationCategoryOptionNone]];
    }

    // Initialize categories
    [[UNUserNotificationCenter currentNotificationCenter]
        setNotificationCategories:categories];

  } @catch (NSException *exception) {
    [self handlePluginExceptionWithoutContext:exception];
  }
}

// @override abstract
/**
 * Handles incoming URLs for the application.
 * Used for Google Sign-In and other OAuth flows.
 *
 * @param notification The notification containing the URL.
 */
- (void)handleOpenURL:(NSNotification *)notification {
  NSURL *url = [notification object];
  [GIDSignIn.sharedInstance handleURL:url];
}

/*************************************************/
#pragma mark - plugin API
/*************************************************/
/**
 * Implementation for the 'setAutoInitEnabled' action.
 * Enables or disables automatic initialization of Firebase FCM.
 *
 * @param command The Cordova command object.
 */
- (void)setAutoInitEnabled:(CDVInvokedUrlCommand *)command {
  @try {
    bool enabled = [[command.arguments objectAtIndex:0] boolValue];
    [self runOnMainThread:^{
      @try {
        [FIRMessaging messaging].autoInitEnabled = enabled;

        CDVPluginResult *pluginResult =
            [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult
                                    callbackId:command.callbackId];
      } @catch (NSException *exception) {
        [self handlePluginExceptionWithContext:exception:command];
      }
    }];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'isAutoInitEnabled' action.
 * Checks if automatic initialization of Firebase FCM is enabled.
 *
 * @param command The Cordova command object.
 */
- (void)isAutoInitEnabled:(CDVInvokedUrlCommand *)command {
  @try {

    [self runOnMainThread:^{
      @try {
        bool enabled = [FIRMessaging messaging].isAutoInitEnabled;

        CDVPluginResult *commandResult =
            [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                messageAsBool:enabled];
        [self.commandDelegate sendPluginResult:commandResult
                                    callbackId:command.callbackId];
      } @catch (NSException *exception) {
        [self handlePluginExceptionWithContext:exception:command];
      }
    }];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/*
 * Remote notifications
 */

/**
 * Implementation for the 'getId' action.
 * Alias for getInstallationId.
 *
 * @param command The Cordova command object.
 */
- (void)getId:(CDVInvokedUrlCommand *)command {
  [self getInstallationId:command];
}

/**
 * Implementation for the 'getToken' action.
 * Retrieves the current FCM registration token.
 *
 * @param command The Cordova command object.
 */
- (void)getToken:(CDVInvokedUrlCommand *)command {
  [self _getToken:^(NSString *token, NSError *error) {
    [self handleStringResultWithPotentialError:error
                                       command:command
                                        result:token];
  }];
}

/**
 * Internal helper to retrieve the FCM token.
 *
 * @param completeBlock Completion block with the token and error.
 */
- (void)_getToken:(void (^)(NSString *token, NSError *error))completeBlock {
  @try {
    [[FIRMessaging messaging]
        tokenWithCompletion:^(NSString *token, NSError *error) {
          @try {
            completeBlock(token, error);
          } @catch (NSException *exception) {
            [self handlePluginExceptionWithoutContext:exception];
          }
        }];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithoutContext:exception];
  }
}

/**
 * Implementation for the 'getAPNSToken' action.
 * Retrieves the underlying APNS device token.
 *
 * @param command The Cordova command object.
 */
- (void)getAPNSToken:(CDVInvokedUrlCommand *)command {
  CDVPluginResult *pluginResult =
      [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                        messageAsString:[self getAPNSToken]];
  [self.commandDelegate sendPluginResult:pluginResult
                              callbackId:command.callbackId];
}

/**
 * Internal method to retrieve the APNS device token as a hex string.
 *
 * @return The hex string token.
 */
- (NSString *)getAPNSToken {
  NSString *hexToken = nil;
  NSData *apnsToken = [FIRMessaging messaging].APNSToken;
  if (apnsToken) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
    // [deviceToken description] Starting with iOS 13 device token is like
    // "{length = 32, bytes = 0xd3d997af 967d1f43 b405374a 13394d2f ... 28f10282
    // 14af515f }"
    hexToken = [self hexadecimalStringFromData:apnsToken];
#else
    hexToken = [[apnsToken.description
        componentsSeparatedByCharactersInSet:[[NSCharacterSet
                                                 alphanumericCharacterSet]
                                                 invertedSet]]
        componentsJoinedByString:@""];
#endif
  }
  return hexToken;
}

/**
 * Convers binary data to a hexadecimal string representation.
 *
 * @param data The source NSData.
 * @return A hexadecimal string.
 */
- (NSString *)hexadecimalStringFromData:(NSData *)data {
  NSUInteger dataLength = data.length;
  if (dataLength == 0) {
    return nil;
  }

  const unsigned char *dataBuffer = data.bytes;
  NSMutableString *hexString =
      [NSMutableString stringWithCapacity:(dataLength * 2)];
  for (int i = 0; i < dataLength; ++i) {
    [hexString appendFormat:@"%02x", dataBuffer[i]];
  }
  return [hexString copy];
}

/**
 * Implementation for the 'hasPermission' action.
 * Checks if the user has granted permission for notifications.
 *
 * @param command The Cordova command object.
 */
- (void)hasPermission:(CDVInvokedUrlCommand *)command {
  @try {
    [self _hasPermission:^(BOOL enabled) {
      CDVPluginResult *commandResult =
          [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                              messageAsBool:enabled];
      [self.commandDelegate sendPluginResult:commandResult
                                  callbackId:command.callbackId];
    }];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Internal method to check notification permission status.
 *
 * @param completeBlock Completion block with simple BOOL result.
 */
- (void)_hasPermission:(void (^)(BOOL result))completeBlock {
  @try {
    [[UNUserNotificationCenter currentNotificationCenter]
        getNotificationSettingsWithCompletionHandler:^(
            UNNotificationSettings *_Nonnull settings) {
          @try {
            BOOL enabled = NO;
            if (settings.alertSetting == UNNotificationSettingEnabled) {
              enabled = YES;
              [self registerForRemoteNotifications];
            }
            NSLog(@"_hasPermission: %@", enabled ? @"YES" : @"NO");
            completeBlock(enabled);
          } @catch (NSException *exception) {
            [self handlePluginExceptionWithoutContext:exception];
          }
        }];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithoutContext:exception];
  }
}

/**
 * Implementation for the 'grantPermission' action.
 * Requests permission for notifications from the user.
 *
 * @param command The Cordova command object.
 */
- (void)grantPermission:(CDVInvokedUrlCommand *)command {
  NSLog(@"grantPermission");
  @try {
    [self _hasPermission:^(BOOL enabled) {
      @try {
        if (enabled) {
          NSString *message =
              @"Permission is already granted - call hasPermission() to check "
              @"before calling grantPermission()";
          CDVPluginResult *pluginResult =
              [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                messageAsString:message];
          [self.commandDelegate sendPluginResult:pluginResult
                                      callbackId:command.callbackId];
        } else {
          [UNUserNotificationCenter currentNotificationCenter].delegate =
              (id<UNUserNotificationCenterDelegate> _Nullable)self;
          BOOL requestWithProvidesAppNotificationSettings =
              [[command argumentAtIndex:0] boolValue];
          UNAuthorizationOptions authOptions = UNAuthorizationOptionAlert |
                                               UNAuthorizationOptionSound |
                                               UNAuthorizationOptionBadge;
          if (@available(iOS 12.0, *)) {
            if (requestWithProvidesAppNotificationSettings) {
              authOptions =
                  authOptions |
                  UNAuthorizationOptionProvidesAppNotificationSettings;
            }
          }

          [[UNUserNotificationCenter currentNotificationCenter]
              requestAuthorizationWithOptions:authOptions
                            completionHandler:^(BOOL granted,
                                                NSError *_Nullable error) {
                              @try {
                                NSLog(@"requestAuthorizationWithOptions: "
                                      @"granted=%@",
                                      granted ? @"YES" : @"NO");
                                if (error == nil && granted) {
                                  [UNUserNotificationCenter
                                      currentNotificationCenter]
                                      .delegate = AppDelegate.instance;
                                  [self registerForRemoteNotifications];
                                }
                                [self
                                    handleBoolResultWithPotentialError:error
                                                               command:command
                                                                result:granted];

                              } @catch (NSException *exception) {
                                [self handlePluginExceptionWithContext:
                                                             exception:command];
                              }
                            }];
        }
      } @catch (NSException *exception) {
        [self handlePluginExceptionWithContext:exception:command];
      }
    }];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'hasCriticalPermission' action.
 *
 * @param command The Cordova command object.
 */
- (void)hasCriticalPermission:(CDVInvokedUrlCommand *)command {
  @try {
    [self _hasCriticalPermission:^(BOOL enabled) {
      CDVPluginResult *commandResult =
          [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                              messageAsBool:enabled];
      [self.commandDelegate sendPluginResult:commandResult
                                  callbackId:command.callbackId];
    }];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Internal helper to check critical alert permissions.
 *
 * @param completeBlock Completion block with the boolean result.
 */
- (void)_hasCriticalPermission:(void (^)(BOOL result))completeBlock {
  @try {
    if (@available(iOS 12.0, *)) {
      [[UNUserNotificationCenter currentNotificationCenter]
          getNotificationSettingsWithCompletionHandler:^(
              UNNotificationSettings *_Nonnull settings) {
            @try {
              BOOL enabled = NO;
              if (settings.criticalAlertSetting ==
                  UNNotificationSettingEnabled) {
                enabled = YES;
                [self registerForRemoteNotifications];
              }
              NSLog(@"_hasCriticalPermission: %@", enabled ? @"YES" : @"NO");
              completeBlock(enabled);
            } @catch (NSException *exception) {
              [self handlePluginExceptionWithoutContext:exception];
            }
          }];
    } else {
      completeBlock(NO);
    }
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithoutContext:exception];
  }
}

/**
 * Implementation for the 'grantCriticalPermission' action.
 *
 * @param command The Cordova command object.
 */
- (void)grantCriticalPermission:(CDVInvokedUrlCommand *)command {
  NSLog(@"grantCriticalPermission");
  @try {
    if (@available(iOS 12.0, *)) {
      [self _hasCriticalPermission:^(BOOL enabled) {
        @try {
          if (enabled) {
            NSString *message = @"Critical permission is already granted - "
                                @"call hasCriticalPermission() to check before "
                                @"calling grantCriticalPermission()";
            CDVPluginResult *pluginResult =
                [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                  messageAsString:message];
            [self.commandDelegate sendPluginResult:pluginResult
                                        callbackId:command.callbackId];
          } else {
            [UNUserNotificationCenter currentNotificationCenter].delegate =
                (id<UNUserNotificationCenterDelegate> _Nullable)self;
            UNAuthorizationOptions authOptions =
                UNAuthorizationOptionCriticalAlert;

            [[UNUserNotificationCenter currentNotificationCenter]
                requestAuthorizationWithOptions:authOptions
                              completionHandler:^(BOOL granted,
                                                  NSError *_Nullable error) {
                                @try {
                                  NSLog(@"requestAuthorizationWithOptions: "
                                        @"granted=%@",
                                        granted ? @"YES" : @"NO");
                                  [self
                                      handleBoolResultWithPotentialError:error
                                                                 command:command
                                                                  result:
                                                                      granted];
                                } @catch (NSException *exception) {
                                  [self
                                      handlePluginExceptionWithContext:
                                                             exception:command];
                                }
                              }];
          }
        } @catch (NSException *exception) {
          [self handlePluginExceptionWithContext:exception:command];
        }
      }];
    } else {
      [self handleBoolResultWithPotentialError:nil
                                       command:command
                                        result:false];
    }
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Registers the application for remote notifications.
 * Ensures the system registration call is made.
 */
- (void)registerForRemoteNotifications {
  NSLog(@"registerForRemoteNotifications");

  if (registeredForRemoteNotifications)
    return;

  [self runOnMainThread:^{
    @try {
      [[UIApplication sharedApplication] registerForRemoteNotifications];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithoutContext:exception];
    }
    registeredForRemoteNotifications = YES;
  }];
}

- (void)setBadgeNumber:(CDVInvokedUrlCommand *)command {
  @try {
    int number = [[command.arguments objectAtIndex:0] intValue];
    [self runOnMainThread:^{
      @try {
        [[UIApplication sharedApplication]
            setApplicationIconBadgeNumber:number];
        CDVPluginResult *pluginResult =
            [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult
                                    callbackId:command.callbackId];
      } @catch (NSException *exception) {
        [self handlePluginExceptionWithContext:exception:command];
      }
    }];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'getBadgeNumber' action.
 *
 * @param command The Cordova command object.
 */
- (void)getBadgeNumber:(CDVInvokedUrlCommand *)command {
  [self runOnMainThread:^{
    @try {
      long badge =
          [[UIApplication sharedApplication] applicationIconBadgeNumber];

      CDVPluginResult *pluginResult =
          [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                            messageAsDouble:badge];
      [self.commandDelegate sendPluginResult:pluginResult
                                  callbackId:command.callbackId];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Implementation for the 'subscribe' action.
 * Subscribes the device to an FCM topic.
 *
 * @param command The Cordova command object.
 */
- (void)subscribe:(CDVInvokedUrlCommand *)command {
  @try {
    NSString *topic =
        [NSString stringWithFormat:@"%@", [command.arguments objectAtIndex:0]];

    [[FIRMessaging messaging]
        subscribeToTopic:topic
              completion:^(NSError *_Nullable error) {
                [self handleEmptyResultWithPotentialError:error
                                                  command:command];
              }];

    CDVPluginResult *pluginResult =
        [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:command.callbackId];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'unsubscribe' action.
 *
 * @param command The Cordova command object.
 */
- (void)unsubscribe:(CDVInvokedUrlCommand *)command {
  @try {
    NSString *topic =
        [NSString stringWithFormat:@"%@", [command.arguments objectAtIndex:0]];

    [[FIRMessaging messaging]
        unsubscribeFromTopic:topic
                  completion:^(NSError *_Nullable error) {
                    [self handleEmptyResultWithPotentialError:error
                                                      command:command];
                  }];

    CDVPluginResult *pluginResult =
        [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:command.callbackId];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'unregister' action.
 * Deletes the FCM registration token for the app.
 *
 * @param command The Cordova command object.
 */
- (void)unregister:(CDVInvokedUrlCommand *)command {
  @try {
    __block NSError *error = nil;
    [[FIRMessaging messaging]
        deleteTokenWithCompletion:^(NSError *_Nullable deleteTokenError) {
          if (error == nil && deleteTokenError != nil)
            error = deleteTokenError;
          if ([FIRMessaging messaging].isAutoInitEnabled) {
            [self _getToken:^(NSString *token, NSError *getError) {
              if (error == nil && getError != nil)
                error = getError;
              [self handleEmptyResultWithPotentialError:error command:command];
            }];
          } else {
            [self handleEmptyResultWithPotentialError:error command:command];
          }
        }];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'onOpenSettings' action.
 * Registers a callback for when notification settings are opened.
 *
 * @param command The Cordova command object.
 */
- (void)onOpenSettings:(CDVInvokedUrlCommand *)command {
  @try {
    self.openSettingsCallbackId = command.callbackId;

    if (openSettingsEmitted == YES) {
      [self sendPluginSuccessAndKeepCallback:self.openSettingsCallbackId];
      openSettingsEmitted = NO;
    }
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'onMessageReceived' action.
 * Registers a callback for when a remote notification is received.
 *
 * @param command The Cordova command object.
 */
- (void)onMessageReceived:(CDVInvokedUrlCommand *)command {
  self.notificationCallbackId = command.callbackId;
  [self sendPendingNotifications];
}

/**
 * Internal method to send any stacked notifications to the webview.
 */
- (void)sendPendingNotifications {
  if (self.notificationCallbackId != nil && self.notificationStack != nil &&
      [self.notificationStack count]) {
    @try {
      for (NSDictionary *userInfo in self.notificationStack) {
        [self sendNotification:userInfo];
      }
      [self.notificationStack removeAllObjects];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithoutContext:exception];
    }
  }
}

/**
 * Implementation for the 'onTokenRefresh' action.
 * Registers a callback for when the FCM token changes.
 *
 * @param command The Cordova command object.
 */
- (void)onTokenRefresh:(CDVInvokedUrlCommand *)command {
  self.tokenRefreshCallbackId = command.callbackId;
  NSString *apnsToken = [self getAPNSToken];
  if (apnsToken != nil) {
    [self _getToken:^(NSString *token, NSError *error) {
      if (error == nil && token != nil) {
        [self sendToken:token];
      }
    }];
  }
}

/**
 * Implementation for the 'onApnsTokenReceived' action.
 * Registers a callback for when the APNS token is received.
 *
 * @param command The Cordova command object.
 */
- (void)onApnsTokenReceived:(CDVInvokedUrlCommand *)command {
  self.apnsTokenRefreshCallbackId = command.callbackId;
  @try {
    NSString *apnsToken = [self getAPNSToken];
    if (apnsToken != nil) {
      [self sendApnsToken:apnsToken];
    }
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Internal method to notify the webview that notification settings were opened.
 */
- (void)sendOpenNotificationSettings {
  @try {
    if (self.openSettingsCallbackId != nil) {
      [self sendPluginSuccessAndKeepCallback:self.openSettingsCallbackId];
    } else if (openSettingsEmitted != YES) {
      openSettingsEmitted = YES;
    }
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:self.commandDelegate];
  }
}

/**
 * Internal method to send a notification payload to the webview.
 *
 * @param userInfo The notification data dictionary.
 */
- (void)sendNotification:(NSDictionary *)userInfo {
  @try {
    if ([FirebasePluginMessageReceiverManager sendNotification:userInfo]) {
      [self _logMessage:@"Message handled by custom receiver"];
      return;
    }
    if (self.notificationCallbackId != nil &&
        ([AppDelegate.instance.applicationInBackground isEqual:@(NO)] ||
         immediateMessagePayloadDelivery)) {
      [self sendPluginDictionaryResultAndKeepCallback:userInfo
                                              command:self.commandDelegate
                                           callbackId:
                                               self.notificationCallbackId];
    } else {
      if (!self.notificationStack) {
        self.notificationStack = [[NSMutableArray alloc] init];
      }

      // stack notifications until a callback has been registered
      [self.notificationStack addObject:userInfo];

      if ([self.notificationStack count] >= kNotificationStackSize) {
        [self.notificationStack removeLastObject];
      }
    }
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:self.commandDelegate];
  }
}

/**
 * Internal method to send a new FCM token to the webview.
 *
 * @param token The FCM token string.
 */
- (void)sendToken:(NSString *)token {
  @try {
    if (self.tokenRefreshCallbackId != nil) {
      [self sendPluginStringResultAndKeepCallback:token
                                          command:self.commandDelegate
                                       callbackId:self.tokenRefreshCallbackId];
    }
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:self.commandDelegate];
  }
}

/**
 * Internal method to send a new APNS token to the webview.
 *
 * @param token The APNS token string.
 */
- (void)sendApnsToken:(NSString *)token {
  @try {
    if (self.apnsTokenRefreshCallbackId != nil) {
      [self sendPluginStringResultAndKeepCallback:token
                                          command:self.commandDelegate
                                       callbackId:
                                           self.apnsTokenRefreshCallbackId];
    }
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:self.commandDelegate];
  }
}

/**
 * Implementation for the 'clearAllNotifications' action.
 * Clears all notifications from the notification center and resets the badge
 * count.
 *
 * @param command The Cordova command object.
 */
- (void)clearAllNotifications:(CDVInvokedUrlCommand *)command {
  [self runOnMainThread:^{
    @try {
      [[UIApplication sharedApplication] setApplicationIconBadgeNumber:1];
      [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];

      CDVPluginResult *pluginResult =
          [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
      [self.commandDelegate sendPluginResult:pluginResult
                                  callbackId:command.callbackId];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/*
 * Authentication
 */
/**
 * Implementation for the 'verifyPhoneNumber' action.
 * Starts the phone number verification flow by sending an SMS.
 *
 * @param command The active Cordova command.
 */
- (void)verifyPhoneNumber:(CDVInvokedUrlCommand *)command {
  NSString *number = [command.arguments objectAtIndex:0];

  @try {
    [[FIRPhoneAuthProvider provider]
        verifyPhoneNumber:number
               UIDelegate:nil
               completion:^(NSString *_Nullable verificationID,
                            NSError *_Nullable error) {
                 @try {
                   CDVPluginResult *pluginResult;
                   if (error) {
                     // Verification code not sent.
                     pluginResult = [CDVPluginResult
                         resultWithStatus:CDVCommandStatus_ERROR
                          messageAsString:error.description];
                   } else {
                     // Successful.
                     NSMutableDictionary *result =
                         [[NSMutableDictionary alloc] init];
                     [result setValue:@"false" forKey:@"instantVerification"];
                     [result setValue:verificationID forKey:@"verificationId"];
                     pluginResult =
                         [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                       messageAsDictionary:result];
                   }
                   [self.commandDelegate sendPluginResult:pluginResult
                                               callbackId:command.callbackId];
                 } @catch (NSException *exception) {
                   [self handlePluginExceptionWithContext:exception:command];
                 }
               }];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'enrollSecondAuthFactor' action.
 * Enrolls a second factor (like SMS) for the current user.
 *
 * @param command The active Cordova command.
 */
- (void)enrollSecondAuthFactor:(CDVInvokedUrlCommand *)command {
  @try {
    if ([self userNotSignedInError:command])
      return;
    FIRUser *user = [FIRAuth auth].currentUser;

    NSString *phoneNumber = [command.arguments objectAtIndex:0];
    NSDictionary *opts = [command.arguments objectAtIndex:1];

    NSString *displayName = [opts objectForKey:@"displayName"];

    NSString *verificationId = nil;
    NSString *verificationCode = nil;
    if ([opts objectForKey:@"credential"] != nil) {
      NSDictionary *credential = [opts objectForKey:@"credential"];
      if ([credential objectForKey:@"verificationId"] != nil &&
          [credential objectForKey:@"code"] != nil) {
        verificationId = [credential objectForKey:@"verificationId"];
        verificationCode = [credential objectForKey:@"code"];
      } else {
        [self sendPluginErrorWithMessage:
                  @"'verificationId' and/or 'code' properties not found on "
                   @"'credential' object":command];
        return;
      }
    }

    [user.multiFactor getSessionWithCompletion:^(
                          FIRMultiFactorSession *_Nullable session,
                          NSError *_Nullable error) {
      @try {
        if (error != nil)
          return [self sendPluginErrorWithError:error command:command];

        // If credential specifying verification ID and code has been provided
        if (verificationId != nil && verificationCode != nil) {
          // Use them to enroll
          FIRPhoneAuthCredential *credential = [FIRPhoneAuthProvider.provider
              credentialWithVerificationID:verificationId
                          verificationCode:verificationCode];
          FIRMultiFactorAssertion *assertion =
              [FIRPhoneMultiFactorGenerator assertionWithCredential:credential];

          // Complete enrollment. This will update the underlying tokens
          // and trigger ID token change listener.
          [user.multiFactor
              enrollWithAssertion:assertion
                      displayName:displayName
                       completion:^(NSError *_Nullable error) {
                         @try {
                           if (error != nil)
                             return [self sendPluginErrorWithError:error
                                                           command:command];
                           [self sendPluginBoolResult:true
                                              command:command
                                           callbackId:command.callbackId];
                         } @catch (NSException *exception) {
                           [self handlePluginExceptionWithContext:
                                                        exception:command];
                         }
                       }];
        } else {
          // Send SMS verification code.
          [FIRPhoneAuthProvider.provider
               verifyPhoneNumber:phoneNumber
                      UIDelegate:nil
              multiFactorSession:session
                      completion:^(NSString *_Nullable verificationID,
                                   NSError *_Nullable error) {
                        @try {
                          if (error != nil)
                            return [self sendPluginErrorWithError:error
                                                          command:command];

                          NSMutableDictionary *result =
                              [[NSMutableDictionary alloc] init];
                          [result setValue:verificationID
                                    forKey:@"verificationId"];
                          [self sendPluginDictionaryResult:result
                                                   command:command
                                                callbackId:command.callbackId];
                        } @catch (NSException *exception) {
                          [self handlePluginExceptionWithContext:
                                                       exception:command];
                        }
                      }];
        }
      } @catch (NSException *exception) {
        [self handlePluginExceptionWithContext:exception:command];
      }
    }];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'verifySecondAuthFactor' action.
 * Resolves a multi-factor challenge.
 *
 * @param command The active Cordova command.
 */
- (void)verifySecondAuthFactor:(CDVInvokedUrlCommand *)command {
  @try {
    if (multiFactorResolver == nil) {
      [self sendPluginErrorWithMessage:
          @"No multi-factor challenge exists to resolve":command];
      return;
    }

    NSDictionary *params = [command.arguments objectAtIndex:0];

    int selectedIndex = -1;
    if ([params objectForKey:@"selectedIndex"] != nil) {
      selectedIndex = [[params objectForKey:@"selectedIndex"] intValue];
      if (selectedIndex < 0) {
        [self
            sendPluginErrorWithMessage:
                [NSString
                    stringWithFormat:
                        @"Selected index value (%d) must be a positive integer",
                        selectedIndex
        ]:command];
        return;
      }
      if (selectedIndex + 1 > multiFactorResolver.hints.count) {
        [self sendPluginErrorWithMessage:
                  [NSString
                      stringWithFormat:@"Selected index value (%d) exceeds the "
                                       @"number of enrolled factors (%d)",
                                       selectedIndex,
                                       (int)multiFactorResolver.hints.count
        ]:command];
        return;
      }
    }

    NSString *verificationId = nil;
    NSString *verificationCode = nil;
    if ([params objectForKey:@"credential"] != nil) {
      NSDictionary *credential = [params objectForKey:@"credential"];
      if ([credential objectForKey:@"verificationId"] != nil &&
          [credential objectForKey:@"code"] != nil) {
        verificationId = [credential objectForKey:@"verificationId"];
        verificationCode = [credential objectForKey:@"code"];
      } else {
        [self sendPluginErrorWithMessage:
                  @"'verificationId' and/or 'code' properties not found on "
                   @"'credential' object":command];
        return;
      }
    }

    if (selectedIndex == -1 && verificationId == nil) {
      [self sendPluginErrorWithMessage:
                @"Neither 'selectedIndex' or 'credential' properties found on "
                 @"'params' object - either one must be specified":command];
      return;
    }

    // Arguments contain ID & code from manual SMS verification, so use this for
    // verification
    if (verificationId != nil && verificationCode != nil) {
      FIRPhoneAuthCredential *credential = [FIRPhoneAuthProvider.provider
          credentialWithVerificationID:verificationId
                      verificationCode:verificationCode];
      FIRMultiFactorAssertion *assertion =
          [FIRPhoneMultiFactorGenerator assertionWithCredential:credential];

      [multiFactorResolver
          resolveSignInWithAssertion:assertion
                          completion:^(FIRAuthDataResult *_Nullable authResult,
                                       NSError *_Nullable error) {
                            @try {
                              [self handleAuthResult:authResult
                                               error:error
                                             command:command];
                            } @catch (NSException *exception) {
                              [self handlePluginExceptionWithContext:
                                                           exception:command];
                            }
                          }];
    } else {
      // Send SMS verification code.
      FIRPhoneMultiFactorInfo *hint =
          (FIRPhoneMultiFactorInfo *)multiFactorResolver.hints[selectedIndex];

      [FIRPhoneAuthProvider.provider
          verifyPhoneNumberWithMultiFactorInfo:hint
                                    UIDelegate:nil
                            multiFactorSession:multiFactorResolver.session
                                    completion:^(
                                        NSString *_Nullable verificationID,
                                        NSError *_Nullable error) {
                                      @try {
                                        if (error != nil)
                                          return [self
                                              sendPluginErrorWithError:error
                                                               command:command];

                                        NSMutableDictionary *result =
                                            [[NSMutableDictionary alloc] init];
                                        [result setValue:verificationID
                                                  forKey:@"verificationId"];
                                        [self
                                            sendPluginDictionaryResult:result
                                                               command:command
                                                            callbackId:
                                                                command
                                                                    .callbackId];
                                      } @catch (NSException *exception) {
                                        [self
                                            handlePluginExceptionWithContext:
                                                                   exception:
                                                                       command];
                                      }
                                    }];
    }

  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'listEnrolledSecondAuthFactors' action.
 * Returns a list of enrolled second factors for the current user.
 *
 * @param command The active Cordova command.
 */
- (void)listEnrolledSecondAuthFactors:(CDVInvokedUrlCommand *)command {
  @try {
    if ([self userNotSignedInError:command])
      return;
    FIRUser *user = [FIRAuth auth].currentUser;
    NSMutableArray *secondFactors = [self
        parseEnrolledSecondFactorsToJson:[[user multiFactor] enrolledFactors]];
    [self sendPluginArrayResult:secondFactors
                        command:command
                     callbackId:command.callbackId];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'unenrollSecondAuthFactor' action.
 * Removes an enrolled second factor from the current user account.
 *
 * @param command The active Cordova command.
 */
- (void)unenrollSecondAuthFactor:(CDVInvokedUrlCommand *)command {
  @try {
    if ([self userNotSignedInError:command])
      return;
    FIRUser *user = [FIRAuth auth].currentUser;

    int selectedIndex = [[command.arguments objectAtIndex:0] intValue];
    if (selectedIndex < 0) {
      [self sendPluginErrorWithMessage:
                [NSString
                    stringWithFormat:
                        @"Selected index value (%d) must be a positive integer",
                        selectedIndex
      ]:command];
      return;
    }

    NSArray *secondFactors = [[user multiFactor] enrolledFactors];
    if (selectedIndex + 1 > secondFactors.count) {
      [self
          sendPluginErrorWithMessage:
              [NSString stringWithFormat:@"Selected index value (%d) exceeds "
                                         @"the number of enrolled factors (%d)",
                                         selectedIndex, (int)secondFactors.count
      ]:command];
      return;
    }

    [[user multiFactor]
        unenrollWithInfo:[secondFactors objectAtIndex:selectedIndex]
              completion:^(NSError *_Nullable error) {
                @try {
                  [self handleEmptyResultWithPotentialError:error
                                                    command:command];
                } @catch (NSException *exception) {
                  [self handlePluginExceptionWithContext:exception:command];
                }
              }];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Internal helper to convert an array of MFA info objects into a
 * JSON-compatible format.
 *
 * @param multiFactorInfos Array of FIRMultiFactorInfo.
 * @return A mutable array of dictionaries.
 */
- (NSMutableArray *)parseEnrolledSecondFactorsToJson:
    (NSArray *)multiFactorInfos {
  NSMutableArray *secondFactors = [NSMutableArray new];
  int index = 0;
  for (FIRMultiFactorInfo *multiFactorInfo in multiFactorInfos) {
    NSMutableDictionary *secondFactor = [[NSMutableDictionary alloc] init];
    [secondFactor setValue:[NSNumber numberWithInt:index] forKey:@"index"];
    if (multiFactorInfo.displayName != nil) {
      [secondFactor setValue:multiFactorInfo.displayName forKey:@"displayName"];
    }

    FIRPhoneMultiFactorInfo *phoneMultiFactorInfo =
        (FIRPhoneMultiFactorInfo *)multiFactorInfo;
    if ([phoneMultiFactorInfo respondsToSelector:@selector(phoneNumber)]) {
      [secondFactor setValue:phoneMultiFactorInfo.phoneNumber
                      forKey:@"phoneNumber"];
    }
    [secondFactors addObject:secondFactor];
    index++;
  }
  return secondFactors;
}

/**
 * Implementation for the 'setLanguageCode' action.
 * Sets the language code for Firebase Auth operations (e.g. email templates).
 *
 * @param command The active Cordova command.
 */
- (void)setLanguageCode:(CDVInvokedUrlCommand *)command {
  NSString *lang = [command.arguments objectAtIndex:0];
  @try {
    [FIRAuth auth].languageCode = lang;
    NSLog(@"Language code set to %@!", lang);
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'createUserWithEmailAndPassword' action.
 * Creates a new user account with the specified email and password.
 *
 * @param command The active Cordova command.
 */
- (void)createUserWithEmailAndPassword:(CDVInvokedUrlCommand *)command {
  @try {
    NSString *email = [command.arguments objectAtIndex:0];
    NSString *password = [command.arguments objectAtIndex:1];
    [[FIRAuth auth]
        createUserWithEmail:email
                   password:password
                 completion:^(FIRAuthDataResult *_Nullable authResult,
                              NSError *_Nullable error) {
                   @try {
                     [self handleAuthResult:authResult
                                      error:error
                                    command:command];
                   } @catch (NSException *exception) {
                     [self handlePluginExceptionWithContext:exception:command];
                   }
                 }];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'signInUserWithEmailAndPassword' action.
 * Signs in a user with the specified email and password.
 *
 * @param command The active Cordova command.
 */
- (void)signInUserWithEmailAndPassword:(CDVInvokedUrlCommand *)command {
  @try {
    NSString *email = [command.arguments objectAtIndex:0];
    NSString *password = [command.arguments objectAtIndex:1];
    [[FIRAuth auth]
        signInWithEmail:email
               password:password
             completion:^(FIRAuthDataResult *_Nullable authResult,
                          NSError *_Nullable error) {
               @try {
                 [self handleAuthResult:authResult error:error command:command];
               } @catch (NSException *exception) {
                 [self handlePluginExceptionWithContext:exception:command];
               }
             }];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'authenticateUserWithEmailAndPassword' action.
 * Returns an auth credential that can be used for sign-in or linking later.
 *
 * @param command The active Cordova command.
 */
- (void)authenticateUserWithEmailAndPassword:(CDVInvokedUrlCommand *)command {
  @try {
    NSString *email = [command.arguments objectAtIndex:0];
    NSString *password = [command.arguments objectAtIndex:1];
    FIRAuthCredential *authCredential =
        [FIREmailAuthProvider credentialWithEmail:email password:password];
    NSNumber *key = [self saveAuthCredential:authCredential];

    NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
    [result setValue:@"true" forKey:@"instantVerification"];
    [result setValue:key forKey:@"id"];
    CDVPluginResult *pluginResult =
        [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                      messageAsDictionary:result];
    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:command.callbackId];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'signInUserWithCustomToken' action.
 * Signs in a user using a custom server-generated token.
 *
 * @param command The active Cordova command.
 */
- (void)signInUserWithCustomToken:(CDVInvokedUrlCommand *)command {
  @try {
    NSString *customToken = [command.arguments objectAtIndex:0];
    [[FIRAuth auth]
        signInWithCustomToken:customToken
                   completion:^(FIRAuthDataResult *_Nullable authResult,
                                NSError *_Nullable error) {
                     @try {
                       [self handleAuthResult:authResult
                                        error:error
                                      command:command];
                     } @catch (NSException *exception) {
                       [self handlePluginExceptionWithContext:
                                                    exception:command];
                     }
                   }];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'signInUserAnonymously' action.
 * Signs in a user anonymously.
 *
 * @param command The active Cordova command.
 */
- (void)signInUserAnonymously:(CDVInvokedUrlCommand *)command {
  @try {
    [[FIRAuth auth]
        signInAnonymouslyWithCompletion:^(
            FIRAuthDataResult *_Nullable authResult, NSError *_Nullable error) {
          @try {
            [self handleAuthResult:authResult error:error command:command];
          } @catch (NSException *exception) {
            [self handlePluginExceptionWithContext:exception:command];
          }
        }];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'authenticateUserWithGoogle' action.
 * Performs Google Sign-In and returns a reusable auth credential.
 *
 * @param command The active Cordova command.
 */
- (void)authenticateUserWithGoogle:(CDVInvokedUrlCommand *)command {
  @try {
    __weak __auto_type weakSelf = self;
    GIDConfiguration *googleSignInConfig = [[GIDConfiguration alloc]
        initWithClientID:[FIRApp defaultApp].options.clientID];
    GIDSignIn.sharedInstance.configuration = googleSignInConfig;
    [GIDSignIn.sharedInstance
        signInWithPresentingViewController:self.viewController
                                completion:^(
                                    GIDSignInResult *_Nullable signInResult,
                                    NSError *_Nullable error) {
                                  __auto_type strongSelf = weakSelf;
                                  if (strongSelf == nil) {
                                    return;
                                  }

                                  @try {
                                    CDVPluginResult *pluginResult;
                                    if (error == nil) {
                                      GIDGoogleUser *gidUser =
                                          signInResult.user;
                                      FIRAuthCredential *credential =
                                          [FIRGoogleAuthProvider
                                              credentialWithIDToken:
                                                  gidUser.idToken.tokenString
                                                        accessToken:
                                                            gidUser.accessToken
                                                                .tokenString];

                                      NSNumber *key =
                                          [[FirebasePlugin firebasePlugin]
                                              saveAuthCredential:credential];
                                      NSString *idToken =
                                          gidUser.idToken.tokenString;
                                      NSMutableDictionary *result =
                                          [[NSMutableDictionary alloc] init];
                                      [result setValue:@"true"
                                                forKey:@"instantVerification"];
                                      [result setValue:key forKey:@"id"];
                                      [result setValue:idToken
                                                forKey:@"idToken"];
                                      pluginResult = [CDVPluginResult
                                             resultWithStatus:
                                                 CDVCommandStatus_OK
                                          messageAsDictionary:result];
                                    } else {
                                      pluginResult =
                                          [self createAuthErrorResult:error];
                                    }
                                    [[FirebasePlugin firebasePlugin]
                                            .commandDelegate
                                        sendPluginResult:pluginResult
                                              callbackId:command.callbackId];
                                  } @catch (NSException *exception) {
                                    [FirebasePlugin.firebasePlugin
                                        handlePluginExceptionWithoutContext:
                                            exception];
                                  }
                                }];

    [self sendPluginNoResultAndKeepCallback:command
                                 callbackId:command.callbackId];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'authenticateUserWithApple' action.
 * Performs Apple Sign-In and returns a reusable auth credential.
 *
 * @param command The active Cordova command.
 */
- (void)authenticateUserWithApple:(CDVInvokedUrlCommand *)command {
  @try {
    CDVPluginResult *pluginResult;
    if (@available(iOS 13.0, *)) {
      self.appleSignInCallbackId = command.callbackId;
      [self startSignInWithAppleFlow];

      pluginResult =
          [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
      [pluginResult setKeepCallbackAsBool:YES];
    } else {
      pluginResult = [CDVPluginResult
          resultWithStatus:CDVCommandStatus_ERROR
           messageAsString:
               @"OS version is too low - Apple Sign In requires iOS 13.0+"];
    }

    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:command.callbackId];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'authenticateUserWithMicrosoft' action.
 * Performs Microsoft Sign-In via OAuth and returns a reusable auth credential.
 *
 * @param command The active Cordova command.
 */
- (void)authenticateUserWithMicrosoft:(CDVInvokedUrlCommand *)command {
  @try {
    NSString *providerId = @"microsoft.com";
    NSMutableDictionary *customParameters = [[NSMutableDictionary alloc] init];
    [customParameters setValue:@"consent" forKey:@"prompt"];

    NSString *locale = [command.arguments objectAtIndex:0];
    if (locale != nil) {
      [customParameters setValue:locale forKey:@"locale"];
    }

    [self authenticateWithOAuth:command
                     providerId:providerId
               customParameters:customParameters
                         scopes:nil];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'authenticateUserWithOAuth' action.
 * Performs Sign-In with an arbitrary OAuth provider.
 *
 * @param command The active Cordova command.
 */
- (void)authenticateUserWithOAuth:(CDVInvokedUrlCommand *)command {
  @try {
    NSString *providerId = [command.arguments objectAtIndex:0];
    NSDictionary *customParameters = [command.arguments objectAtIndex:1];
    NSArray *scopes = [command.arguments objectAtIndex:2];

    [self authenticateWithOAuth:command
                     providerId:providerId
               customParameters:customParameters
                         scopes:scopes];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Internal helper to perform OAuth authentication with specific parameters.
 *
 * @param command The active Cordova command.
 * @param providerId The OAuth provider ID.
 * @param customParameters Custom parameters for the OAuth request.
 * @param scopes Scopes for the OAuth request.
 */
- (void)authenticateWithOAuth:(CDVInvokedUrlCommand *)command
                   providerId:(NSString *)providerId
             customParameters:(NSDictionary *)customParameters
                       scopes:(NSArray *)scopes {
  oauthProvider = [FIROAuthProvider providerWithProviderID:providerId];

  if (customParameters != nil) {
    for (id key in customParameters) {
      id value = [customParameters objectForKey:key];
      [oauthProvider setCustomParameters:@{key : value}];
    }
  }

  if (scopes != nil) {
    [oauthProvider setScopes:scopes];
  }

  [oauthProvider
      getCredentialWithUIDelegate:nil
                       completion:^(FIRAuthCredential *_Nullable credential,
                                    NSError *_Nullable error) {
                         CDVPluginResult *pluginResult;
                         if (error) {
                           pluginResult = [self createAuthErrorResult:error];
                         } else if (credential) {
                           NSNumber *key = [self saveAuthCredential:credential];
                           NSMutableDictionary *result =
                               [[NSMutableDictionary alloc] init];
                           [result setValue:@"true"
                                     forKey:@"instantVerification"];
                           [result setValue:key forKey:@"id"];
                           pluginResult = [CDVPluginResult
                                  resultWithStatus:CDVCommandStatus_OK
                               messageAsDictionary:result];
                         }
                         [self.commandDelegate
                             sendPluginResult:pluginResult
                                   callbackId:command.callbackId];
                       }];
}

/**
 * Implementation for the 'authenticateUserWithFacebook' action.
 * Performs Facebook Sign-In and returns a reusable auth credential.
 *
 * @param command The active Cordova command.
 */
- (void)authenticateUserWithFacebook:(CDVInvokedUrlCommand *)command {
  @try {
    NSString *accessToken = [command.arguments objectAtIndex:0];
    FIRAuthCredential *credential =
        [FIRFacebookAuthProvider credentialWithAccessToken:accessToken];
    NSNumber *key = [self saveAuthCredential:credential];
    NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
    [result setValue:@"true" forKey:@"instantVerification"];
    [result setValue:key forKey:@"id"];
    CDVPluginResult *pluginResult =
        [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                      messageAsDictionary:result];
    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:command.callbackId];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'signInWithCredential' action.
 * Signs in the user with a provided auth credential.
 *
 * @param command The active Cordova command.
 */
- (void)signInWithCredential:(CDVInvokedUrlCommand *)command {
  @try {
    FIRAuthCredential *credential =
        [self obtainAuthCredential:[command.arguments objectAtIndex:0]
                           command:command];
    if (credential == nil)
      return;

    [[FIRAuth auth]
        signInWithCredential:credential
                  completion:^(FIRAuthDataResult *_Nullable authResult,
                               NSError *_Nullable error) {
                    [self handleAuthResult:authResult
                                     error:error
                                   command:command];
                  }];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'reauthenticateWithCredential' action.
 * Re-authenticates the current user.
 *
 * @param command The active Cordova command.
 */
- (void)reauthenticateWithCredential:(CDVInvokedUrlCommand *)command {
  @try {
    if ([self userNotSignedInError:command])
      return;
    FIRUser *user = [FIRAuth auth].currentUser;

    FIRAuthCredential *credential =
        [self obtainAuthCredential:[command.arguments objectAtIndex:0]
                           command:command];
    if (credential == nil)
      return;

    [user
        reauthenticateWithCredential:credential
                          completion:^(FIRAuthDataResult *_Nullable authResult,
                                       NSError *_Nullable error) {
                            [self handleAuthResult:authResult
                                             error:error
                                           command:command];
                          }];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'linkUserWithCredential' action.
 * Links the current user with a new identity provider.
 *
 * @param command The active Cordova command.
 */
- (void)linkUserWithCredential:(CDVInvokedUrlCommand *)command {
  @try {
    FIRAuthCredential *credential =
        [self obtainAuthCredential:[command.arguments objectAtIndex:0]
                           command:command];
    if (credential == nil)
      return;

    [[FIRAuth auth].currentUser
        linkWithCredential:credential
                completion:^(FIRAuthDataResult *_Nullable authResult,
                             NSError *_Nullable error) {
                  [self handleAuthResult:authResult
                                   error:error
                                 command:command];
                }];

  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'unlinkUserWithProvider' action.
 * Unlinks the current user from an identity provider.
 *
 * @param command The active Cordova command.
 */
- (void)unlinkUserWithProvider:(CDVInvokedUrlCommand *)command {
  @try {
    if ([self userNotSignedInError:command])
      return;
    FIRUser *user = [FIRAuth auth].currentUser;

    NSString *providerId = [command.arguments objectAtIndex:0];

    [user unlinkFromProvider:providerId
                  completion:^(FIRUser *_Nullable user,
                               NSError *_Nullable error) {
                    [self handleEmptyResultWithPotentialError:error
                                                      command:command];
                  }];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'isUserSignedIn' action.
 * Checks if the user is currently signed in.
 *
 * @param command The active Cordova command.
 */
- (void)isUserSignedIn:(CDVInvokedUrlCommand *)command {
  @try {
    bool isSignedIn = [self isSignedIn];
    [self.commandDelegate
        sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                             messageAsBool:isSignedIn]
              callbackId:command.callbackId];

  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'signOutUser' action.
 * Signs out the current user from Firebase and Google (if applicable).
 *
 * @param command The active Cordova command.
 */
- (void)signOutUser:(CDVInvokedUrlCommand *)command {
  @try {
    if ([self userNotSignedInError:command])
      return;

    // If signed in with Google
    if ([GIDSignIn.sharedInstance currentUser] != nil) {
      // Sign out of Google
      [GIDSignIn.sharedInstance
          disconnectWithCompletion:^(NSError *_Nullable error) {
            if (error) {
              [self.commandDelegate
                  sendPluginResult:
                      [CDVPluginResult
                          resultWithStatus:CDVCommandStatus_ERROR
                           messageAsString:
                               [NSString stringWithFormat:
                                             @"Error signing out of Google: %@",
                                             error]]
                        callbackId:command.callbackId];
            }

            [self signOutOfFirebase:command];
          }];
    } else {
      [self signOutOfFirebase:command];
    }
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Internal helper to sign out of Firebase.
 *
 * @param command The active Cordova command.
 */
- (void)signOutOfFirebase:(CDVInvokedUrlCommand *)command {
  NSError *signOutError;
  BOOL status = [[FIRAuth auth] signOut:&signOutError];
  if (!status) {
    [self.commandDelegate
        sendPluginResult:
            [CDVPluginResult
                resultWithStatus:CDVCommandStatus_ERROR
                 messageAsString:
                     [NSString
                         stringWithFormat:@"Error signing out of Firebase: %@",
                                          signOutError]]
              callbackId:command.callbackId];
  } else {
    [self.commandDelegate
        sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK]
              callbackId:command.callbackId];
  }
}

/**
 * Implementation for the 'getCurrentUser' action.
 * Retrieves profile information for the current user.
 *
 * @param command The active Cordova command.
 */
- (void)getCurrentUser:(CDVInvokedUrlCommand *)command {

  @try {
    if ([self userNotSignedInError:command])
      return;
    [self extractAndReturnUserInfo:command];

  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'reloadCurrentUser' action.
 * Forces a refresh of the current user's profile data.
 *
 * @param command The active Cordova command.
 */
- (void)reloadCurrentUser:(CDVInvokedUrlCommand *)command {

  @try {
    if ([self userNotSignedInError:command])
      return;
    FIRUser *user = [FIRAuth auth].currentUser;
    [user reloadWithCompletion:^(NSError *_Nullable error) {
      if (error != nil) {
        [self handleEmptyResultWithPotentialError:error command:command];
      } else {
        [self extractAndReturnUserInfo:command];
      }
    }];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Internal helper to extract user information and send it to the webview.
 *
 * @param command The active Cordova command.
 */
- (void)extractAndReturnUserInfo:(CDVInvokedUrlCommand *)command {
  FIRUser *user = [FIRAuth auth].currentUser;
  NSMutableDictionary *userInfo = [NSMutableDictionary new];
  [userInfo setValue:user.displayName forKey:@"name"];
  [userInfo setValue:user.email forKey:@"email"];
  [userInfo setValue:@(user.isEmailVerified ? true : false)
              forKey:@"emailIsVerified"];
  [userInfo setValue:user.phoneNumber forKey:@"phoneNumber"];
  [userInfo setValue:user.photoURL ? user.photoURL.absoluteString : nil
              forKey:@"photoUrl"];
  [userInfo setValue:user.uid forKey:@"uid"];
  [userInfo setValue:@(user.isAnonymous ? true : false) forKey:@"isAnonymous"];

  FIRUserMetadata *metadata = user.metadata;
  userInfo[@"creationTimestamp"] =
      [self getTimestampFromDate:metadata.creationDate];
  userInfo[@"lastSignInTimestamp"] =
      [self getTimestampFromDate:metadata.lastSignInDate];

  NSMutableArray *providerData = [[NSMutableArray alloc] init];
  for (id<FIRUserInfo> userInfo in user.providerData) {
    // Create a dictionary, add the providerData properties to it and add it to
    // the array
    NSMutableDictionary *providerDataDict = [[NSMutableDictionary alloc] init];
    providerDataDict[@"providerId"] = userInfo.providerID;
    providerDataDict[@"uid"] = userInfo.uid;
    providerDataDict[@"displayName"] = userInfo.displayName;
    providerDataDict[@"email"] = userInfo.email;
    providerDataDict[@"phoneNumber"] = userInfo.phoneNumber;
    providerDataDict[@"photoUrl"] = [userInfo.photoURL absoluteString];
    [providerData addObject:providerDataDict];
  }
  userInfo[@"providers"] = providerData;

  [user getIDTokenWithCompletion:^(NSString *_Nullable token,
                                   NSError *_Nullable error) {
    if (error == nil) {
      [userInfo setValue:token forKey:@"idToken"];
    }
    [user getIDTokenResultWithCompletion:^(
              FIRAuthTokenResult *_Nullable tokenResult,
              NSError *_Nullable error) {
      if (error == nil) {
        [userInfo setValue:tokenResult.signInProvider forKey:@"providerId"];
      }
      [self.commandDelegate
          sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                         messageAsDictionary:userInfo]
                callbackId:command.callbackId];
    }];
  }];
}

/**
 * Internal helper to convert an NSDate to a millisecond timestamp.
 *
 * @param date The source NSDate.
 * @return The timestamp number.
 */
- (NSNumber *)getTimestampFromDate:(NSDate *)date {
  if (date == nil)
    return nil;
  return @([date timeIntervalSince1970] * 1000);
}

/**
 * Implementation for the 'updateUserProfile' action.
 * Updates the display name and/or photo URL of the current user.
 *
 * @param command The active Cordova command.
 */
- (void)updateUserProfile:(CDVInvokedUrlCommand *)command {
  @try {
    if ([self userNotSignedInError:command])
      return;
    FIRUser *user = [FIRAuth auth].currentUser;

    NSDictionary *profile = [command.arguments objectAtIndex:0];

    FIRUserProfileChangeRequest *changeRequest = [user profileChangeRequest];
    if ([profile objectForKey:@"name"] != nil) {
      changeRequest.displayName = [profile objectForKey:@"name"];
    }
    if ([profile objectForKey:@"photoUri"] != nil) {
      changeRequest.photoURL =
          [NSURL URLWithString:[profile objectForKey:@"photoUri"]];
    }

    [changeRequest commitChangesWithCompletion:^(NSError *_Nullable error) {
      @try {
        [self handleEmptyResultWithPotentialError:error command:command];
      } @catch (NSException *exception) {
        [self handlePluginExceptionWithContext:exception:command];
      }
    }];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'updateUserEmail' action.
 * Updates the email address of the current user.
 *
 * @param command The active Cordova command.
 */
- (void)updateUserEmail:(CDVInvokedUrlCommand *)command {
  @try {
    if ([self userNotSignedInError:command])
      return;
    FIRUser *user = [FIRAuth auth].currentUser;

    NSString *email = [command.arguments objectAtIndex:0];
    [user updateEmail:email
           completion:^(NSError *_Nullable error) {
             @try {
               [self handleEmptyResultWithPotentialError:error command:command];
             } @catch (NSException *exception) {
               [self handlePluginExceptionWithContext:exception:command];
             }
           }];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'verifyBeforeUpdateEmail' action.
 * Sends a verification email to a new address before updating it.
 *
 * @param command The active Cordova command.
 */
- (void)verifyBeforeUpdateEmail:(CDVInvokedUrlCommand *)command {
  @try {
    if ([self userNotSignedInError:command])
      return;
    FIRUser *user = [FIRAuth auth].currentUser;
    NSString *email = [command.arguments objectAtIndex:0];
    [user
        sendEmailVerificationBeforeUpdatingEmail:email
                                      completion:^(NSError *_Nullable error) {
                                        @try {
                                          [self
                                              handleEmptyResultWithPotentialError:
                                                  error
                                                                          command:
                                                                              command];
                                        } @catch (NSException *exception) {
                                          [self
                                              handlePluginExceptionWithContext:
                                                                     exception:
                                                                         command];
                                        }
                                      }];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'sendUserEmailVerification' action.
 * Sends a verification email to the current user.
 *
 * @param command The active Cordova command.
 */
- (void)sendUserEmailVerification:(CDVInvokedUrlCommand *)command {
  @try {
    if ([self userNotSignedInError:command])
      return;
    FIRUser *user = [FIRAuth auth].currentUser;

    NSDictionary *actionCodeSettingsParams =
        [command.arguments objectAtIndex:0];
    if (![actionCodeSettingsParams isEqual:[NSNull null]]) {
      FIRActionCodeSettings *actionCodeSettings =
          [[FIRActionCodeSettings alloc] init];
      if ([actionCodeSettingsParams objectForKey:@"handleCodeInApp"] != nil) {
        actionCodeSettings.handleCodeInApp = [[actionCodeSettingsParams
            objectForKey:@"handleCodeInApp"] boolValue];
      }
      if ([actionCodeSettingsParams objectForKey:@"url"] != nil) {
        actionCodeSettings.URL = [NSURL
            URLWithString:[actionCodeSettingsParams objectForKey:@"url"]];
      }
      if ([actionCodeSettingsParams objectForKey:@"iosBundleId"] != nil) {
        actionCodeSettings.iOSBundleID =
            [NSString stringWithString:[actionCodeSettingsParams
                                           objectForKey:@"iosBundleId"]];
      }
      if ([actionCodeSettingsParams objectForKey:@"androidPackageName"] !=
          nil) {
        NSString *minimumVersion;
        if ([actionCodeSettingsParams objectForKey:@"minimumVersion"] != nil) {
          minimumVersion =
              [NSString stringWithString:[actionCodeSettingsParams
                                             objectForKey:@"minimumVersion"]];
        }
        [actionCodeSettings
            setAndroidPackageName:
                [NSString
                    stringWithString:[actionCodeSettingsParams
                                         objectForKey:@"androidPackageName"]]
            installIfNotAvailable:[[actionCodeSettingsParams
                                      objectForKey:@"installIfNotAvailable"]
                                      boolValue]
                   minimumVersion:minimumVersion];
      }
      [user
          sendEmailVerificationWithActionCodeSettings:actionCodeSettings
                                           completion:^(
                                               NSError *_Nullable error) {
                                             @try {
                                               [self
                                                   handleEmptyResultWithPotentialError:
                                                       error
                                                                               command:
                                                                                   command];
                                             } @catch (NSException *exception) {
                                               [self
                                                   handlePluginExceptionWithContext:
                                                                          exception:
                                                                              command];
                                             }
                                           }];
    } else {
      [user sendEmailVerificationWithCompletion:^(NSError *_Nullable error) {
        @try {
          [self handleEmptyResultWithPotentialError:error command:command];
        } @catch (NSException *exception) {
          [self handlePluginExceptionWithContext:exception:command];
        }
      }];
    }

  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'updateUserPassword' action.
 * Updates the password of the current user.
 *
 * @param command The active Cordova command.
 */
- (void)updateUserPassword:(CDVInvokedUrlCommand *)command {
  @try {
    if ([self userNotSignedInError:command])
      return;
    FIRUser *user = [FIRAuth auth].currentUser;

    NSString *password = [command.arguments objectAtIndex:0];
    [user updatePassword:password
              completion:^(NSError *_Nullable error) {
                @try {
                  [self handleEmptyResultWithPotentialError:error
                                                    command:command];
                } @catch (NSException *exception) {
                  [self handlePluginExceptionWithContext:exception:command];
                }
              }];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'sendUserPasswordResetEmail' action.
 * Sends a password reset email to a specified address.
 *
 * @param command The active Cordova command.
 */
- (void)sendUserPasswordResetEmail:(CDVInvokedUrlCommand *)command {
  @try {
    NSString *email = [command.arguments objectAtIndex:0];
    [[FIRAuth auth]
        sendPasswordResetWithEmail:email
                        completion:^(NSError *_Nullable error) {
                          @try {
                            [self handleEmptyResultWithPotentialError:error
                                                              command:command];
                          } @catch (NSException *exception) {
                            [self handlePluginExceptionWithContext:
                                                         exception:command];
                          }
                        }];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'deleteUser' action.
 * Deletes the current user's account.
 *
 * @param command The active Cordova command.
 */
- (void)deleteUser:(CDVInvokedUrlCommand *)command {
  @try {
    if ([self userNotSignedInError:command])
      return;
    FIRUser *user = [FIRAuth auth].currentUser;

    [user deleteWithCompletion:^(NSError *_Nullable error) {
      @try {
        [self handleEmptyResultWithPotentialError:error command:command];
      } @catch (NSException *exception) {
        [self handlePluginExceptionWithContext:exception:command];
      }
    }];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Internal helper to initiate the Apple Sign-In flow.
 */
- (void)startSignInWithAppleFlow API_AVAILABLE(ios(13.0)) {
  NSString *nonce = [self randomNonce:32];
  currentNonce = nonce;
  ASAuthorizationAppleIDProvider *appleIDProvider =
      [[ASAuthorizationAppleIDProvider alloc] init];
  ASAuthorizationAppleIDRequest *request = [appleIDProvider createRequest];
  request.requestedScopes =
      @[ ASAuthorizationScopeFullName, ASAuthorizationScopeEmail ];
  request.nonce = [self stringBySha256HashingString:nonce];

  ASAuthorizationController *authorizationController =
      [[ASAuthorizationController alloc]
          initWithAuthorizationRequests:@[ request ]];
  authorizationController.delegate = [AppDelegate instance];
  authorizationController.presentationContextProvider = [AppDelegate instance];
  [authorizationController performRequests];
}

/**
 * Internal helper to hash a string using SHA-256.
 *
 * @param input The source string.
 * @return The hashed hexadecimal string.
 */
- (NSString *)stringBySha256HashingString:(NSString *)input {
  const char *string = [input UTF8String];
  unsigned char result[CC_SHA256_DIGEST_LENGTH];
  CC_SHA256(string, (CC_LONG)strlen(string), result);

  NSMutableString *hashed =
      [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
  for (NSInteger i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
    [hashed appendFormat:@"%02x", result[i]];
  }
  return hashed;
}

// Generates random nonce for Apple Sign In
/**
 * Generates a random cryptographic nonce for Apple Sign-In.
 *
 * @param length The desired length of the nonce.
 * @return The random nonce string.
 */
- (NSString *)randomNonce:(NSInteger)length {
  NSAssert(length > 0, @"Expected nonce to have positive length");
  NSString *characterSet =
      @"0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._";
  NSMutableString *result = [NSMutableString string];
  NSInteger remainingLength = length;

  while (remainingLength > 0) {
    NSMutableArray *randoms = [NSMutableArray arrayWithCapacity:16];
    for (NSInteger i = 0; i < 16; i++) {
      uint8_t random = 0;
      int errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random);
      NSAssert(errorCode == errSecSuccess,
               @"Unable to generate nonce: OSStatus %i", errorCode);

      [randoms addObject:@(random)];
    }

    for (NSNumber *random in randoms) {
      if (remainingLength == 0) {
        break;
      }

      if (random.unsignedIntValue < characterSet.length) {
        unichar character =
            [characterSet characterAtIndex:random.unsignedIntValue];
        [result appendFormat:@"%C", character];
        remainingLength--;
      }
    }
  }

  return result;
}

/**
 * Implementation for the 'useAuthEmulator' action.
 * Configures the Auth client to use a local emulator.
 *
 * @param command The active Cordova command.
 */
- (void)useAuthEmulator:(CDVInvokedUrlCommand *)command {
  NSString *host = [command.arguments objectAtIndex:0];
  NSInteger port = [[command.arguments objectAtIndex:1] integerValue];
  @try {
    [[FIRAuth auth] useEmulatorWithHost:host port:port];
    [self sendPluginSuccess:command];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'getClaims' action.
 * Retrieves custom claims for the current user.
 *
 * @param command The active Cordova command.
 */
- (void)getClaims:(CDVInvokedUrlCommand *)command {
  @try {
    if ([self userNotSignedInError:command])
      return;
    FIRUser *user = [FIRAuth auth].currentUser;

    [user
        getIDTokenResultForcingRefresh:YES
                            completion:^(
                                FIRAuthTokenResult *_Nullable tokenResult,
                                NSError *_Nullable error) {
                              if (error != nil) {
                                [self sendPluginErrorWithError:error
                                                       command:command];
                                return;
                              }

                              [self
                                  sendPluginDictionaryResult:tokenResult.claims
                                                     command:command
                                                  callbackId:command
                                                                 .callbackId];
                            }];

  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/*
 * Analytics
 */
/**
 * Implementation for the 'setAnalyticsCollectionEnabled' action.
 * Enables or disables automatic analytics collection.
 *
 * @param command The active Cordova command.
 */
- (void)setAnalyticsCollectionEnabled:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      BOOL enabled = [[command argumentAtIndex:0] boolValue];
      CDVPluginResult *pluginResult;
      [FIRAnalytics setAnalyticsCollectionEnabled:enabled];
      [self setPreferenceFlag:FIREBASE_ANALYTICS_COLLECTION_ENABLED
                         flag:enabled];
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];

      [self.commandDelegate sendPluginResult:pluginResult
                                  callbackId:command.callbackId];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Implementation for the 'isAnalyticsCollectionEnabled' action.
 * Checks if automatic analytics collection is enabled.
 *
 * @param command The active Cordova command.
 */
- (void)isAnalyticsCollectionEnabled:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      CDVPluginResult *pluginResult = [CDVPluginResult
          resultWithStatus:CDVCommandStatus_OK
             messageAsBool:[self getPreferenceFlag:
                                     FIREBASE_ANALYTICS_COLLECTION_ENABLED]];
      [self.commandDelegate sendPluginResult:pluginResult
                                  callbackId:command.callbackId];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Implementation for the 'setAnalyticsConsentMode' action.
 * Sets the analytics consent mode (GDPR compliance).
 *
 * @param command The active Cordova command.
 */
- (void)setAnalyticsConsentMode:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    CDVPluginResult *pluginResult = nil;
    NSDictionary *consentObject = [command.arguments objectAtIndex:0];

    NSMutableDictionary *consentSettings = [[NSMutableDictionary alloc] init];

    NSEnumerator *enumerator = [consentObject keyEnumerator];
    id key;
    while ((key = [enumerator nextObject])) {
      NSString *consentType = [self consentTypeFromString:key];
      NSString *consentStatus =
          [self consentStatusFromString:[consentObject objectForKey:key]];
      [consentSettings setObject:consentStatus forKey:consentType];
    }

    [FIRAnalytics setConsent:consentSettings];

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:command.callbackId];
  }];
}

/**
 * Internal helper to convert a string constant to FIRConsentType.
 *
 * @param consentTypeString The consent type string.
 * @return The corresponding constant.
 */
- (NSString *)consentTypeFromString:(NSString *)consentTypeString {
  if ([consentTypeString isEqualToString:@"ANALYTICS_STORAGE"]) {
    return FIRConsentTypeAnalyticsStorage;
  } else if ([consentTypeString isEqualToString:@"AD_STORAGE"]) {
    return FIRConsentTypeAdStorage;
  } else if ([consentTypeString isEqualToString:@"AD_PERSONALIZATION"]) {
    return FIRConsentTypeAdPersonalization;
  } else if ([consentTypeString isEqualToString:@"AD_USER_DATA"]) {
    return FIRConsentTypeAdUserData;
  } else {
    return nil;
  }
}

/**
 * Internal helper to convert a string constant to FIRConsentStatus.
 *
 * @param consentStatusString The consent status string.
 * @return The corresponding constant.
 */
- (NSString *)consentStatusFromString:(NSString *)consentStatusString {
  if ([consentStatusString isEqualToString:@"GRANTED"]) {
    return FIRConsentStatusGranted;
  } else if ([consentStatusString isEqualToString:@"DENIED"]) {
    return FIRConsentStatusDenied;
  } else {
    return nil;
  }
}

/**
 * Implementation for the 'logEvent' action.
 * Logs a custom analytics event with parameters.
 *
 * @param command The active Cordova command.
 */
- (void)logEvent:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      NSString *name = [command.arguments objectAtIndex:0];
      NSDictionary *parameters = [command argumentAtIndex:1];

      [FIRAnalytics logEventWithName:name parameters:parameters];

      CDVPluginResult *pluginResult =
          [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
      [self.commandDelegate sendPluginResult:pluginResult
                                  callbackId:command.callbackId];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Implementation for the 'setScreenName' action.
 * Logs a screen view analytics event.
 *
 * @param command The active Cordova command.
 */
- (void)setScreenName:(CDVInvokedUrlCommand *)command {
  @try {
    NSString *name = [command.arguments objectAtIndex:0];
    [FIRAnalytics logEventWithName:kFIREventScreenView
                        parameters:@{kFIRParameterScreenName : name}];
    CDVPluginResult *pluginResult =
        [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:command.callbackId];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Implementation for the 'setUserId' action.
 * Sets the user ID for analytics.
 *
 * @param command The active Cordova command.
 */
- (void)setUserId:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      NSString *id = [command.arguments objectAtIndex:0];

      [FIRAnalytics setUserID:id];

      CDVPluginResult *pluginResult =
          [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
      [self.commandDelegate sendPluginResult:pluginResult
                                  callbackId:command.callbackId];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Implementation for the 'setUserProperty' action.
 * Sets a custom user property for analytics.
 *
 * @param command The active Cordova command.
 */
- (void)setUserProperty:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      NSString *name = [command.arguments objectAtIndex:0];
      NSString *value = [command.arguments objectAtIndex:1];

      [FIRAnalytics setUserPropertyString:value forName:name];

      CDVPluginResult *pluginResult =
          [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
      [self.commandDelegate sendPluginResult:pluginResult
                                  callbackId:command.callbackId];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Implementation for the 'initiateOnDeviceConversionMeasurement' action.
 *
 * @param command The active Cordova command.
 */
- (void)initiateOnDeviceConversionMeasurement:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      NSDictionary *userIdentifier = [command.arguments objectAtIndex:0];
      if ([userIdentifier objectForKey:@"emailAddress"] != nil) {
        [FIRAnalytics initiateOnDeviceConversionMeasurementWithEmailAddress:
                          [userIdentifier objectForKey:@"emailAddress"]];
      } else if ([userIdentifier objectForKey:@"phoneNumber"] != nil) {
        [FIRAnalytics initiateOnDeviceConversionMeasurementWithPhoneNumber:
                          [userIdentifier objectForKey:@"phoneNumber"]];
      }

      [self sendPluginSuccess:command];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/*
 * Crashlytics
 */

/**
 * Implementation for the 'setCrashlyticsCollectionEnabled' action.
 * Enables or disables automatic crash collection.
 *
 * @param command The active Cordova command.
 */
- (void)setCrashlyticsCollectionEnabled:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      BOOL enabled = [[command argumentAtIndex:0] boolValue];
      CDVPluginResult *pluginResult;
      [[FIRCrashlytics crashlytics] setCrashlyticsCollectionEnabled:enabled];
      [self setPreferenceFlag:FIREBASE_CRASHLYTICS_COLLECTION_ENABLED
                         flag:enabled];
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];

      [self.commandDelegate sendPluginResult:pluginResult
                                  callbackId:command.callbackId];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Implementation for the 'isCrashlyticsCollectionEnabled' action.
 * Checks if automatic crash collection is enabled.
 *
 * @param command The active Cordova command.
 */
- (void)isCrashlyticsCollectionEnabled:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      CDVPluginResult *pluginResult =
          [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                              messageAsBool:[self isCrashlyticsEnabled]];
      [self.commandDelegate sendPluginResult:pluginResult
                                  callbackId:command.callbackId];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Internal helper to check if Crashlytics should be enabled based on user
 * settings.
 *
 * @return YES if enabled.
 */
- (BOOL)isCrashlyticsEnabled {
  return [self getPreferenceFlag:FIREBASE_CRASHLYTICS_COLLECTION_ENABLED];
}

/**
 * Implementation for the 'didCrashOnPreviousExecution' action.
 * Checks if the application crashed during the previous run.
 *
 * @param command The active Cordova command.
 */
- (void)didCrashOnPreviousExecution:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      CDVPluginResult *pluginResult =
          [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];

      if (![self isCrashlyticsEnabled]) {
        pluginResult = [CDVPluginResult
            resultWithStatus:CDVCommandStatus_ERROR
             messageAsString:@"Cannot query didCrashOnPreviousExecution - "
                             @"Crashlytics collection is disabled"];
      } else {
        pluginResult = [CDVPluginResult
            resultWithStatus:CDVCommandStatus_OK
               messageAsBool:[[FIRCrashlytics crashlytics]
                                 didCrashDuringPreviousExecution]];
      }

      [self.commandDelegate sendPluginResult:pluginResult
                                  callbackId:command.callbackId];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Implementation for the 'logError' action.
 * Logs a non-fatal error to Crashlytics.
 *
 * @param command The active Cordova command.
 */
- (void)logError:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      NSString *errorMessage = [command.arguments objectAtIndex:0];
      CDVPluginResult *pluginResult =
          [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
      if (![self isCrashlyticsEnabled]) {
        pluginResult = [CDVPluginResult
            resultWithStatus:CDVCommandStatus_ERROR
             messageAsString:
                 @"Cannot log error - Crashlytics collection is disabled"];
      } else if ([command.arguments objectAtIndex:0] == [NSNull null]) {
        pluginResult = [CDVPluginResult
            resultWithStatus:CDVCommandStatus_ERROR
             messageAsString:@"Cannot log error - error message is empty"];
      }
      // We can optionally be passed a stack trace from stackTrace.js which
      // we'll put in userInfo.
      else if ([command.arguments count] > 1) {
        NSArray *stackFrames = [command.arguments objectAtIndex:1];

        NSString *message = errorMessage;
        NSString *name = @"Uncaught Javascript exception";
        NSMutableArray *customFrames = [[NSMutableArray alloc] init];
        FIRExceptionModel *exceptionModel =
            [FIRExceptionModel exceptionModelWithName:name reason:message];

        for (NSDictionary *stackFrame in stackFrames) {
          FIRStackFrame *customFrame = [FIRStackFrame
              stackFrameWithSymbol:stackFrame[@"functionName"]
                              file:stackFrame[@"fileName"]
                              line:(uint32_t)[stackFrame[@"lineNumber"]
                                       intValue]];
          [customFrames addObject:customFrame];
        }
        exceptionModel.stackTrace = customFrames;
        [[FIRCrashlytics crashlytics] recordExceptionModel:exceptionModel];
      } else {
        // TODO detect and handle non-stack userInfo and pass to recordError
        NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
        NSError *error = [NSError errorWithDomain:errorMessage
                                             code:0
                                         userInfo:userInfo];
        [[FIRCrashlytics crashlytics] recordError:error];
      }
      [self.commandDelegate sendPluginResult:pluginResult
                                  callbackId:command.callbackId];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Implementation for the 'logMessage' action.
 * Logs a message to Crashlytics custom logs.
 *
 * @param command The active Cordova command.
 */
- (void)logMessage:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      NSString *message = [command argumentAtIndex:0 withDefault:@""];
      CDVPluginResult *pluginResult =
          [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
      if (![self isCrashlyticsEnabled]) {
        pluginResult = [CDVPluginResult
            resultWithStatus:CDVCommandStatus_ERROR
             messageAsString:
                 @"Cannot log message - Crashlytics collection is disabled"];
      } else if (message) {
        [[FIRCrashlytics crashlytics] logWithFormat:@"%@", message];
      }
      [self.commandDelegate sendPluginResult:pluginResult
                                  callbackId:command.callbackId];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Implementation for the 'setCrashlyticsCustomKey' action.
 * Sets a custom key/value pair formatted as a breadcrumb in Crashlytics.
 *
 * @param command The active Cordova command.
 */
- (void)setCrashlyticsCustomKey:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      NSString *key = [command argumentAtIndex:0 withDefault:@""];
      NSString *value = [command argumentAtIndex:1 withDefault:@""];
      CDVPluginResult *pluginResult =
          [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];

      if (![self isCrashlyticsEnabled]) {
        pluginResult = [CDVPluginResult
            resultWithStatus:CDVCommandStatus_ERROR
             messageAsString:@"Cannot set custom key/valuee - Crashlytics "
                             @"collection is disabled"];
      } else {
        [[FIRCrashlytics crashlytics] setCustomValue:value forKey:key];
      }
      [self.commandDelegate sendPluginResult:pluginResult
                                  callbackId:command.callbackId];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Implementation for the 'sendCrash' action.
 * Forces a native crash for testing purposes.
 *
 * @param command The active Cordova command.
 */
- (void)sendCrash:(CDVInvokedUrlCommand *)command {
  assert(NO);
}

/**
 * Implementation for the 'setCrashlyticsUserId' action.
 * Sets a custom user identifier for Crashlytics reports.
 *
 * @param command The active Cordova command.
 */
- (void)setCrashlyticsUserId:(CDVInvokedUrlCommand *)command {
  @try {
    NSString *userId = [command.arguments objectAtIndex:0];
    CDVPluginResult *pluginResult =
        [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    if (![self isCrashlyticsEnabled]) {
      pluginResult = [CDVPluginResult
          resultWithStatus:CDVCommandStatus_ERROR
           messageAsString:
               @"Cannot set user ID - Crashlytics collection is disabled"];
    } else {
      [[FIRCrashlytics crashlytics] setUserID:userId];
    }
    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:command.callbackId];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/*
 * Remote config
 */
/**
 * Implementation for the 'setConfigSettings' action.
 * Configures Remote Config settings like fetch timeout and minimum interval.
 *
 * @param command The active Cordova command.
 */
- (void)setConfigSettings:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      FIRRemoteConfig *remoteConfig = [FIRRemoteConfig remoteConfig];

      FIRRemoteConfigSettings *settings =
          [[FIRRemoteConfigSettings alloc] init];

      if ([command.arguments objectAtIndex:0] != [NSNull null]) {
        settings.fetchTimeout = [[command.arguments objectAtIndex:0] longValue];
      }

      if ([command.arguments objectAtIndex:1] != [NSNull null]) {
        settings.minimumFetchInterval =
            [[command.arguments objectAtIndex:1] longValue];
      }

      remoteConfig.configSettings = settings;

      [self sendPluginSuccess:command];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Implementation for the 'setDefaults' action.
 * Sets local default values for Remote Config.
 *
 * @param command The active Cordova command.
 */
- (void)setDefaults:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      NSDictionary *defaults = [command.arguments objectAtIndex:0];
      FIRRemoteConfig *remoteConfig = [FIRRemoteConfig remoteConfig];
      [remoteConfig setDefaults:defaults];
      [self sendPluginSuccess:command];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Implementation for the 'fetch' action.
 * Fetches Remote Config values from the server.
 *
 * @param command The active Cordova command.
 */
- (void)fetch:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      FIRRemoteConfig *remoteConfig = [FIRRemoteConfig remoteConfig];

      if ([command.arguments count] > 0) {
        int expirationDuration = [[command.arguments objectAtIndex:0] intValue];

        [remoteConfig
            fetchWithExpirationDuration:expirationDuration
                      completionHandler:^(FIRRemoteConfigFetchStatus status,
                                          NSError *_Nullable error) {
                        if (status == FIRRemoteConfigFetchStatusSuccess &&
                            error == nil) {
                          [self sendPluginSuccess:command];
                        } else if (error != nil) {
                          [self handleEmptyResultWithPotentialError:error
                                                            command:command];
                        } else {
                          [self sendPluginError:command];
                        }
                      }];
      } else {
        [remoteConfig
            fetchWithCompletionHandler:^(FIRRemoteConfigFetchStatus status,
                                         NSError *_Nullable error) {
              if (status == FIRRemoteConfigFetchStatusSuccess && error == nil) {
                [self sendPluginSuccess:command];
              } else if (error != nil) {
                [self handleEmptyResultWithPotentialError:error
                                                  command:command];
              } else {
                [self sendPluginError:command];
              }
            }];
      }
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Implementation for the 'activateFetched' action.
 * Activates the last successfully fetched Remote Config values.
 *
 * @param command The active Cordova command.
 */
- (void)activateFetched:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      FIRRemoteConfig *remoteConfig = [FIRRemoteConfig remoteConfig];
      [remoteConfig
          activateWithCompletion:^(BOOL changed, NSError *_Nullable error) {
            [self handleBoolResultWithPotentialError:error
                                             command:command
                                              result:true];
          }];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Implementation for the 'fetchAndActivate' action.
 * Fetches and immediately activates Remote Config values.
 *
 * @param command The active Cordova command.
 */
- (void)fetchAndActivate:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      FIRRemoteConfig *remoteConfig = [FIRRemoteConfig remoteConfig];
      [remoteConfig fetchAndActivateWithCompletionHandler:^(
                        FIRRemoteConfigFetchAndActivateStatus status,
                        NSError *_Nullable error) {
        bool activated =
            (status ==
                 FIRRemoteConfigFetchAndActivateStatusSuccessFetchedFromRemote ||
             status ==
                 FIRRemoteConfigFetchAndActivateStatusSuccessUsingPreFetchedData);
        [self handleBoolResultWithPotentialError:error
                                         command:command
                                          result:activated];
      }];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Implementation for the 'resetRemoteConfig' action.
 * (Stub on iOS as not currently supported).
 *
 * @param command The active Cordova command.
 */
- (void)resetRemoteConfig:(CDVInvokedUrlCommand *)command {
  [self sendPluginErrorWithMessage:
      @"resetRemoteConfig is not currently available on iOS":command];
}

/**
 * Implementation for the 'getAll' action.
 * Retrieves all Remote Config values as a dictionary.
 *
 * @param command The active Cordova command.
 */
- (void)getAll:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      FIRRemoteConfig *remoteConfig = [FIRRemoteConfig remoteConfig];
      NSArray *defaultKeys =
          [remoteConfig allKeysFromSource:FIRRemoteConfigSourceDefault];
      NSArray *remoteKeys =
          [remoteConfig allKeysFromSource:FIRRemoteConfigSourceRemote];
      NSArray *staticKeys =
          [remoteConfig allKeysFromSource:FIRRemoteConfigSourceStatic];
      NSArray *keys = defaultKeys;
      if ([keys count] == 0) {
        keys = remoteKeys;
      }
      if ([keys count] == 0) {
        keys = staticKeys;
      }
      NSMutableDictionary *result = [[NSMutableDictionary alloc] init];

      for (NSString *key in keys) {
        [result setObject:remoteConfig[key].stringValue forKey:key];
      }

      CDVPluginResult *pluginResult =
          [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                        messageAsDictionary:result];
      [self.commandDelegate sendPluginResult:pluginResult
                                  callbackId:command.callbackId];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Implementation for the 'getValue' action.
 * Retrieves a single Remote Config value by key.
 *
 * @param command The active Cordova command.
 */
- (void)getValue:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      NSString *key = [command.arguments objectAtIndex:0];
      FIRRemoteConfig *remoteConfig = [FIRRemoteConfig remoteConfig];
      NSString *value = remoteConfig[key].stringValue;
      CDVPluginResult *pluginResult =
          [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                            messageAsString:value];
      [self.commandDelegate sendPluginResult:pluginResult
                                  callbackId:command.callbackId];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Implementation for the 'getInfo' action.
 * Returns metadata about Remote Config state.
 *
 * @param command The active Cordova command.
 */
- (void)getInfo:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      FIRRemoteConfig *remoteConfig = [FIRRemoteConfig remoteConfig];
      NSInteger minimumFetchInterval =
          remoteConfig.configSettings.minimumFetchInterval;
      NSInteger fetchTimeout = remoteConfig.configSettings.fetchTimeout;
      NSDate *lastFetchTime = remoteConfig.lastFetchTime;
      FIRRemoteConfigFetchStatus lastFetchStatus = remoteConfig.lastFetchStatus;

      NSDictionary *configSettings = @{
        @"minimumFetchInterval" :
            [NSNumber numberWithInteger:minimumFetchInterval],
        @"fetchTimeout" : [NSNumber numberWithInteger:fetchTimeout],
      };

      NSDictionary *infoObject = @{
        @"configSettings" : configSettings,
        @"fetchTimeMillis" :
            (lastFetchTime
                 ? [NSNumber
                       numberWithInteger:(lastFetchTime.timeIntervalSince1970 *
                                          1000)]
                 : [NSNull null]),
        @"lastFetchStatus" : [NSNumber numberWithInteger:(lastFetchStatus)],
      };

      CDVPluginResult *pluginResult =
          [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                        messageAsDictionary:infoObject];
      [self.commandDelegate sendPluginResult:pluginResult
                                  callbackId:command.callbackId];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/*
 * Performance
 */
/**
 * Implementation for the 'setPerformanceCollectionEnabled' action.
 * Enables or disables automatic performance monitoring collection.
 *
 * @param command The active Cordova command.
 */
- (void)setPerformanceCollectionEnabled:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      BOOL enabled = [[command argumentAtIndex:0] boolValue];
      CDVPluginResult *pluginResult;
      [[FIRPerformance sharedInstance] setDataCollectionEnabled:enabled];
      [self setPreferenceFlag:FIREBASE_PERFORMANCE_COLLECTION_ENABLED
                         flag:enabled];
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];

      [self.commandDelegate sendPluginResult:pluginResult
                                  callbackId:command.callbackId];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Implementation for the 'isPerformanceCollectionEnabled' action.
 * Checks if performance monitoring collection is enabled.
 *
 * @param command The active Cordova command.
 */
- (void)isPerformanceCollectionEnabled:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      CDVPluginResult *pluginResult = [CDVPluginResult
          resultWithStatus:CDVCommandStatus_OK
             messageAsBool:[self getPreferenceFlag:
                                     FIREBASE_PERFORMANCE_COLLECTION_ENABLED]];
      [self.commandDelegate sendPluginResult:pluginResult
                                  callbackId:command.callbackId];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Implementation for the 'startTrace' action.
 * Starts a custom performance trace.
 *
 * @param command The active Cordova command.
 */
- (void)startTrace:(CDVInvokedUrlCommand *)command {

  [self.commandDelegate runInBackground:^{
    @try {
      NSString *traceName = [command.arguments objectAtIndex:0];

      @synchronized(traces) {
        FIRTrace *trace = [traces objectForKey:traceName];

        if (trace == nil) {
          trace = [FIRPerformance startTraceWithName:traceName];
          [traces setObject:trace forKey:traceName];
        }
      }

      CDVPluginResult *pluginResult =
          [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
      [self.commandDelegate sendPluginResult:pluginResult
                                  callbackId:command.callbackId];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Implementation for the 'incrementCounter' action.
 * Increments a custom metric on an active performance trace.
 *
 * @param command The active Cordova command.
 */
- (void)incrementCounter:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      NSString *traceName = [command.arguments objectAtIndex:0];
      NSString *counterNamed = [command.arguments objectAtIndex:1];
      CDVPluginResult *pluginResult =
          [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
      @synchronized(traces) {
        FIRTrace *trace = (FIRTrace *)[traces objectForKey:traceName];

        if (trace != nil) {
          [trace incrementMetric:counterNamed byInt:1];
          [self.commandDelegate sendPluginResult:pluginResult
                                      callbackId:command.callbackId];
        } else {
          pluginResult =
              [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                messageAsString:@"Trace not found"];
        }
      }

      [self.commandDelegate sendPluginResult:pluginResult
                                  callbackId:command.callbackId];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Implementation for the 'stopTrace' action.
 * Stops an active performance trace.
 *
 * @param command The active Cordova command.
 */
- (void)stopTrace:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      NSString *traceName = [command.arguments objectAtIndex:0];
      CDVPluginResult *pluginResult =
          [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
      @synchronized(traces) {
        FIRTrace *trace = [traces objectForKey:traceName];

        if (trace != nil) {
          [trace stop];
          [traces removeObjectForKey:traceName];
          [self.commandDelegate sendPluginResult:pluginResult
                                      callbackId:command.callbackId];
        } else {
          pluginResult =
              [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                messageAsString:@"Trace not found"];
        }
      }

      [self.commandDelegate sendPluginResult:pluginResult
                                  callbackId:command.callbackId];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/*
 * Firestore
 */

/**
 * Implementation for the 'addDocumentToFirestoreCollection' action.
 * Adds a new document to a Firestore collection and returns its auto-generated
 * ID.
 *
 * @param command The active Cordova command.
 */
- (void)addDocumentToFirestoreCollection:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      NSDictionary *document = [command.arguments objectAtIndex:0];
      NSString *collection = [command.arguments objectAtIndex:1];
      bool timestamp = [command.arguments objectAtIndex:2];

      NSMutableDictionary *document_mutable = [document mutableCopy];

      if (timestamp) {
        document_mutable[@"created"] =
            [FIRTimestamp timestampWithDate:[NSDate date]];
        document_mutable[@"lastUpdate"] =
            [FIRTimestamp timestampWithDate:[NSDate date]];
      }

      __block FIRDocumentReference *ref = [[firestore
          collectionWithPath:collection]
          addDocumentWithData:document_mutable
                   completion:^(NSError *_Nullable error) {
                     [self handleStringResultWithPotentialError:error
                                                        command:command
                                                         result:ref.documentID];
                   }];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Implementation for the 'setDocumentInFirestoreCollection' action.
 * Sets the data of a Firestore document, overwriting any existing data.
 *
 * @param command The active Cordova command.
 */
- (void)setDocumentInFirestoreCollection:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      NSString *documentId = [command.arguments objectAtIndex:0];
      NSDictionary *document = [command.arguments objectAtIndex:1];
      NSString *collection = [command.arguments objectAtIndex:2];
      bool timestamp = [command.arguments objectAtIndex:3];

      NSMutableDictionary *document_mutable = [document mutableCopy];

      if (timestamp) {
        document_mutable[@"lastUpdate"] =
            [FIRTimestamp timestampWithDate:[NSDate date]];
      }

      [[[firestore collectionWithPath:collection] documentWithPath:documentId]
             setData:document_mutable
          completion:^(NSError *_Nullable error) {
            [self handleEmptyResultWithPotentialError:error command:command];
          }];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Implementation for the 'updateDocumentInFirestoreCollection' action.
 * Updates specific fields of a Firestore document.
 *
 * @param command The active Cordova command.
 */
- (void)updateDocumentInFirestoreCollection:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      NSString *documentId = [command.arguments objectAtIndex:0];
      NSDictionary *document = [command.arguments objectAtIndex:1];
      NSString *collection = [command.arguments objectAtIndex:2];
      bool timestamp = [command.arguments objectAtIndex:3];

      NSMutableDictionary *document_mutable = [document mutableCopy];

      if (timestamp) {
        document_mutable[@"lastUpdate"] =
            [FIRTimestamp timestampWithDate:[NSDate date]];
      }

      FIRDocumentReference *docRef = [[firestore collectionWithPath:collection]
          documentWithPath:documentId];
      if (docRef != nil) {
        [docRef updateData:document_mutable
                completion:^(NSError *_Nullable error) {
                  [self handleEmptyResultWithPotentialError:error
                                                    command:command];
                }];
      } else {
        [self sendPluginErrorWithMessage:
            @"Document not found in collection":command];
      }
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Implementation for the 'deleteDocumentFromFirestoreCollection' action.
 * Deletes a document from a Firestore collection.
 *
 * @param command The active Cordova command.
 */
- (void)deleteDocumentFromFirestoreCollection:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      NSString *documentId = [command.arguments objectAtIndex:0];
      NSString *collection = [command.arguments objectAtIndex:1];

      [[[firestore collectionWithPath:collection] documentWithPath:documentId]
          deleteDocumentWithCompletion:^(NSError *_Nullable error) {
            [self handleEmptyResultWithPotentialError:error command:command];
          }];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Implementation for the 'documentExistsInFirestoreCollection' action.
 * Checks if a Firestore document exists.
 *
 * @param command The active Cordova command.
 */
- (void)documentExistsInFirestoreCollection:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      NSString *documentId = [command.arguments objectAtIndex:0];
      NSString *collection = [command.arguments objectAtIndex:1];

      FIRDocumentReference *docRef = [[firestore collectionWithPath:collection]
          documentWithPath:documentId];
      if (docRef != nil) {
        [docRef
            getDocumentWithCompletion:^(FIRDocumentSnapshot *_Nullable snapshot,
                                        NSError *_Nullable error) {
              BOOL docExists = snapshot.data != nil;
              [self handleBoolResultWithPotentialError:error
                                               command:command
                                                result:docExists];
            }];
      } else {
        [self sendPluginErrorWithMessage:@"Collection not found":command];
      }
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Implementation for the 'fetchDocumentInFirestoreCollection' action.
 * Retrieves the data of a Firestore document once.
 *
 * @param command The active Cordova command.
 */
- (void)fetchDocumentInFirestoreCollection:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      NSString *documentId = [command.arguments objectAtIndex:0];
      NSString *collection = [command.arguments objectAtIndex:1];

      FIRDocumentReference *docRef = [[firestore collectionWithPath:collection]
          documentWithPath:documentId];
      if (docRef != nil) {
        [docRef getDocumentWithCompletion:^(
                    FIRDocumentSnapshot *_Nullable snapshot,
                    NSError *_Nullable error) {
          if (error != nil) {
            [self sendPluginErrorWithMessage:error.localizedDescription:command];
          } else if (snapshot.data != nil) {
            [self.commandDelegate
                sendPluginResult:[CDVPluginResult
                                        resultWithStatus:CDVCommandStatus_OK
                                     messageAsDictionary:
                                         [self sanitiseFirestoreDataDictionary:
                                                   snapshot.data]]
                      callbackId:command.callbackId];
          } else {
            [self sendPluginErrorWithMessage:
                @"Document not found in collection":command];
          }
        }];
      } else {
        [self sendPluginErrorWithMessage:@"Collection not found":command];
      }
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Implementation for the 'listenToDocumentInFirestoreCollection' action.
 * Sets up a real-time listener for changes to a Firestore document.
 *
 * @param command The active Cordova command.
 */
- (void)listenToDocumentInFirestoreCollection:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      NSString *documentId = [command.arguments objectAtIndex:0];
      NSString *collection = [command.arguments objectAtIndex:1];
      bool includeMetadata = [command.arguments objectAtIndex:2];

      id<FIRListenerRegistration> listener =
          [[[firestore collectionWithPath:collection]
              documentWithPath:documentId] addSnapshotListenerWithIncludeMetadataChanges:
                                               includeMetadata
                                                                                listener:
                                                                                    ^(FIRDocumentSnapshot
                                                                                          *snapshot,
                                                                                      NSError
                                                                                          *error) {
                                                                                      @try {
                                                                                        if (snapshot !=
                                                                                            nil) {
                                                                                          NSMutableDictionary
                                                                                              *document =
                                                                                                  [[NSMutableDictionary
                                                                                                      alloc]
                                                                                                      init];
                                                                                          ;
                                                                                          [document
                                                                                              setObject:
                                                                                                  @"change"
                                                                                                 forKey:
                                                                                                     @"eventType"];
                                                                                          if (snapshot
                                                                                                  .data !=
                                                                                              nil) {
                                                                                            [document
                                                                                                setObject:
                                                                                                    snapshot
                                                                                                        .data
                                                                                                   forKey:
                                                                                                       @"snapshot"];
                                                                                          }
                                                                                          if (snapshot
                                                                                                  .metadata !=
                                                                                              nil) {
                                                                                            [document
                                                                                                setObject:
                                                                                                    [NSNumber
                                                                                                        numberWithBool:
                                                                                                            snapshot
                                                                                                                .metadata
                                                                                                                .fromCache]
                                                                                                   forKey:
                                                                                                       @"fromCache"];
                                                                                            [document
                                                                                                setObject:
                                                                                                    snapshot.metadata
                                                                                                            .hasPendingWrites
                                                                                                        ? @"local"
                                                                                                        : @"remote"
                                                                                                   forKey:
                                                                                                       @"source"];
                                                                                          }
                                                                                          [self
                                                                                              sendPluginDictionaryResultAndKeepCallback:
                                                                                                  [self
                                                                                                      sanitiseFirestoreDataDictionary:
                                                                                                          document]
                                                                                                                                command:
                                                                                                                                    command
                                                                                                                             callbackId:
                                                                                                                                 command
                                                                                                                                     .callbackId];
                                                                                        } else {
                                                                                          [self
                                                                                              sendPluginErrorWithError:
                                                                                                  error
                                                                                                               command:
                                                                                                                   command];
                                                                                        }
                                                                                      }
                                                                                      @catch (
                                                                                          NSException
                                                                                              *exception) {
                                                                                        [self
                                                                                            handlePluginExceptionWithContext:
                                                                                                                   exception:
                                                                                                                       command];
                                                                                      }
                                                                                    }];

      NSMutableDictionary *jsResult = [[NSMutableDictionary alloc] init];
      ;
      [jsResult setObject:@"id" forKey:@"eventType"];
      NSNumber *key = [self saveFirestoreListener:listener];
      [jsResult setObject:key forKey:@"id"];
      [self sendPluginDictionaryResultAndKeepCallback:jsResult
                                              command:command
                                           callbackId:command.callbackId];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Implementation for the 'fetchFirestoreCollection' action.
 * Retrieves all documents in a Firestore collection (optionally filtered).
 *
 * @param command The active Cordova command.
 */
- (void)fetchFirestoreCollection:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      NSString *collection = [command.arguments objectAtIndex:0];
      NSArray *filters = nil;
      if ([command.arguments objectAtIndex:1] != [NSNull null]) {
        filters = [command.arguments objectAtIndex:1];
      }

      FIRQuery *query = [firestore collectionWithPath:collection];
      if (filters != nil) {
        query = [self applyFiltersToFirestoreCollectionQuery:filters
                                                       query:query];
      }

      [query getDocumentsWithCompletion:^(FIRQuerySnapshot *_Nullable snapshot,
                                          NSError *_Nullable error) {
        if (error != nil) {
          [self sendPluginErrorWithMessage:error.localizedDescription:command];
        } else {
          NSMutableDictionary *documents = [[NSMutableDictionary alloc] init];
          ;
          for (FIRDocumentSnapshot *document in snapshot.documents) {
            [documents
                setObject:[self sanitiseFirestoreDataDictionary:document.data]
                   forKey:document.documentID];
          }
          [self.commandDelegate
              sendPluginResult:[CDVPluginResult
                                      resultWithStatus:CDVCommandStatus_OK
                                   messageAsDictionary:documents]
                    callbackId:command.callbackId];
        }
      }];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Implementation for the 'listenToFirestoreCollection' action.
 * Sets up a real-time listener for changes to a Firestore collection
 * (optionally filtered).
 *
 * @param command The active Cordova command.
 */
- (void)listenToFirestoreCollection:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      NSString *collection = [command.arguments objectAtIndex:0];
      NSArray *filters = nil;
      if ([command.arguments objectAtIndex:1] != [NSNull null]) {
        filters = [command.arguments objectAtIndex:1];
      }
      bool includeMetadata = [command.arguments objectAtIndex:2];

      FIRQuery *query = [firestore collectionWithPath:collection];
      if (filters != nil) {
        query = [self applyFiltersToFirestoreCollectionQuery:filters
                                                       query:query];
      }

      id<FIRListenerRegistration>
          listener = [query addSnapshotListenerWithIncludeMetadataChanges:
                                includeMetadata
                                                                 listener:
                                                                     ^(FIRQuerySnapshot *snapshot, NSError *error) {
                                                                       @try {
                                                                         if (snapshot !=
                                                                             nil) {
                                                                           NSMutableDictionary
                                                                               *jsResult =
                                                                                   [[NSMutableDictionary
                                                                                       alloc]
                                                                                       init];
                                                                           [jsResult
                                                                               setObject:
                                                                                   @"change"
                                                                                  forKey:
                                                                                      @"eventType"];

                                                                           NSMutableDictionary
                                                                               *documents =
                                                                                   [[NSMutableDictionary
                                                                                       alloc]
                                                                                       init];
                                                                           bool hasDocuments =
                                                                               false;
                                                                           for (
                                                                               FIRDocumentChange
                                                                                   *dc in snapshot
                                                                                       .documentChanges) {
                                                                             hasDocuments =
                                                                                 true;
                                                                             NSMutableDictionary
                                                                                 *document =
                                                                                     [[NSMutableDictionary
                                                                                         alloc]
                                                                                         init];
                                                                             if (dc.type ==
                                                                                 FIRDocumentChangeTypeAdded) {
                                                                               [document
                                                                                   setObject:
                                                                                       @"new"
                                                                                      forKey:
                                                                                          @"type"];
                                                                             } else if (
                                                                                 dc.type ==
                                                                                 FIRDocumentChangeTypeModified) {
                                                                               [document
                                                                                   setObject:
                                                                                       @"modified"
                                                                                      forKey:
                                                                                          @"type"];
                                                                             } else if (
                                                                                 dc.type ==
                                                                                 FIRDocumentChangeTypeRemoved) {
                                                                               [document
                                                                                   setObject:
                                                                                       @"removed"
                                                                                      forKey:
                                                                                          @"type"];
                                                                             } else {
                                                                               [document
                                                                                   setObject:
                                                                                       @"metadata"
                                                                                      forKey:
                                                                                          @"type"];
                                                                             }
                                                                             if (dc.document
                                                                                     .data !=
                                                                                 nil) {
                                                                               [document
                                                                                   setObject:
                                                                                       [self
                                                                                           sanitiseFirestoreDataDictionary:
                                                                                               dc.document
                                                                                                   .data]
                                                                                      forKey:
                                                                                          @"snapshot"];
                                                                             }
                                                                             if (dc.document
                                                                                     .metadata !=
                                                                                 nil) {
                                                                               [document
                                                                                   setObject:
                                                                                       [NSNumber
                                                                                           numberWithBool:
                                                                                               dc.document
                                                                                                   .metadata
                                                                                                   .fromCache]
                                                                                      forKey:
                                                                                          @"fromCache"];
                                                                               [document
                                                                                   setObject:
                                                                                       dc.document
                                                                                               .metadata
                                                                                               .hasPendingWrites
                                                                                           ? @"local"
                                                                                           : @"remote"
                                                                                      forKey:
                                                                                          @"source"];
                                                                             }
                                                                             [documents
                                                                                 setObject:
                                                                                     document
                                                                                    forKey:
                                                                                        dc.document
                                                                                            .documentID];
                                                                           }
                                                                           if (hasDocuments) {
                                                                             [jsResult
                                                                                 setObject:
                                                                                     documents
                                                                                    forKey:
                                                                                        @"documents"];
                                                                           }
                                                                           [self
                                                                               sendPluginDictionaryResultAndKeepCallback:
                                                                                   jsResult
                                                                                                                 command:
                                                                                                                     command
                                                                                                              callbackId:
                                                                                                                  command
                                                                                                                      .callbackId];
                                                                         } else {
                                                                           [self
                                                                               sendPluginErrorWithError:
                                                                                   error
                                                                                                command:
                                                                                                    command];
                                                                         }
                                                                       }
                                                                       @catch (
                                                                           NSException
                                                                               *exception) {
                                                                         [self
                                                                             handlePluginExceptionWithContext:
                                                                                                    exception:
                                                                                                        command];
                                                                       }
                                                                     }];

      NSMutableDictionary *jsResult = [[NSMutableDictionary alloc] init];
      ;
      [jsResult setObject:@"id" forKey:@"eventType"];
      NSNumber *key = [self saveFirestoreListener:listener];
      [jsResult setObject:key forKey:@"id"];
      [self sendPluginDictionaryResultAndKeepCallback:jsResult
                                              command:command
                                           callbackId:command.callbackId];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

- (FIRQuery *)applyFiltersToFirestoreCollectionQuery:(NSArray *)filters
                                               query:(FIRQuery *)query {
  for (int i = 0; i < [filters count]; i++) {
    NSArray *filter = [filters objectAtIndex:i];
    if ([[filter objectAtIndex:0] isEqualToString:@"where"]) {
      if ([[filter objectAtIndex:2] isEqualToString:@"=="]) {
        query = [query queryWhereField:[filter objectAtIndex:1]
                             isEqualTo:[self getFilterValueAsType:filter
                                                       valueIndex:3
                                                        typeIndex:4]];
      }
      if ([[filter objectAtIndex:2] isEqualToString:@"<"]) {
        query = [query queryWhereField:[filter objectAtIndex:1]
                            isLessThan:[self getFilterValueAsType:filter
                                                       valueIndex:3
                                                        typeIndex:4]];
      }
      if ([[filter objectAtIndex:2] isEqualToString:@">"]) {
        query = [query queryWhereField:[filter objectAtIndex:1]
                         isGreaterThan:[self getFilterValueAsType:filter
                                                       valueIndex:3
                                                        typeIndex:4]];
      }
      if ([[filter objectAtIndex:2] isEqualToString:@"<="]) {
        query = [query queryWhereField:[filter objectAtIndex:1]
                   isLessThanOrEqualTo:[self getFilterValueAsType:filter
                                                       valueIndex:3
                                                        typeIndex:4]];
      }
      if ([[filter objectAtIndex:2] isEqualToString:@">="]) {
        query = [query queryWhereField:[filter objectAtIndex:1]
                isGreaterThanOrEqualTo:[self getFilterValueAsType:filter
                                                       valueIndex:3
                                                        typeIndex:4]];
      }
      if ([[filter objectAtIndex:2] isEqualToString:@"array-contains"]) {
        query = [query queryWhereField:[filter objectAtIndex:1]
                         arrayContains:[self getFilterValueAsType:filter
                                                       valueIndex:3
                                                        typeIndex:4]];
      }
      continue;
    }
    if ([[filter objectAtIndex:0] isEqualToString:@"orderBy"]) {
      query = [query queryOrderedByField:[filter objectAtIndex:1]
                              descending:([[filter objectAtIndex:2]
                                             isEqualToString:@"desc"])];
      continue;
    }
    if ([[filter objectAtIndex:0] isEqualToString:@"startAt"]) {
      query = [query queryStartingAtValues:[self getFilterValueAsType:filter
                                                           valueIndex:1
                                                            typeIndex:2]];
      continue;
    }
    if ([[filter objectAtIndex:0] isEqualToString:@"endAt"]) {
      query = [query queryEndingAtValues:[self getFilterValueAsType:filter
                                                         valueIndex:1
                                                          typeIndex:2]];
      continue;
    }
    if ([[filter objectAtIndex:0] isEqualToString:@"limit"]) {
      query = [query
          queryLimitedTo:[(NSNumber *)[filter objectAtIndex:1] integerValue]];
      continue;
    }
  }
  return query;
}

/**
 * Internal helper to extract a filter value and cast it to the expected type.
 *
 * @param filter The filter array.
 * @param valueIndex The index of the value in the array.
 * @param typeIndex The index of the type string in the array.
 * @return The typed value object.
 */
- (id)getFilterValueAsType:(NSArray *)filter
                valueIndex:(int)valueIndex
                 typeIndex:(int)typeIndex {
  id typedValue = [filter objectAtIndex:valueIndex];

  NSString *type = @"string";
  if ([filter objectAtIndex:typeIndex] != nil) {
    type = [filter objectAtIndex:typeIndex];
  }

  if ([type isEqual:@"boolean"]) {
    if ([typedValue isKindOfClass:[NSNumber class]]) {
      typedValue = [NSNumber numberWithBool:typedValue];
    } else if ([typedValue isKindOfClass:[NSString class]]) {
      bool boolValue = [typedValue boolValue];
      typedValue = [NSNumber numberWithBool:boolValue];
    }
  } else if ([type isEqual:@"integer"] || [type isEqual:@"long"]) {
    if ([typedValue isKindOfClass:[NSString class]]) {
      NSInteger intValue = [typedValue integerValue];
      typedValue = [NSNumber numberWithInteger:intValue];
    }
  } else if ([type isEqual:@"double"]) {
    if ([typedValue isKindOfClass:[NSString class]]) {
      double doubleValue = [typedValue doubleValue];
      typedValue = [NSNumber numberWithDouble:doubleValue];
    }
  } else { // string
    if ([typedValue isKindOfClass:[NSNumber class]]) {
      if ([self isBoolNumber:typedValue]) {
        bool boolValue = [typedValue boolValue];
        typedValue = boolValue ? @"true" : @"false";
      } else {
        typedValue = [typedValue stringValue];
      }
    }
  }

  return typedValue;
}

// https://stackoverflow.com/a/30223989/777265
/**
 * Checks if an NSNumber represents a boolean value.
 *
 * @param num The number to check.
 * @return YES if boolean.
 */
- (BOOL)isBoolNumber:(NSNumber *)num {
  CFTypeID boolID = CFBooleanGetTypeID(); // the type ID of CFBoolean
  CFTypeID numID = CFGetTypeID((__bridge CFTypeRef)(num)); // the type ID of num
  return numID == boolID;
}

/**
 * Saves a Firestore listener registration and returns a unique ID.
 *
 * @param firestoreListener The listener to save.
 * @return A unique key for retrieval.
 */
- (NSNumber *)saveFirestoreListener:
    (id<FIRListenerRegistration>)firestoreListener {
  @synchronized(firestoreListeners) {
    int id = [self generateId];
    NSNumber *key = [NSNumber numberWithInt:id];
    [firestoreListeners setObject:firestoreListener forKey:key];
    return key;
  }
}

/**
 * Implementation for the 'removeFirestoreListener' action.
 *
 * @param command The Cordova command object.
 */
- (void)removeFirestoreListener:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      NSNumber *listenerId = @([[command.arguments objectAtIndex:0] intValue]);
      bool removed = [self _removeFirestoreListener:listenerId];
      if (removed) {
        [self sendPluginSuccess:command];
      } else {
        [self sendPluginErrorWithMessage:@"Listener ID not found":command];
      }
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Internal helper to remove a Firestore listener by its key.
 *
 * @param key The listener key.
 * @return true if successfully removed.
 */
- (bool)_removeFirestoreListener:(NSNumber *)key {
  @synchronized(firestoreListeners) {
    bool removed = false;
    if ([firestoreListeners objectForKey:key] != nil) {
      id<FIRListenerRegistration> firestoreListener =
          [firestoreListeners objectForKey:key];
      [firestoreListener remove];
      [firestoreListeners removeObjectForKey:key];
      removed = true;
    }
    return removed;
  }
}

/**
 * Recursively sanitizes a dictionary of Firestore data.
 *
 * @param data The dictionary to sanitize.
 * @return The sanitized dictionary.
 */
- (NSMutableDictionary *)sanitiseFirestoreDataDictionary:(NSDictionary *)data {
  NSMutableDictionary *sanitisedData = [[NSMutableDictionary alloc] init];
  for (id key in data) {
    id value = [data objectForKey:key];
    value = [self sanitizeFirestoreData:(id)value];
    [sanitisedData setValue:value forKey:key];
  }
  return sanitisedData;
}

/**
 * Sanitizes a single Firestore data value.
 * Converts DocumentReferences to paths, Timestamps to dictionaries, etc.
 *
 * @param value The value to sanitize.
 * @return The sanitized value.
 */
- (id)sanitizeFirestoreData:(id)value {
  if ([value isKindOfClass:[FIRDocumentReference class]]) {
    FIRDocumentReference *reference = (FIRDocumentReference *)value;
    NSString *path = reference.path;
    return path;
  } else if ([value isKindOfClass:[NSDictionary class]]) {
    return [self sanitiseFirestoreDataDictionary:value];
  } else if ([value isKindOfClass:[NSArray class]]) {
    NSMutableArray *array = [[NSMutableArray alloc] init];
    ;
    for (id element in value) {
      id sanitizedValue = (id)[self sanitizeFirestoreData:element];
      [array addObject:(id)sanitizedValue];
    }
    return array;
  } else if ([value isKindOfClass:[FIRTimestamp class]]) {
    FIRTimestamp *dateTimestamp = (FIRTimestamp *)value;
    NSDictionary *dateDictionary = @{
      @"nanoseconds" : [NSNumber numberWithInt:dateTimestamp.nanoseconds],
      @"seconds" : [NSNumber numberWithLong:dateTimestamp.seconds]
    };

    return dateDictionary;
  } else if ([value isKindOfClass:[NSNumber class]]) {
    double number = [value doubleValue];
    if (isnan(number) || isinf(number)) {
      return nil;
    }
  }
  return value;
}

/*
 * Functions
 */
/**
 * Implementation for the 'functionsHttpsCallable' action.
 *
 * @param command The Cordova command object.
 */
- (void)functionsHttpsCallable:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      __weak __auto_type weakSelf = self;
      NSString *name = [command.arguments objectAtIndex:0];
      NSDictionary *arguments = [command.arguments objectAtIndex:1];
      [[[FIRFunctions functions] HTTPSCallableWithName:name]
          callWithObject:arguments
              completion:^(FIRHTTPSCallableResult *_Nullable result,
                           NSError *_Nullable error) {
                if (error != nil) {
                  [weakSelf sendPluginErrorWithError:error command:command];
                } else {
                  [weakSelf sendPluginDictionaryResult:result.data
                                               command:command
                                            callbackId:command.callbackId];
                }
              }];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/*
 * Installations
 */
/**
 * Implementation for the 'getInstallationId' action.
 *
 * @param command The Cordova command object.
 */
- (void)getInstallationId:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      [[FIRInstallations installations]
          installationIDWithCompletion:^(NSString *identifier, NSError *error) {
            [self handleStringResultWithPotentialError:error
                                               command:command
                                                result:identifier];
          }];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Implementation for the 'getInstallationToken' action.
 *
 * @param command The Cordova command object.
 */
- (void)getInstallationToken:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      [[FIRInstallations installations]
          authTokenForcingRefresh:true
                       completion:^(FIRInstallationsAuthTokenResult *result,
                                    NSError *error) {
                         if (error != nil) {
                           [self sendPluginErrorWithError:error
                                                  command:command];
                         } else {
                           [self sendPluginStringResult:[result authToken]
                                                command:command
                                             callbackId:command.callbackId];
                         }
                       }];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Implementation for the 'deleteInstallationId' action.
 *
 * @param command The Cordova command object.
 */
- (void)deleteInstallationId:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    @try {
      [[FIRInstallations installations] deleteWithCompletion:^(NSError *error) {
        [self handleEmptyResultWithPotentialError:error command:command];
      }];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithContext:exception:command];
    }
  }];
}

/**
 * Internal method to fetch and report the current installation ID to the
 * webview.
 */
- (void)sendNewInstallationId {
  [self.commandDelegate runInBackground:^{
    @try {
      [[FIRInstallations installations] installationIDWithCompletion:^(
                                            NSString *identifier,
                                            NSError *error) {
        if (error != nil) {
          [self handlePluginErrorWithoutContext:error];
        } else if (currentInstallationId != identifier) {
          [FirebasePlugin.firebasePlugin
              executeGlobalJavascript:
                  [NSString
                      stringWithFormat:@"FirebasePlugin._"
                                       @"onInstallationIdChangeCallback('%@')",
                                       identifier]];
          currentInstallationId = identifier;
        }
      }];
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithoutContext:exception];
    }
  }];
}

/*************************************************/
#pragma mark - utility functions
/*************************************************/
/**
 * Sends a generic "OK" plugin result.
 *
 * @param command The active Cordova command.
 */
- (void)sendPluginSuccess:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate
      sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK]
            callbackId:command.callbackId];
}

/**
 * Sends a generic "OK" plugin result and keeps the callback active.
 *
 * @param callbackId The callback identifier.
 */
- (void)sendPluginSuccessAndKeepCallback:(NSString *)callbackId {
  CDVPluginResult *pluginResult =
      [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
  [pluginResult setKeepCallbackAsBool:YES];
}

/**
 * Sends a "NO RESULT" plugin result.
 *
 * @param command The active Cordova command.
 * @param callbackId The callback identifier.
 */
- (void)sendPluginNoResult:(CDVInvokedUrlCommand *)command
                callbackId:(NSString *)callbackId {
  CDVPluginResult *pluginResult =
      [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}

/**
 * Sends a "NO RESULT" plugin result and keeps the callback active.
 *
 * @param command The active Cordova command.
 * @param callbackId The callback identifier.
 */
- (void)sendPluginNoResultAndKeepCallback:(CDVInvokedUrlCommand *)command
                               callbackId:(NSString *)callbackId {
  CDVPluginResult *pluginResult =
      [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
  [pluginResult setKeepCallbackAsBool:YES];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}

/**
 * Sends a string-based success plugin result.
 *
 * @param result The result string.
 * @param command The active Cordova command.
 * @param callbackId The callback identifier.
 */
- (void)sendPluginStringResult:(NSString *)result
                       command:(CDVInvokedUrlCommand *)command
                    callbackId:(NSString *)callbackId {
  CDVPluginResult *pluginResult =
      [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                        messageAsString:result];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}

/**
 * Sends a string-based success plugin result and keeps the callback active.
 *
 * @param result The result string.
 * @param command The active Cordova command.
 * @param callbackId The callback identifier.
 */
- (void)sendPluginStringResultAndKeepCallback:(NSString *)result
                                      command:(CDVInvokedUrlCommand *)command
                                   callbackId:(NSString *)callbackId {
  CDVPluginResult *pluginResult =
      [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                        messageAsString:result];
  [pluginResult setKeepCallbackAsBool:YES];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}

/**
 * Sends a boolean-based success plugin result.
 *
 * @param result The result boolean.
 * @param command The active Cordova command.
 * @param callbackId The callback identifier.
 */
- (void)sendPluginBoolResult:(BOOL)result
                     command:(CDVInvokedUrlCommand *)command
                  callbackId:(NSString *)callbackId {
  CDVPluginResult *pluginResult =
      [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                          messageAsBool:result];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}

/**
 * Sends a boolean-based success plugin result and keeps the callback active.
 *
 * @param result The result boolean.
 * @param command The active Cordova command.
 * @param callbackId The callback identifier.
 */
- (void)sendPluginBoolResultAndKeepCallback:(BOOL)result
                                    command:(CDVInvokedUrlCommand *)command
                                 callbackId:(NSString *)callbackId {
  CDVPluginResult *pluginResult =
      [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                          messageAsBool:result];
  [pluginResult setKeepCallbackAsBool:YES];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}

/**
 * Sends a dictionary-based success plugin result.
 *
 * @param result The result dictionary.
 * @param command The active Cordova command.
 * @param callbackId The callback identifier.
 */
- (void)sendPluginDictionaryResult:(NSDictionary *)result
                           command:(CDVInvokedUrlCommand *)command
                        callbackId:(NSString *)callbackId {
  CDVPluginResult *pluginResult =
      [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                    messageAsDictionary:result];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}

/**
 * Sends a dictionary-based success plugin result and keeps the callback active.
 *
 * @param result The result dictionary.
 * @param command The active Cordova command.
 * @param callbackId The callback identifier.
 */
- (void)sendPluginDictionaryResultAndKeepCallback:(NSDictionary *)result
                                          command:
                                              (CDVInvokedUrlCommand *)command
                                       callbackId:(NSString *)callbackId {
  CDVPluginResult *pluginResult =
      [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                    messageAsDictionary:result];
  [pluginResult setKeepCallbackAsBool:YES];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}

/**
 * Sends an array-based success plugin result.
 *
 * @param result The result array.
 * @param command The active Cordova command.
 * @param callbackId The callback identifier.
 */
- (void)sendPluginArrayResult:(NSArray *)result
                      command:(CDVInvokedUrlCommand *)command
                   callbackId:(NSString *)callbackId {
  CDVPluginResult *pluginResult =
      [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                         messageAsArray:result];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}

/**
 * Sends an array-based success plugin result and keeps the callback active.
 *
 * @param result The result array.
 * @param command The active Cordova command.
 * @param callbackId The callback identifier.
 */
- (void)sendPluginArrayResultAndKeepCallback:(NSArray *)result
                                     command:(CDVInvokedUrlCommand *)command
                                  callbackId:(NSString *)callbackId {
  CDVPluginResult *pluginResult =
      [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                         messageAsArray:result];
  [pluginResult setKeepCallbackAsBool:YES];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}

/**
 * Sends a generic error plugin result.
 *
 * @param command The active Cordova command.
 */
- (void)sendPluginError:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate
      sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR]
            callbackId:command.callbackId];
}

/**
 * Sends an error plugin result with a message.
 *
 * @param errorMessage The error message string.
 * @param command The active Cordova command.
 */
- (void)sendPluginErrorWithMessage:(NSString *)
                      errorMessage:(CDVInvokedUrlCommand *)command {
  CDVPluginResult *pluginResult =
      [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                        messageAsString:errorMessage];
  [self _logError:errorMessage];
  [self.commandDelegate sendPluginResult:pluginResult
                              callbackId:command.callbackId];
}

- (void)sendPluginErrorWithError:(NSError *)error
                         command:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate
      sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                         messageAsString:error.description]
            callbackId:command.callbackId];
}

- (void)handleEmptyResultWithPotentialError:(NSError *)error
                                    command:(CDVInvokedUrlCommand *)command {
  if (error) {
    [self sendPluginErrorWithError:error command:command];
  } else {
    [self sendPluginSuccess:command];
  }
}

- (void)handleStringResultWithPotentialError:(NSError *)error
                                     command:(CDVInvokedUrlCommand *)command
                                      result:(NSString *)result {
  if (error) {
    [self sendPluginErrorWithError:error command:command];
  } else {
    [self sendPluginStringResult:result
                         command:command
                      callbackId:command.callbackId];
  }
}

- (void)handleBoolResultWithPotentialError:(NSError *)error
                                   command:(CDVInvokedUrlCommand *)command
                                    result:(BOOL)result {
  if (error) {
    [self sendPluginErrorWithError:error command:command];
  } else {
    [self sendPluginBoolResult:result
                       command:command
                    callbackId:command.callbackId];
  }
}

- (void)handlePluginExceptionWithContext:(NSException *)
                               exception:(CDVInvokedUrlCommand *)command {
  [self handlePluginExceptionWithoutContext:exception];
  CDVPluginResult *pluginResult =
      [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                        messageAsString:exception.reason];
  [self.commandDelegate sendPluginResult:pluginResult
                              callbackId:command.callbackId];
}

- (void)handlePluginExceptionWithoutContext:(NSException *)exception {
  [self
      _logError:[NSString stringWithFormat:@"EXCEPTION: %@", exception.reason]];
}

- (void)handlePluginErrorWithoutContext:(NSError *)error {
  [self _logError:[NSString stringWithFormat:@"ERROR: %@", error.description]];
}

/**
 * Executes a string of Javascript in the webview context.
 * Queues the call if the plugin is not yet initialized.
 *
 * @param jsString The Javascript to execute.
 */
- (void)executeGlobalJavascript:(NSString *)jsString {
  if (pluginInitialized) {
    [self doExecuteGlobalJavascript:jsString];
  } else {
    if (pendingGlobalJS == nil) {
      pendingGlobalJS = [[NSMutableArray alloc] init];
    }
    [pendingGlobalJS addObject:jsString];
  }
}

- (void)executePendingGlobalJavascript {
  if (pendingGlobalJS == nil) {
    NSLog(@"%@ No pending global JS calls", LOG_TAG);
    return;
  }
  NSLog(@"%@ Executing %lu pending global JS calls", LOG_TAG,
        (unsigned long)pendingGlobalJS.count);
  for (NSString *jsString in pendingGlobalJS) {
    [self doExecuteGlobalJavascript:jsString];
  }
  pendingGlobalJS = nil;
}

- (void)doExecuteGlobalJavascript:(NSString *)jsString {
  [self.commandDelegate evalJs:jsString];
}

/**
 * Logs an error message to both the native console and the webview console.
 *
 * @param msg The error message.
 */
- (void)_logError:(NSString *)msg {
  NSLog(@"%@ ERROR: %@", LOG_TAG, msg);
  NSString *jsString =
      [NSString stringWithFormat:@"console.error(\"%@: %@\")", LOG_TAG,
                                 [self escapeJavascriptString:msg]];
  [self executeGlobalJavascript:jsString];
}

/**
 * Logs an informational message to both the native console and the webview
 * console.
 *
 * @param msg The info message.
 */
- (void)_logInfo:(NSString *)msg {
  NSLog(@"%@ INFO: %@", LOG_TAG, msg);
  NSString *jsString =
      [NSString stringWithFormat:@"console.info(\"%@: %@\")", LOG_TAG,
                                 [self escapeJavascriptString:msg]];
  [self executeGlobalJavascript:jsString];
}

/**
 * Logs a general message to both the native console and the webview console.
 *
 * @param msg The log message.
 */
- (void)_logMessage:(NSString *)msg {
  NSLog(@"%@ LOG: %@", LOG_TAG, msg);
  NSString *jsString =
      [NSString stringWithFormat:@"console.log(\"%@: %@\")", LOG_TAG,
                                 [self escapeJavascriptString:msg]];
  [self executeGlobalJavascript:jsString];
}

/**
 * Escapes special characters in a string for safe inclusion in a Javascript
 * command.
 *
 * @param str The source string.
 * @return The escaped string.
 */
- (NSString *)escapeJavascriptString:(NSString *)str {
  NSString *result = [str stringByReplacingOccurrencesOfString:@"\\\""
                                                    withString:@"\""];
  result = [result stringByReplacingOccurrencesOfString:@"\""
                                             withString:@"\\\""];
  result = [result stringByReplacingOccurrencesOfString:@"\n"
                                             withString:@"\\\n"];
  return result;
}

/**
 * Ensures a block of code is executed on the main application thread.
 *
 * @param completeBlock The block to execute.
 */
- (void)runOnMainThread:(void (^)(void))completeBlock {
  if (![NSThread isMainThread]) {
    dispatch_sync(dispatch_get_main_queue(), ^{
      @try {
        completeBlock();
      } @catch (NSException *exception) {
        [self handlePluginExceptionWithoutContext:exception];
      }
    });
  } else {
    @try {
      completeBlock();
    } @catch (NSException *exception) {
      [self handlePluginExceptionWithoutContext:exception];
    }
  }
}

/**
 * Resolves a credential dictionary into a native Firebase AuthCredential
 * object.
 *
 * @param credential The credential dictionary from Javascript.
 * @param command The active Cordova command.
 * @return The native credential object, or nil if invalid.
 */
- (FIRAuthCredential *)obtainAuthCredential:(NSDictionary *)credential
                                    command:(CDVInvokedUrlCommand *)command {
  FIRAuthCredential *authCredential = nil;

  if (credential == nil) {
    NSString *errMsg =
        @"credential object must be passed as first and only argument";
    [self.commandDelegate
        sendPluginResult:[CDVPluginResult
                             resultWithStatus:CDVCommandStatus_ERROR
                              messageAsString:errMsg]
              callbackId:command.callbackId];
    return authCredential;
  }

  NSString *key = [credential objectForKey:@"id"];
  NSString *verificationId = [credential objectForKey:@"verificationId"];
  NSString *code = [credential objectForKey:@"code"];

  if (key != nil) {
    authCredential = [authCredentials objectForKey:key];
    if (authCredential == nil) {
      NSString *errMsg = [NSString
          stringWithFormat:
              @"no native auth credential exists for specified id '%@'", key];
      [self.commandDelegate
          sendPluginResult:[CDVPluginResult
                               resultWithStatus:CDVCommandStatus_ERROR
                                messageAsString:errMsg]
                callbackId:command.callbackId];
    }
  } else if (verificationId != nil && code != nil) {
    authCredential = [[FIRPhoneAuthProvider provider]
        credentialWithVerificationID:verificationId
                    verificationCode:code];
  } else {
    NSString *errMsg =
        @"credential object must either specify the id key of an existing "
        @"native auth credential or the verificationId/code keys must be "
        @"specified for a phone number authentication";
    [self.commandDelegate
        sendPluginResult:[CDVPluginResult
                             resultWithStatus:CDVCommandStatus_ERROR
                              messageAsString:errMsg]
              callbackId:command.callbackId];
  }

  return authCredential;
}

/**
 * Handles the result of a Firebase Auth operation.
 * Sends success or error result back to the webview.
 *
 * @param authResult The authentication result data.
 * @param error The error object, if any.
 * @param command The active Cordova command.
 */
- (void)handleAuthResult:(FIRAuthDataResult *)authResult
                   error:(NSError *)error
                 command:(CDVInvokedUrlCommand *)command {
  @try {
    CDVPluginResult *pluginResult;
    if (error) {
      pluginResult = [self createAuthErrorResult:error];
    } else if (authResult == nil) {
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                       messageAsString:@"User not signed in"];
    } else {
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                         messageAsBool:true];
    }

    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:command.callbackId];
  } @catch (NSException *exception) {
    [self handlePluginExceptionWithContext:exception:command];
  }
}

/**
 * Internal helper to create a structured error result for auth failures.
 * Handles MFA and multi-credential merge flows.
 *
 * @param error The native error.
 * @return A Cordova plugin result.
 */
- (CDVPluginResult *)createAuthErrorResult:(NSError *)error {
  CDVPluginResult *pluginResult;
  if (error.code == FIRAuthErrorCodeSecondFactorRequired) {
    // The user is a multi-factor user. Second factor challenge is required.
    multiFactorResolver =
        (FIRMultiFactorResolver *)
            error.userInfo[FIRAuthErrorUserInfoMultiFactorResolverKey];
    NSMutableArray *secondFactors =
        [self parseEnrolledSecondFactorsToJson:multiFactorResolver.hints];
    NSString *errMessage = @"Second factor required";

    NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
    [result setValue:errMessage forKey:@"errorMessage"];
    [result setValue:secondFactors forKey:@"secondFactors"];

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                 messageAsDictionary:result];
  } else if (error.code == FIRAuthErrorCodeCredentialAlreadyInUse) {
    NSMutableDictionary *userInfo =
        [NSMutableDictionary dictionaryWithDictionary:[error userInfo]];
    FIROAuthCredential *updatedCredential =
        userInfo[FIRAuthErrorUserInfoUpdatedCredentialKey];
    NSMutableDictionary *responseDict = [[NSMutableDictionary alloc] init];

    [responseDict setValue:@(error.code) forKey:@"errorCode"];
    [responseDict setValue:error.domain forKey:@"errorDomain"];
    [responseDict setValue:userInfo.description forKey:@"errorDescription"];
    if (userInfo[FIRAuthErrorUserInfoNameKey]) {
      [responseDict setValue:userInfo[FIRAuthErrorUserInfoNameKey]
                      forKey:FIRAuthErrorUserInfoNameKey];
    }
    if (userInfo[FIRAuthErrorUserInfoEmailKey]) {
      [responseDict setValue:userInfo[FIRAuthErrorUserInfoEmailKey]
                      forKey:FIRAuthErrorUserInfoEmailKey];
    }
    if (userInfo[FIRAuthErrorUserInfoNameKey]) {
      [responseDict setValue:userInfo[FIRAuthErrorUserInfoNameKey]
                      forKey:FIRAuthErrorUserInfoNameKey];
    }

    if (updatedCredential) {
      NSMutableDictionary *updatedCredentialDict =
          [[NSMutableDictionary alloc] init];
      if (updatedCredential.provider) {
        [updatedCredentialDict setValue:updatedCredential.provider
                                 forKey:@"provider"];
      }
      if (updatedCredential.IDToken) {
        [updatedCredentialDict setValue:updatedCredential.IDToken
                                 forKey:@"IDToken"];
      }
      NSNumber *key = [self saveAuthCredential:updatedCredential];
      [updatedCredentialDict setValue:key forKey:@"id"];
      [responseDict setValue:updatedCredentialDict forKey:@"updatedCredential"];
    }

    // TODO: Make messageAsDictionary work with error status- currently it
    // returns undefined
    NSString *jsonString = [[NSString alloc]
        initWithData:[NSJSONSerialization dataWithJSONObject:responseDict
                                                     options:0
                                                       error:nil]
            encoding:NSUTF8StringEncoding];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                     messageAsString:jsonString];
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                     messageAsString:error.description];
  }
  return pluginResult;
}

/**
 * Saves a native auth credential so it can be retrieved later by ID.
 *
 * @param authCredential The native credential.
 * @return A unique numeric ID for the saved credential.
 */
- (NSNumber *)saveAuthCredential:(FIRAuthCredential *)authCredential {
  int id = [self generateId];
  NSNumber *key = [NSNumber numberWithInt:id];
  [authCredentials setObject:authCredential forKey:key];
  return key;
}

/**
 * Checks if a user is currently signed in.
 *
 * @return YES if signed in.
 */
- (bool)isSignedIn {
  return [FIRAuth auth].currentUser ? true : false;
}

/**
 * Checks if a user is signed in and sends an error to the webview if not.
 *
 * @param command The active Cordova command.
 * @return YES if NOT signed in (error sent), NO if signed in.
 */
- (bool)userNotSignedInError:(CDVInvokedUrlCommand *)command {
  bool isError = ![self isSignedIn];
  if (isError) {
    [self.commandDelegate
        sendPluginResult:[CDVPluginResult
                             resultWithStatus:CDVCommandStatus_ERROR
                              messageAsString:@"No user is currently signed"]
              callbackId:command.callbackId];
  }
  return isError;
}

/**
 * Generates a unique numeric ID for use with credentials or listeners.
 *
 * @return A unique integer ID.
 */
- (int)generateId {
  int key = -1;
  while (key < 0 ||
         [authCredentials objectForKey:[NSNumber numberWithInt:key]] != nil ||
         [firestoreListeners
             objectForKey:[NSNumber numberWithInt:key]] != nil) {
    key = arc4random_uniform(100000);
  }
  return key;
}

/**
 * Persists a boolean flag in user defaults.
 *
 * @param name The preference key.
 * @param flag The boolean value.
 */
- (void)setPreferenceFlag:(NSString *)name flag:(BOOL)flag {
  [preferences setBool:flag forKey:name];
  [preferences synchronize];
}

/**
 * Retrieves a boolean flag from user defaults.
 *
 * @param name The preference key.
 * @return The boolean value, or NO if not set.
 */
- (BOOL)getPreferenceFlag:(NSString *)name {
  if ([preferences objectForKey:name] == nil) {
    return false;
  }
  return [preferences boolForKey:name];
}

/**
 * Retrieves a boolean flag from the GoogleService-Info.plist file.
 *
 * @param name The plist key.
 * @param defaultValue The value to return if the key is missing.
 * @return The boolean value from plist or default.
 */
- (BOOL)getGooglePlistFlagWithDefaultValue:(NSString *)name
                              defaultValue:(BOOL)defaultValue {
  if ([googlePlist objectForKey:name] == nil) {
    return defaultValue;
  }
  id value = [googlePlist objectForKey:name];
  if ([value isKindOfClass:[NSNumber class]]) {
    return [value boolValue];
  } else {
    // Note that `isEqualToString` would crash if the value is not a string.
    return [value isEqual:@"true"];
  }
}

#pragma mark - Stubs
/**
 * Stub method for creating a notification channel (Android only feature).
 *
 * @param command The active Cordova command.
 */
- (void)createChannel:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    CDVPluginResult *pluginResult =
        [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:command.callbackId];
  }];
}

/**
 * Stub method for setting the default notification channel (Android only
 * feature).
 *
 * @param command The active Cordova command.
 */
- (void)setDefaultChannel:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    CDVPluginResult *pluginResult =
        [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:command.callbackId];
  }];
}

/**
 * Stub method for deleting a notification channel (Android only feature).
 *
 * @param command The active Cordova command.
 */
- (void)deleteChannel:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    CDVPluginResult *pluginResult =
        [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:command.callbackId];
  }];
}

/**
 * Stub method for listing notification channels (Android only feature).
 *
 * @param command The active Cordova command.
 */
- (void)listChannels:(CDVInvokedUrlCommand *)command {
  [self.commandDelegate runInBackground:^{
    CDVPluginResult *pluginResult =
        [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:command.callbackId];
  }];
}

@end
