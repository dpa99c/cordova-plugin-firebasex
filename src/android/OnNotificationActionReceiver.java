package org.apache.cordova.firebase;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;

import java.io.IOException;
import java.net.HttpURLConnection;
import java.net.URL;

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
                    // Make HTTP GET request to track the confirm action
                    makeHttpGetRequest(confirmUrl, "Confirm");
                }
            } else if ("EMERGENCY_CANCEL".equals(action)) {
                data.putString("action", "cancel");
                String cancelUrl = data.getString("cancelUrl");
                if (cancelUrl != null && !cancelUrl.isEmpty()) {
                    // Make HTTP GET request to track the cancel action
                    makeHttpGetRequest(cancelUrl, "Cancel");
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

    private void makeHttpGetRequest(final String urlString, final String actionName) {
        new Thread(new Runnable() {
            @Override
            public void run() {
                HttpURLConnection connection = null;
                try {
                    URL url = new URL(urlString);
                    connection = (HttpURLConnection) url.openConnection();
                    connection.setRequestMethod("GET");
                    connection.setConnectTimeout(10000); // 10 seconds
                    connection.setReadTimeout(10000);

                    int responseCode = connection.getResponseCode();
                    Log.d(TAG, actionName + " URL requested successfully: " + urlString + " (Status: " + responseCode + ")");

                } catch (IOException e) {
                    Log.e(TAG, actionName + " URL request failed: " + e.getMessage());
                } finally {
                    if (connection != null) {
                        connection.disconnect();
                    }
                }
            }
        }).start();
    }
}
