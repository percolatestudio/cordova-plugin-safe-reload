Percolate Studio's Safe Reload Plugin for Meteor / Cordova
----------------------------------------------------------
When Meteor does a Hot Code Push, there is the possiblity of caching an unparseable JS or CSS file on the device.  This will render the application completely broken and the only course of recovery is to uninstall the application.

SafeReload attempts to recover from this situation.  After a window reload event happens, it will check to make sure the JS and CSS are working inside the WebView.  If not, the plugin will revert back to the originally installed binary version by deleting any HCP versions currently installed.

## Usage

Install like `cordova plugin add https://github.com/percolatestudio/cordova-plugin-safe-reload.git`.

No application-level code changes required.  Currently only iOS and Android supported.
