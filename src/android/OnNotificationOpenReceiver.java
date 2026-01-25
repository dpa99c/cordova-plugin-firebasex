package org.apache.cordova.firebase;

import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.util.Log;

/**
 * BroadcastReceiver that handles the "open" action of a notification.
 * Triggered when a user taps a notification in the system tray.
 */
public class OnNotificationOpenReceiver extends BroadcastReceiver {

    /**
     * Called when the notification is tapped.
     * Launches the main activity and passes the notification data.
     *
     * @param context The application context.
     * @param intent The intent containing notification data.
     */
    @Override
    public void onReceive(Context context, Intent intent) {
        try{
            PackageManager pm = context.getPackageManager();

            Intent launchIntent = pm.getLaunchIntentForPackage(context.getPackageName());
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_NEW_TASK);

            Bundle data = intent.getExtras();
            if(!data.containsKey("messageType")) data.putString("messageType", "notification");
            data.putString("tap", FirebasePlugin.inBackground() ? "background" : "foreground");

            Log.d(FirebasePlugin.TAG, "OnNotificationOpenReceiver.onReceive(): "+data.toString());

            FirebasePlugin.sendMessage(data, context);

            launchIntent.putExtras(data);
            context.startActivity(launchIntent);
        }catch (Exception e){
            FirebasePlugin.handleExceptionWithoutContext(e);
        }
    }
}
