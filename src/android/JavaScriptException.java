package org.apache.cordova.firebase;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

/**
 * Exception class to wrap and log Javascript-based exceptions with a native stack trace.
 * This allows Javascript errors to be reported to Crashlytics with structured trace data.
 *
 * @author sagrawal31
 */
public class JavaScriptException extends Exception {

    /**
     * Constructor for a simple message-based exception.
     *
     * @param message The error message.
     */
    public JavaScriptException(String message) {
        super(message);
    }

    /**
     * Constructor that parses a Javascript stack trace into native elements.
     *
     * @param message The error message.
     * @param stackTrace JSONArray of stack trace elements from stacktrace.js.
     * @throws JSONException if parsing the stack trace fails.
     */
    public JavaScriptException(String message, JSONArray stackTrace) throws JSONException {
        super(message);
        this.handleStacktrace(stackTrace);
    }

    /**
     * Internal helper to convert a JSONArray of stack elements into native StackTraceElements.
     *
     * @param stackTrace The source stack trace.
     * @throws JSONException if parsing fails.
     */
    private void handleStacktrace(JSONArray stackTrace) throws JSONException {
        if (stackTrace == null) {
            return;
        }

        StackTraceElement[] trace = new StackTraceElement[stackTrace.length()];

        for (int i = 0; i < stackTrace.length(); i++) {
            JSONObject elem = stackTrace.getJSONObject(i);

            trace[i] = new StackTraceElement(
                    "undefined",
                    elem.optString("functionName", "undefined"),
                    elem.optString("fileName", "undefined"),
                    elem.optInt("lineNumber", -1)
            );
        }

        this.setStackTrace(trace);
    }
}
