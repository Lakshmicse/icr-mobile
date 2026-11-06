package org.icr.icr_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * What the Digital Library needs from the phone and Flutter cannot do alone:
 *
 *  - `org.icr.icr_mobile/pdf`: draws a PDF's pages with Android's own PdfRenderer (see [PdfViewerChannel]),
 *    so a document can be read in the app.
 *
 * The window is never marked FLAG_SECURE: screenshots and screen recording are allowed everywhere (owner, 5 Nov
 * 2026, taking off the library's screenshot lock of 28 Oct).
 */
class MainActivity : FlutterActivity() {
    private var pdf: PdfViewerChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        pdf = PdfViewerChannel(this, cacheDir).also {
            MethodChannel(messenger, "org.icr.icr_mobile/pdf").setMethodCallHandler(it)
        }
    }

    override fun onDestroy() {
        pdf?.closeAll()
        super.onDestroy()
    }
}
