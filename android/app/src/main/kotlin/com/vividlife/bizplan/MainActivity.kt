package com.vividlife.bizplan

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.util.Log

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.vividlife.bizPlan/widget"
    private var methodChannel: MethodChannel? = null
    private var pendingScheduleId: Int? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            if (call.method == "getScheduleId") {
                Log.d("MainActivity", "getScheduleId called, returning: $pendingScheduleId")
                result.success(pendingScheduleId)
                pendingScheduleId = null  // 한 번 읽은 후 초기화
            } else {
                result.notImplemented()
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
}
