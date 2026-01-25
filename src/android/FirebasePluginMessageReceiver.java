package org.apache.cordova.firebase;

import android.os.Bundle;

import com.google.firebase.messaging.RemoteMessage;

/**
 * Abstract class for receiving and handling Firebase messages.
 * Subclasses can register themselves to intercept and process incoming 
 * FCM messages or notification bundles before they are processed by 
 * the main plugin.
 */
public abstract class FirebasePluginMessageReceiver {

    /**
     * Constructor. 
     * Automatically registers this receiver with the manager.
     */
    public FirebasePluginMessageReceiver() {
        FirebasePluginMessageReceiverManager.register(this);
    }

    /**
     * Concrete subclasses should override this and return true if they handle the received message.
     * Intercepts the raw RemoteMessage from FCM.
     *
     * @param remoteMessage Object representing the message received from Firebase Cloud Messaging.
     * @return true if the received message was handled by the receiver and should not be processed further.
     */
    public abstract boolean onMessageReceived(RemoteMessage remoteMessage);

    /**
     * Concrete subclasses should override this and return true if they handle the message bundle before it's sent to FirebasePlugin.sendMessage().
     * Intercepts the data Bundle before it is sent to the Javascript layer.
     *
     * @param bundle The notification data bundle.
     * @return true if the received bundle was handled by the receiver and should not be processed further.
     */
    public abstract boolean sendMessage(Bundle bundle);
}
