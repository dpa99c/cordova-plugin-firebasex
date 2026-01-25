package org.apache.cordova.firebase;

import android.os.Bundle;

import com.google.firebase.messaging.RemoteMessage;

import java.util.ArrayList;
import java.util.List;

/**
 * Manager class to track and invoke registered FirebasePluginMessageReceiver instances.
 * Acts as a dispatcher for incoming messages and bundles.
 */
public class FirebasePluginMessageReceiverManager {

    /** List of registered message receivers. */
    private static List<FirebasePluginMessageReceiver> receivers = new ArrayList<FirebasePluginMessageReceiver>();

    /**
     * Registers a new message receiver.
     *
     * @param receiver The receiver instance to add.
     */
    public static void register(FirebasePluginMessageReceiver receiver) {
        receivers.add(receiver);
    }

    /**
     * Dispatches a raw RemoteMessage to all registered receivers.
     *
     * @param remoteMessage The message from FCM.
     * @return true if any receiver handled the message.
     */
    public static boolean onMessageReceived(RemoteMessage remoteMessage) {
        boolean handled = false;
        for (FirebasePluginMessageReceiver receiver : receivers) {
            boolean wasHandled = receiver.onMessageReceived(remoteMessage);
            if (wasHandled) {
                handled = true;
            }
        }

        return handled;
    }

    /**
     * Dispatches a notification data bundle to all registered receivers.
     *
     * @param bundle The notification data bundle.
     * @return true if any receiver handled the bundle.
     */
    public static boolean sendMessage(Bundle bundle) {
        boolean handled = false;
        for (FirebasePluginMessageReceiver receiver : receivers) {
            boolean wasHandled = receiver.sendMessage(bundle);
            if (wasHandled) {
                handled = true;
            }
        }

        return handled;
    }
}
