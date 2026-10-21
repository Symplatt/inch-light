package com.example.inch_light

import android.app.Activity
import android.content.Intent
import android.provider.DocumentsContract
import io.flutter.plugin.common.MethodChannel

class DataImport(private val activity: Activity) {
    companion object { const val REQUEST = 3501 }
    private var pending: MethodChannel.Result? = null

    fun open(result: MethodChannel.Result) {
        if (pending != null) { result.error("busy", "请先完成文件选择", null); return }
        pending = result
        try {
            activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                putExtra(Intent.EXTRA_ALLOW_MULTIPLE, false)
                putExtra(DocumentsContract.EXTRA_INITIAL_URI,
                    DocumentsContract.buildDocumentUri("com.android.externalstorage.documents", "primary:inch-light"))
                type = "*/*"
                putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json", "text/plain", "text/markdown", "text/x-markdown", "application/octet-stream"))
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }, REQUEST)
        } catch (_: Exception) {
            pending = null
            result.error("open", "无法打开文件选择器", null)
        }
    }

    fun onResult(code: Int, data: Intent?) {
        val result = pending ?: return
        pending = null
        // Some document providers return a single selection through ClipData.
        val uri = data?.data ?: data?.clipData?.let {
            if (it.itemCount == 1) it.getItemAt(0).uri else null
        }
        if (code != Activity.RESULT_OK || uri == null) { result.success(null); return }
        BackupRetention.executor.execute {
            try {
                val text = activity.contentResolver.openInputStream(uri)?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }
                    ?: error("无法读取文件")
                activity.runOnUiThread { result.success(text.removePrefix("\uFEFF")) }
            } catch (_: Exception) {
                activity.runOnUiThread { result.error("read", "文件读取失败", null) }
            }
        }
    }
}
