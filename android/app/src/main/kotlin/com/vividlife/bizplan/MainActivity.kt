package com.vividlife.bizplan

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.util.Log
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.vividlife.bizplan/widget"
    private var methodChannel: MethodChannel? = null
    private var pendingScheduleId: Int? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Edge-to-edge 활성화 (Android 15+ 권장사항)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            WindowCompat.setDecorFitsSystemWindows(window, false)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getScheduleId" -> {
                    Log.d("MainActivity", "getScheduleId called, returning: $pendingScheduleId")
                    result.success(pendingScheduleId)
                    pendingScheduleId = null  // 한 번 읽은 후 초기화
                }
                "updateWidget" -> {
                    updateWidgets()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Flutter 엔진이 준비되면 pending intent 처리
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)  // 중요: 새 intent를 설정
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        Log.d("MainActivity", "handleIntent called with intent: $intent")
        if (intent?.hasExtra("schedule_id") == true) {
            val scheduleId = intent.getIntExtra("schedule_id", -1)
            Log.d("MainActivity", "Found schedule_id: $scheduleId")
            if (scheduleId > 0) {
                pendingScheduleId = scheduleId
                // Flutter에 알림
                methodChannel?.invokeMethod("openSchedule", scheduleId)
            }
        }
    }

    private fun updateWidgets() {
        try {
            val appWidgetManager = AppWidgetManager.getInstance(this)

            // 작은 위젯 업데이트
            val smallWidgetIds = appWidgetManager.getAppWidgetIds(
                ComponentName(this, ScheduleWidgetProvider::class.java)
            )
            if (smallWidgetIds.isNotEmpty()) {
                val intent = Intent(this, ScheduleWidgetProvider::class.java)
                intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, smallWidgetIds)
                sendBroadcast(intent)
                Log.d("MainActivity", "Updated ${smallWidgetIds.size} small widgets")
            }

            // 큰 위젯 업데이트
            val largeWidgetIds = appWidgetManager.getAppWidgetIds(
                ComponentName(this, ScheduleWidgetLargeProvider::class.java)
            )
            if (largeWidgetIds.isNotEmpty()) {
                val intent = Intent(this, ScheduleWidgetLargeProvider::class.java)
                intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, largeWidgetIds)
                sendBroadcast(intent)
                Log.d("MainActivity", "Updated ${largeWidgetIds.size} large widgets")
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Error updating widgets", e)
        }
    }
}
