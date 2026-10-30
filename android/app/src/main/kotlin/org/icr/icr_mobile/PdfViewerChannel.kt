package org.icr.icr_mobile

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Reads a PDF the app already holds in memory and draws its pages as PNG, for the library's viewer.
 *
 * `open(bytes)` -> `{id, sizes: [[w, h], ...]}`, `render(id, page, width)` -> PNG bytes, `close(id)`.
 *
 * PdfRenderer needs a seekable file descriptor, so the bytes are written to a private cache file that is
 * deleted the moment it is open: the descriptor keeps it readable and nothing is left on disk (not even if
 * the app is killed), so there is no file for anyone to collect. PdfRenderer allows one page open at a
 * time, so every call runs on one worker thread.
 */
class PdfViewerChannel(
    private val activity: Activity,
    private val cacheDir: File,
) : MethodChannel.MethodCallHandler {
    private class Opened(val renderer: PdfRenderer, val descriptor: ParcelFileDescriptor)

    private val opened = ConcurrentHashMap<String, Opened>()
    private val worker = Executors.newSingleThreadExecutor()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "open" -> {
                val bytes = call.argument<ByteArray>("bytes")
                if (bytes == null) result.error("bad_args", "No bytes.", null) else run(result) { open(bytes) }
            }
            "render" -> {
                val id = call.argument<String>("id")
                val page = call.argument<Int>("page")
                val width = call.argument<Int>("width")
                if (id == null || page == null || width == null) {
                    result.error("bad_args", "Missing arguments.", null)
                } else {
                    run(result) { render(id, page, width) }
                }
            }
            "close" -> {
                val id = call.argument<String>("id")
                if (id != null) worker.execute { close(id) }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun run(result: MethodChannel.Result, body: () -> Any?) {
        worker.execute {
            try {
                val value = body()
                activity.runOnUiThread { result.success(value) }
            } catch (e: SecurityException) {
                // PdfRenderer's way of saying the file is password protected.
                activity.runOnUiThread { result.error("password", "This PDF is password protected.", null) }
            } catch (e: IOException) {
                activity.runOnUiThread { result.error("unreadable", "This PDF can't be read.", null) }
            } catch (e: Exception) {
                activity.runOnUiThread { result.error("unreadable", e.message ?: "This PDF can't be read.", null) }
            }
        }
    }

    private fun open(bytes: ByteArray): Map<String, Any> {
        val file = File.createTempFile("view", ".pdf", cacheDir)
        val descriptor: ParcelFileDescriptor
        try {
            file.outputStream().use { it.write(bytes) }
            descriptor = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        } finally {
            file.delete()
        }
        val renderer: PdfRenderer
        try {
            renderer = PdfRenderer(descriptor)
        } catch (e: Exception) {
            descriptor.close()
            throw e
        }
        val sizes = ArrayList<List<Int>>(renderer.pageCount)
        for (i in 0 until renderer.pageCount) {
            renderer.openPage(i).use { sizes.add(listOf(it.width, it.height)) }
        }
        val id = UUID.randomUUID().toString()
        opened[id] = Opened(renderer, descriptor)
        return mapOf("id" to id, "sizes" to sizes)
    }

    private fun render(id: String, index: Int, width: Int): ByteArray {
        val doc = opened[id] ?: throw IOException("closed")
        doc.renderer.openPage(index).use { page ->
            val w = max(1, width)
            val h = max(1, (w.toFloat() * page.height / page.width).roundToInt())
            val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            try {
                bitmap.eraseColor(Color.WHITE)
                page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                val out = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                return out.toByteArray()
            } finally {
                bitmap.recycle()
            }
        }
    }

    private fun close(id: String) {
        val doc = opened.remove(id) ?: return
        try { doc.renderer.close() } catch (_: Exception) {}
        try { doc.descriptor.close() } catch (_: Exception) {}
    }

    fun closeAll() {
        worker.execute { opened.keys.toList().forEach { close(it) } }
        worker.shutdown()
    }
}
