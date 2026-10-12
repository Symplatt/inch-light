package com.example.inch_light

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.job.JobScheduler
import android.content.Intent
import android.os.Bundle
import android.app.Activity
import androidx.core.content.FileProvider
import java.io.File
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private var pendingImage: ByteArray? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "inch_light/note_export")
            .setMethodCallHandler { call, result ->
                if (call.method != "saveImage" && call.method != "shareImage") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val bytes = call.argument<ByteArray>("bytes")
                if (bytes == null || bytes.isEmpty()) {
                    result.error("image", "图片为空", null)
                    return@setMethodCallHandler
                }
                val name = (call.argument<String>("name") ?: "笔记")
                    .replace(Regex("[^\\p{L}\\p{N}_ -]"), "_").take(64).ifBlank { "笔记" } + ".png"
                try {
                    if (call.method == "saveImage") {
                        if (pendingResult != null) {
                            result.error("busy", "请先完成当前保存", null)
                        } else {
                            pendingImage = bytes
                            pendingResult = result
                            startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "image/png"
                                putExtra(Intent.EXTRA_TITLE, name)
                            }, 3401)
                        }
                    } else {
                        val directory = File(cacheDir, "note_exports").apply { mkdirs() }
                        // Only remove our own expired export files; shared URIs stay valid for a day.
                        directory.listFiles()?.filter { System.currentTimeMillis() - it.lastModified() > 86400000 }
                            ?.forEach { it.delete() }
                        val image = File.createTempFile("note_", ".png", directory)
                        image.writeBytes(bytes)
                        val uri = FileProvider.getUriForFile(this, "$packageName.note_exports", image)
                        startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply {
                            type = "image/png"
                            putExtra(Intent.EXTRA_STREAM, uri)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }, "导出长图"))
                        result.success(true)
                    }
                } catch (error: Exception) {
                    pendingImage = null
                    pendingResult = null
                    result.error("export", error.message, null)
                }
            }
    }

    @Deprecated("Android activity result compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 3401) return
        val result = pendingResult ?: return
        val bytes = pendingImage
        pendingResult = null
        pendingImage = null
        if (resultCode != Activity.RESULT_OK || data?.data == null || bytes == null) {
            result.success(false)
            return
        }
        try {
            val stream = contentResolver.openOutputStream(data.data!!)
                ?: throw IllegalStateException("无法打开保存位置")
            stream.use { it.write(bytes) }
            result.success(true)
        } catch (error: Exception) { result.error("save", error.message, null) }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Overlay upgrades must stop the withdrawn backup test build's persisted job.
        (getSystemService(JOB_SCHEDULER_SERVICE) as JobScheduler).cancel(23001)
        getSharedPreferences("local_backup", MODE_PRIVATE).edit().clear().apply()
        // Upgrade cleanup only: cancel alarms created by the retired reminder plugin.
        val prefs = getSharedPreferences("retired_reminders", MODE_PRIVATE)
        if (!prefs.getBoolean("cleared_v2_0_2", false)) {
            val alarms = getSystemService(ALARM_SERVICE) as AlarmManager
            val intent = Intent().setClassName(packageName,
                "com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver")
            for (id in 10000 until 10450) {
                val pending = PendingIntent.getBroadcast(this, id, intent,
                    PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE)
                if (pending != null) {
                    alarms.cancel(pending)
                    pending.cancel()
                }
            }
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).cancelAll()
            prefs.edit().putBoolean("cleared_v2_0_2", true).apply()
        }
    }
}
