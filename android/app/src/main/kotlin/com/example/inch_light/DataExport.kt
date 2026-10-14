package com.example.inch_light

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** User-triggered export into the one folder explicitly chosen in Android SAF. */
class DataExport(private val activity: Activity) {
    companion object { const val REQUEST = 3402 }
    private val prefs get() = activity.getSharedPreferences("data_export", Activity.MODE_PRIVATE)
    private var pendingText: String? = null
    private var pendingResult: MethodChannel.Result? = null

    fun export(text: String, result: MethodChannel.Result) {
        if (pendingResult != null) { result.error("busy", "请先完成当前导出", null); return }
        pendingText = text
        pendingResult = result
        val saved = prefs.getString("folder", null)?.let(Uri::parse)
        val granted = activity.contentResolver.persistedUriPermissions.any { it.uri == saved && it.isWritePermission }
        if (saved != null && granted) { write(saved); return }
        try {
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
                if (Build.VERSION.SDK_INT >= 26) putExtra(DocumentsContract.EXTRA_INITIAL_URI,
                    DocumentsContract.buildDocumentUri("com.android.externalstorage.documents", "primary:inch-light"))
            }
            activity.startActivityForResult(intent, REQUEST)
        } catch (error: Exception) { fail("folder", "无法打开文件夹选择器") }
    }

    fun onResult(resultCode: Int, data: Intent?) {
        if (pendingResult == null) return
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { fail("cancelled", "未授权文件夹，文件未保存"); return }
        try {
            if (uri.authority != "com.android.externalstorage.documents" || DocumentsContract.getTreeDocumentId(uri) != "primary:inch-light") {
                fail("folder", "请选择内部存储中的 inch-light 文件夹；不存在时请先新建")
                return
            }
            val flags = data.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            activity.contentResolver.takePersistableUriPermission(uri, flags)
            prefs.edit().putString("folder", uri.toString()).apply()
            write(uri)
        } catch (error: Exception) { fail("permission", "文件夹授权失败，请重试") }
    }

    private fun write(tree: Uri) {
        val result = pendingResult ?: return
        val text = pendingText ?: return
        // SAF providers may block; keep document creation and writing off the UI thread.
        BackupRetention.executor.execute {
            try {
                val path = BackupRetention.write(activity, tree, text)
                activity.runOnUiThread {
                    pendingText = null
                    pendingResult = null
                    result.success(path)
                    BackupRetention.schedule(activity.applicationContext)
                }
            } catch (error: Exception) {
                activity.runOnUiThread {
                    prefs.edit().remove("folder").apply()
                    fail("write", "文件未保存，请重新授权 inch-light 文件夹")
                }
            }
        }
    }

    private fun fail(code: String, message: String) {
        pendingResult?.error(code, message, null)
        pendingResult = null
        pendingText = null
    }
}
