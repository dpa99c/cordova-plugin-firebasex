package org.apache.cordova.firebase;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;

public class OnNotificationActionReceiver extends BroadcastReceiver {

    private static final String TAG = "FirebasePlugin";

    @Override
    public void onReceive(Context context, Intent intent) {
        try {
            String action = intent.getAction();
            Bundle data = intent.getExtras();

            if (data == null) {
                Log.e(TAG, "OnNotificationActionReceiver: data is null");
                return;
            }

            Log.d(TAG, "OnNotificationActionReceiver.onReceive(): action=" + action + ", data=" + data.toString());

            // Add the action identifier to the bundle
            if ("EMERGENCY_CONFIRM".equals(action)) {
                data.putString("action", "confirm");
                String confirmUrl = data.getString("confirmUrl");
                if (confirmUrl != null && !confirmUrl.isEmpty()) {
                    // Open the confirm URL
                    Intent urlIntent = new Intent(Intent.ACTION_VIEW, Uri.parse(confirmUrl));
                    urlIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    context.startActivity(urlIntent);
                }
            } else if ("EMERGENCY_CANCEL".equals(action)) {
                data.putString("action", "cancel");
                String cancelUrl = data.getString("cancelUrl");
                if (cancelUrl != null && !cancelUrl.isEmpty()) {
                    // Open the cancel URL
                    Intent urlIntent = new Intent(Intent.ACTION_VIEW, Uri.parse(cancelUrl));
                    urlIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    context.startActivity(urlIntent);
                }
            }

            // Set tap location
            data.putString("tap", FirebasePlugin.inBackground() ? "background" : "foreground");

            // Send the message to the plugin
            FirebasePlugin.sendMessage(data, context);

        } catch (Exception e) {
            FirebasePlugin.handleExceptionWithoutContext(e);
        }
    }
}
