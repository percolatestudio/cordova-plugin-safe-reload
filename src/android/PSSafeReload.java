package com.percolatestudio.cordova.safereload;

import java.io.Closeable;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FilterInputStream;
import java.io.IOException;
import java.util.Iterator;
import java.util.Timer;
import java.util.TimerTask;

import org.apache.cordova.Config;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaResourceApi;
import org.apache.cordova.CordovaResourceApi.OpenForReadResult;
import org.apache.cordova.PluginResult;
import org.apache.cordova.file.FileUtils;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.content.Context;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.SystemClock;
import android.util.Log;

public class PSSafeReload extends CordovaPlugin {

    protected static final String LOG_TAG = "PSSafeReload";
    protected static final float SR_HEALTH_CHECK_INTERVAL = 1.0f;
    protected static final float SR_HEALTH_CHECK_TIMEOUT = 10.0f;

    protected Timer reloadTimer;
    protected TimerTask reloadTimerTask;
    protected long timerStartedAt;
    protected String appBundleRootUrl;
    protected final Handler handler = new Handler();


    public Object onMessage(String id, Object data) {
        if (id.equals("onPageFinished")) {
            String currentUrl = (String)data;
            Log.d(LOG_TAG, "SafeReload pageDidLoad " + currentUrl);
        
            if (appBundleRootUrl == null
                && currentUrl.startsWith("file://")) {
                appBundleRootUrl = currentUrl;
            }
            else if (currentUrl.contains("meteor.local")) {
                // start the reload timer if we are loading from our local meteor app
                startTimer();
            }
        }
        return null;
    }

    protected void startTimer() {
        cancelTimer();

        reloadTimer = new Timer();
        initializeTimerTask();
        
        reloadTimer.schedule(reloadTimerTask, (long)(1000*SR_HEALTH_CHECK_INTERVAL), (long)(1000*SR_HEALTH_CHECK_INTERVAL));
        timerStartedAt = SystemClock.elapsedRealtime();
    }

    protected void cancelTimer() {
        if (reloadTimer != null) {
            reloadTimer.cancel();
            reloadTimer = null;
        }
    }

    protected void initializeTimerTask() {
        reloadTimerTask = new TimerTask() {
            public void run() {
                handler.post(new Runnable() {
                    public void run() {
                        performHealthCheck();
                    }
                });
            }
        };
    }

    protected void performHealthCheck() {
        long elapsedTime = SystemClock.elapsedRealtime() - timerStartedAt;
        if (elapsedTime > 1000*SR_HEALTH_CHECK_TIMEOUT) {
            healthCheckFailed();
        }
        else {
            String healthCheckJs =
            "(function () { " +
                "if (typeof Package === 'undefined' || " +
                    "! Package['percolate:safe-reload'] || " +
                    "! Package['percolate:safe-reload'].SafeReload || " + 
                    "! Package['percolate:safe-reload'].SafeReload.healthy() ) { " + 
                    "return 'failed'; " +
                "} " +
                "else { " +
                    "return 'passed'; " +
                "} " +
            "})();";
            // TODO sendJavascript is a deprecated API, but no sign of it being removed yet.
            // The alternative at this point is a bit complicated...
            webView.sendJavascript(healthCheckJs);
            Log.d(LOG_TAG, "SafeReload healthCheck pending...");
        }
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        if (action.equals("bridgeHealthCheckPassed")) {
            healthCheckPassed();
            callbackContext.success();
            return true;
        }
        if (action.equals("bridgeHealthCheckFailed")) {
            healthCheckFailed();
            callbackContext.success();
            return true;
        }
        return false;
    }

    protected void healthCheckPassed() {
        Log.d(LOG_TAG, "SafeReload healthCheckPassed");
        cancelTimer();
    }

    protected void healthCheckFailed() {
        Log.d(LOG_TAG, "SafeReload healthCheckFailed");
        Log.d(LOG_TAG, "This is likely due to a broken Hot Code Push.");
        cancelTimer();
        if (trashCurrentVersion()) {       
            if (appBundleRootUrl != null) {
                webView.loadUrlIntoView(appBundleRootUrl, true);
            }
            else if (webView.canGoBack()) {
                webView.backHistory();
            }
        }
    }

    protected boolean trashCurrentVersion() {
        Context ctx = cordova.getActivity();
        String filesDir = Uri.fromFile(ctx.getFilesDir()).getPath();
        String meteorAppPath = filesDir + "/meteor";
        String versionFilePath = meteorAppPath + "/version";

        boolean success = false;
        File versionFile = new File(versionFilePath);
        if (versionFile.exists()) {
            Log.d(LOG_TAG, "SafeReload Removing cached version at " + versionFilePath);
            success = versionFile.delete();
            if (!success) {
                Log.d(LOG_TAG, "SafeReload Error removing file");
            }
        }
        else {
            Log.d(LOG_TAG, "SafeReload No versions to remove, uh oh." + versionFilePath);
        }
        return success;
    }
}
