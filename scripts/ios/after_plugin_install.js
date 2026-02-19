var helper = require("./helper");

module.exports = function(context) {

    // Crashlytics build phase has been removed since FirebaseCrashlytics pod is no longer included
    var xcodeProjectPath = helper.getXcodeProjectPath();
    helper.removeShellScriptBuildPhase(context, xcodeProjectPath);
    // helper.addShellScriptBuildPhase(context, xcodeProjectPath); // Commented out - Crashlytics removed
    helper.addGoogleTagManagerContainer(context, xcodeProjectPath);
};
