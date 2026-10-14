package com.example.inch_light

import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.Date
import android.util.AtomicFile
import java.io.File
import java.util.concurrent.Executors

object BackupRetention {
    val executor = Executors.newSingleThreadExecutor()
    private const val JOB = 3502
    private const val WEEK = 7L * 24 * 60 * 60 * 1000
    private val namePattern = Regex("^inch-light-(\\d{4}-\\d{2}-\\d{2}_\\d{2}-\\d{2}-\\d{2}_\\d{3})\\.json$")

    fun schedule(context: Context) {
        if (savedTree(context) == null) return
        val scheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
        try {
            if (scheduler.getPendingJob(JOB) == null) {
                scheduler.schedule(JobInfo.Builder(JOB, ComponentName(context, BackupCleanupService::class.java))
                    .setPeriodic(6L * 60 * 60 * 1000).setPersisted(true).build())
            }
        } catch (_: Exception) { /* Foreground cleanup still works if background scheduling is unavailable. */ }
        executor.execute { maintain(context) }
    }

    // Atomic private snapshot shares the exact payload produced by manual export.
    fun sync(context: Context, text: String) {
        val file = AtomicFile(File(context.filesDir, "daily-backup.json"))
        val stream = file.startWrite()
        try {
            stream.write(text.toByteArray(Charsets.UTF_8))
            file.finishWrite(stream)
        } catch (error: Exception) {
            file.failWrite(stream)
            throw error
        }
        schedule(context)
    }

    fun write(context: Context, tree: Uri, text: String): String {
        var output: Uri? = null
        try {
            val directory = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
            val stamp = SimpleDateFormat("yyyy-MM-dd_HH-mm-ss_SSS", Locale.ROOT).format(Date())
            val name = "inch-light-$stamp.json"
            output = DocumentsContract.createDocument(context.contentResolver, directory, "application/json", name)
                ?: error("无法创建文件")
            val stream = context.contentResolver.openOutputStream(output, "w") ?: error("无法打开文件")
            stream.use { it.write(text.toByteArray(Charsets.UTF_8)); it.flush() }
            return "/storage/emulated/0/inch-light/$name"
        } catch (error: Exception) {
            output?.let { try { DocumentsContract.deleteDocument(context.contentResolver, it) } catch (_: Exception) {} }
            throw error
        }
    }

    fun maintain(context: Context) {
        val tree = savedTree(context) ?: return
        val prefs = context.getSharedPreferences("data_export", Context.MODE_PRIVATE)
        val day = SimpleDateFormat("yyyy-MM-dd", Locale.ROOT).format(Date())
        try {
            if (prefs.getString("daily_date", null) != day) {
                val file = AtomicFile(File(context.filesDir, "daily-backup.json"))
                val text = file.openRead().use { it.readBytes().toString(Charsets.UTF_8) }
                write(context, tree, text)
                // Only mark success after the complete document is closed; failures retry.
                prefs.edit().putString("daily_date", day).commit()
            }
        } catch (_: Exception) { /* Missing snapshot, revoked grant or full storage: retry on the next check. */ }
        clean(context, tree)
    }

    private fun savedTree(context: Context): Uri? {
        val uri = context.getSharedPreferences("data_export", Context.MODE_PRIVATE)
            .getString("folder", null)?.let(Uri::parse) ?: return null
        return uri.takeIf { context.contentResolver.persistedUriPermissions.any { p -> p.uri == uri && p.isReadPermission && p.isWritePermission } }
    }

    fun clean(context: Context, tree: Uri? = savedTree(context)) {
        if (tree == null) return
        val resolver = context.contentResolver
        val cutoff = System.currentTimeMillis() - WEEK
        val date = SimpleDateFormat("yyyy-MM-dd_HH-mm-ss_SSS", Locale.ROOT).apply { isLenient = false }
        try {
            val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
            val columns = arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME, DocumentsContract.Document.COLUMN_MIME_TYPE)
            resolver.query(children, columns, null, null, null)?.use { cursor ->
                while (cursor.moveToNext()) {
                    // Restrict deletion to this application's timestamped exports, never folders or unrelated files.
                    if (cursor.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR) continue
                    val stamp = namePattern.matchEntire(cursor.getString(1))?.groupValues?.get(1) ?: continue
                    val created = try { date.parse(stamp)?.time } catch (_: Exception) { null } ?: continue
                    if (created < cutoff) {
                        val uri = DocumentsContract.buildDocumentUriUsingTree(tree, cursor.getString(0))
                        try { DocumentsContract.deleteDocument(resolver, uri) } catch (_: Exception) { /* Retry next sweep. */ }
                    }
                }
            }
        } catch (_: Exception) { /* Revoked or unavailable SAF access must not interrupt normal app use. */ }
    }
}

class BackupCleanupService : JobService() {
    override fun onStartJob(params: JobParameters): Boolean {
        BackupRetention.executor.execute {
            BackupRetention.maintain(applicationContext)
            jobFinished(params, false)
        }
        return true
    }
    override fun onStopJob(params: JobParameters) = true
}
