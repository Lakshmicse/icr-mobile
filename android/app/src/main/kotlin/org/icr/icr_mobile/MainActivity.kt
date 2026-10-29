package org.icr.icr_mobile

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Two things the Digital Library needs from the phone and Flutter cannot do alone:
 *
 *  - `org.icr.icr_mobile/secure_screen`: FLAG_SECURE on the window while a library screen is up, so the
 *    system refuses screenshots and screen recording and shows a blank card in the recent-apps list.
 *  - `org.icr.icr_mobile/pdf`: draws a PDF's pages with Android's own PdfRenderer (see [PdfViewerChannel]),
 *    so a document can be read in the app without handing the file to another app or saving it.
 */
class MainActivity : FlutterActivity() {
    private var pdf: PdfViewerChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "org.icr.icr_mobile/secure_screen").setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecure" -> {
                    val on = call.argument<Boolean>("on") == true
                    if (on) {
                        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                }
                "isSecure" -> result.success((window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE) != 0)
                else -> result.notImplemented()
            }
        }

        pdf = PdfViewerChannel(this, cacheDir).also {
            MethodChannel(messenger, "org.icr.icr_mobile/pdf").setMethodCallHandler(it)
        }
    }

    override fun onDestroy() {
        pdf?.closeAll()
        super.onDestroy()
    }
}
