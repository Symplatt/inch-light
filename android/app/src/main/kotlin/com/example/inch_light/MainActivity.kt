package com.example.inch_light

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.job.JobScheduler
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
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
