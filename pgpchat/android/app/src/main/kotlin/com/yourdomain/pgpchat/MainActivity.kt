package com.yourdomain.pgpchat

import android.Manifest
import android.app.DownloadManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val SCREENSHOT_CHANNEL = "com.pgpchat/screenshot"
    private val DOWNLOAD_CHANNEL = "com.pgpchat/download"
    private val DOWNLOAD_NOTIFICATION_CHANNEL_ID = "pgpchat_downloads"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Screenshots are enabled
        // window.setFlags(
        //     WindowManager.LayoutParams.FLAG_SECURE,
        //     WindowManager.LayoutParams.FLAG_SECURE
        // )

        ensureDownloadNotificationChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREENSHOT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getScreenshotBlocked" -> result.success(false)
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DOWNLOAD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveTextToDownloads" -> {
                        val fileName = call.argument<String>("fileName")
                        val content = call.argument<String>("content")

                        if (fileName.isNullOrBlank() || content == null) {
                            result.error("INVALID_ARGS", "fileName and content are required", null)
                            return@setMethodCallHandler
                        }

                        saveTextToDownloads(fileName, content, result)
                    }

                    "openDownloads" -> {
                        try {
                            val downloadsIntent = Intent(DownloadManager.ACTION_VIEW_DOWNLOADS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(downloadsIntent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN_DOWNLOADS_FAILED", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun saveTextToDownloads(
        fileName: String,
        content: String,
        result: MethodChannel.Result
    ) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val resolver = applicationContext.contentResolver
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                    put(MediaStore.Downloads.MIME_TYPE, "text/plain")
                    put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                    put(MediaStore.Downloads.IS_PENDING, 1)
                }

                val itemUri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                if (itemUri == null) {
                    result.error("DOWNLOAD_FAILED", "Could not create download entry", null)
                    return
                }

                resolver.openOutputStream(itemUri)?.use { stream ->
                    stream.write(content.toByteArray(Charsets.UTF_8))
                } ?: run {
                    result.error("DOWNLOAD_FAILED", "Could not open download output stream", null)
                    return
                }

                values.clear()
                values.put(MediaStore.Downloads.IS_PENDING, 0)
                resolver.update(itemUri, values, null, null)

                showDownloadNotification(fileName)
                result.success(itemUri.toString())
                return
            }

            val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!downloadsDir.exists()) {
                downloadsDir.mkdirs()
            }

            val file = File(downloadsDir, fileName)
            file.writeText(content, Charsets.UTF_8)

            MediaScannerConnection.scanFile(
                this,
                arrayOf(file.absolutePath),
                arrayOf("text/plain"),
                null
            )

            showDownloadNotification(fileName)
            result.success(file.absolutePath)
        } catch (e: Exception) {
            result.error("DOWNLOAD_FAILED", e.message, null)
        }
    }

    private fun ensureDownloadNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val manager = getSystemService(NotificationManager::class.java)
        val existing = manager.getNotificationChannel(DOWNLOAD_NOTIFICATION_CHANNEL_ID)
        if (existing != null) {
            return
        }

        val channel = NotificationChannel(
            DOWNLOAD_NOTIFICATION_CHANNEL_ID,
            "PGP Downloads",
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = "Notifications for completed PGP key downloads"
        }
        manager.createNotificationChannel(channel)
    }

    private fun showDownloadNotification(fileName: String) {
        try {
            if (
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                return
            }

            val downloadsIntent = Intent(DownloadManager.ACTION_VIEW_DOWNLOADS)
            val pendingIntentFlags =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
            val contentIntent = PendingIntent.getActivity(
                this,
                0,
                downloadsIntent,
                pendingIntentFlags
            )

            val notification = NotificationCompat.Builder(this, DOWNLOAD_NOTIFICATION_CHANNEL_ID)
                .setSmallIcon(android.R.drawable.stat_sys_download_done)
                .setContentTitle("PGP download complete")
                .setContentText("$fileName saved to Downloads")
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setAutoCancel(true)
                .setContentIntent(contentIntent)
                .build()

            val notificationId = (System.currentTimeMillis() % Int.MAX_VALUE).toInt()
            NotificationManagerCompat.from(this).notify(notificationId, notification)
        } catch (_: Exception) {
            // Best-effort only: a download should still succeed even if notification fails.
        }
    }
}
