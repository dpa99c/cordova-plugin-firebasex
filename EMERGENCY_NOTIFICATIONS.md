# Emergency Notifications with Action Buttons

This plugin supports emergency notifications with Confirm and Cancel action buttons on both Android and iOS platforms.

## How to Use

To send an emergency notification with action buttons, include the following fields in your FCM message's `data` payload:

```json
{
  "message": {
    "notification": {
      "title": "Emergency Alert",
      "body": "Critical system failure detected"
    },
    "data": {
      "notiType": "emergency",
      "confirmUrl": "https://example.com/confirm",
      "cancelUrl": "https://example.com/cancel",
      "badge": "0",
      "title": "Emergency Alert",
      "body": "Critical system failure detected"
    },
    "token": "DEVICE_TOKEN"
  }
}
```

### Required Fields

- `notiType`: Must be set to `"emergency"` to enable action buttons
- `confirmUrl`: The URL to open when the user taps the "Confirm" button
- `cancelUrl`: The URL to open when the user taps the "Cancel" button

## Platform-Specific Behavior

### Android

On Android, emergency notifications will automatically display "Confirm" and "Cancel" action buttons when `notiType` is set to `"emergency"`. When a user taps either button:

1. The corresponding URL (confirmUrl or cancelUrl) will be opened in the default browser or appropriate app
2. The notification callback will receive the action data with an `action` field set to either `"confirm"` or `"cancel"`

### iOS

On iOS, emergency notifications work as follows:

#### Foreground Notifications
For notifications received while the app is in the foreground with the `notification_foreground` flag set to `true`:
- The plugin will automatically create a local notification with "Confirm" and "Cancel" action buttons
- When tapped, the corresponding URL will be opened
- The notification callback will receive the action data

#### Background Notifications
For notifications received while the app is in the background or not running, to show action buttons you need to include the category in your FCM message:

```json
{
  "message": {
    "notification": {
      "title": "Emergency Alert",
      "body": "Critical system failure detected"
    },
    "data": {
      "notiType": "emergency",
      "confirmUrl": "https://example.com/confirm",
      "cancelUrl": "https://example.com/cancel"
    },
    "apns": {
      "payload": {
        "aps": {
          "category": "EMERGENCY_CATEGORY",
          "alert": {
            "title": "Emergency Alert",
            "body": "Critical system failure detected"
          }
        },
        "confirmUrl": "https://example.com/confirm",
        "cancelUrl": "https://example.com/cancel",
        "notiType": "emergency"
      }
    },
    "token": "DEVICE_TOKEN"
  }
}
```

## Receiving Action Callbacks

In your JavaScript code, you can handle the action callbacks using the `onMessageReceived` callback:

```javascript
FirebasePlugin.onMessageReceived(function(message) {
    console.log("Message type: " + message.messageType);

    if (message.notiType === "emergency" && message.action) {
        if (message.action === "confirm" || message.action === "EMERGENCY_CONFIRM") {
            console.log("User confirmed the emergency");
            console.log("Confirm URL: " + message.confirmUrl);
            // The URL has already been opened, but you can perform additional actions here
        } else if (message.action === "cancel" || message.action === "EMERGENCY_CANCEL") {
            console.log("User cancelled the emergency");
            console.log("Cancel URL: " + message.cancelUrl);
            // The URL has already been opened, but you can perform additional actions here
        }
    }
}, function(error) {
    console.error(error);
});
```

## Example FCM Message

Here's a complete example of an FCM message that works on both Android and iOS:

```json
{
  "message": {
    "notification": {
      "title": "Emergency Alert",
      "body": "Critical system failure detected. Please respond immediately."
    },
    "data": {
      "notiType": "emergency",
      "badge": "0",
      "title": "Emergency Alert",
      "body": "Critical system failure detected. Please respond immediately.",
      "confirmUrl": "https://www.example.com/emergency/confirm?id=12345",
      "cancelUrl": "https://www.example.com/emergency/cancel?id=12345",
      "notification_foreground": "true"
    },
    "apns": {
      "payload": {
        "aps": {
          "category": "EMERGENCY_CATEGORY",
          "alert": {
            "title": "Emergency Alert",
            "body": "Critical system failure detected. Please respond immediately."
          },
          "sound": "default"
        },
        "confirmUrl": "https://www.example.com/emergency/confirm?id=12345",
        "cancelUrl": "https://www.example.com/emergency/cancel?id=12345",
        "notiType": "emergency"
      }
    },
    "android": {
      "ttl": "0s"
    },
    "token": "DEVICE_FCM_TOKEN"
  }
}
```

## Notes

- The URLs will be opened in the device's default browser or appropriate app
- Make sure the URLs are valid and properly formatted (including the protocol, e.g., `https://`)
- You can use custom URL schemes (e.g., `myapp://action`) to handle actions within your app
- The action buttons will only appear when `notiType` is set to `"emergency"`
