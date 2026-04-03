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
import android.view.WindowManager
import android.view.View
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import androidx.core.content.FileProvider
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.vividlife.bizplan/widget"
    private val CLIPBOARD_CHANNEL = "com.vividlife.bizplan/clipboard"
    private var methodChannel: MethodChannel? = null
    private var pendingScheduleId: Int? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 천지인 키보드 등 조합형 한글 입력 지원을 위한 설정
        // 1. SoftInputMode 설정 - 키보드가 화면을 리사이즈하도록 설정
        window.setSoftInputMode(
            WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE or
            WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_HIDDEN
        )

        // 2. IME 옵션 설정 - 한글 조합형 입력 지원 강화
        // 이 설정으로 천지인 키보드의 ㆍ(아래아) 등 조합 문자가 정상 작동
        window.decorView.apply {
            // IME가 항상 활성화 상태 유지
            importantForAutofill = View.IMPORTANT_FOR_AUTOFILL_YES
        }

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

        // 이미지 클립보드 채널
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CLIPBOARD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "copyTextAndImageToClipboard" -> {
                        val text = call.argument<String>("text") ?: ""
                        val imagePath = call.argument<String>("imagePath")
                        if (imagePath == null) {
                            result.error("INVALID_ARGUMENT", "imagePath is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val file = File(imagePath)
                            if (!file.exists()) {
                                result.error("FILE_NOT_FOUND", "Image file not found: $imagePath", null)
                                return@setMethodCallHandler
                            }
                            val uri = FileProvider.getUriForFile(
                                this,
                                "${applicationContext.packageName}.fileprovider",
                                file
                            )
                            val ext = imagePath.substringAfterLast('.').lowercase()
                            val mimeType = if (ext == "png") "image/png" else "image/jpeg"
                            // 텍스트와 이미지를 하나의 ClipData에 담기
                            val clipData = ClipData(
                                "message_with_card",
                                arrayOf("text/plain", mimeType),
                                ClipData.Item(text)
                            )
                            clipData.addItem(ClipData.Item(uri))
                            val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                            clipboard.setPrimaryClip(clipData)
                            Log.d("MainActivity", "Text+Image copied to clipboard: $uri mimeType=$mimeType")
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e("MainActivity", "copyTextAndImageToClipboard failed", e)
                            result.error("CLIPBOARD_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
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
