package com.wedo.mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.content.Context
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(
                NotificationChannel(
                    "wedo_notifications",
                    "WeDo notifications",
                    NotificationManager.IMPORTANCE_DEFAULT
                )
            )
        }
    }
}
