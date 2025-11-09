package com.vividlife.bizplan

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import android.view.View
import android.content.Intent
import android.app.PendingIntent

class ScheduleWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.schedule_widget)

                // SharedPreferences에서 데이터 읽기
                val widgetData = HomeWidgetPlugin.getData(context)

                // 배경색과 텍스트 색상 가져오기
                val backgroundColor = try {
                    widgetData.getLong("widget_background_color", android.graphics.Color.WHITE.toLong()).toInt()
                } catch (e: Exception) {
                    android.graphics.Color.WHITE
                }
                val textColor = try {
                    widgetData.getLong("widget_text_color", android.graphics.Color.BLACK.toLong()).toInt()
                } catch (e: Exception) {
                    android.graphics.Color.BLACK
                }

                // 위젯 배경색 설정
                views.setInt(R.id.widget_root, "setBackgroundColor", backgroundColor)

                // 날짜 정보 설정 (기본값 제공)
                val currentMonth = widgetData.getString("current_month", "월")
                val currentDate = widgetData.getString("current_date", "0")
                val currentDay = widgetData.getString("current_day", "요일")
                val scheduleCount = try {
                    widgetData.getLong("schedule_count", 0).toInt()
                } catch (e: Exception) {
                    0
                }

                views.setTextViewText(R.id.current_month, currentMonth ?: "월")
                views.setTextViewText(R.id.current_date, currentDate ?: "0")
                views.setTextViewText(R.id.current_day, currentDay ?: "요일")

                // 날짜 텍스트 색상 설정
                views.setTextColor(R.id.current_month, textColor)
                views.setTextColor(R.id.current_date, textColor)
                views.setTextColor(R.id.current_day, textColor)

            // 스케줄이 없을 때
            if (scheduleCount == 0) {
                views.setViewVisibility(R.id.no_schedule_text, View.VISIBLE)
                views.setTextColor(R.id.no_schedule_text, textColor)
                views.setViewVisibility(R.id.schedule_1_container, View.GONE)
                views.setViewVisibility(R.id.schedule_2_container, View.GONE)
                views.setViewVisibility(R.id.schedule_3_container, View.GONE)
            } else {
                views.setViewVisibility(R.id.no_schedule_text, View.GONE)

                // 스케줄 1
                if (scheduleCount >= 1) {
                    val time1 = widgetData.getString("schedule_0_time", "미정") ?: "미정"
                    val title1 = widgetData.getString("schedule_0_title", "스케줄") ?: "스케줄"
                    val status1 = widgetData.getString("schedule_0_status", "예정") ?: "예정"
                    val scheduleId1 = try {
                        widgetData.getLong("schedule_0_id", 0).toInt()
                    } catch (e: Exception) {
                        0
                    }

                    views.setViewVisibility(R.id.schedule_1_container, View.VISIBLE)
                    views.setTextViewText(R.id.schedule_1_time, time1)
                    views.setTextViewText(R.id.schedule_1_title, title1)

                    // 텍스트 색상 설정
                    views.setTextColor(R.id.schedule_1_time, textColor)
                    views.setTextColor(R.id.schedule_1_title, textColor)

                    // 상태에 따른 색상 설정
                    val color1 = when (status1) {
                        "확정" -> android.graphics.Color.parseColor("#2196F3")
                        else -> android.graphics.Color.parseColor("#FF9800")
                    }
                    views.setInt(R.id.schedule_1_indicator, "setBackgroundColor", color1)

                    // 스케줄 클릭 시 상세보기로 이동
                    val scheduleIntent1 = Intent(context, MainActivity::class.java).apply {
                        action = Intent.ACTION_VIEW
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        putExtra("schedule_id", scheduleId1)
                    }
                    val schedulePendingIntent1 = PendingIntent.getActivity(
                        context,
                        scheduleId1,
                        scheduleIntent1,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.schedule_1_container, schedulePendingIntent1)
                } else {
                    views.setViewVisibility(R.id.schedule_1_container, View.GONE)
                }

                // 스케줄 2
                if (scheduleCount >= 2) {
                    val time2 = widgetData.getString("schedule_1_time", "미정") ?: "미정"
                    val title2 = widgetData.getString("schedule_1_title", "스케줄") ?: "스케줄"
                    val status2 = widgetData.getString("schedule_1_status", "예정") ?: "예정"
                    val scheduleId2 = try {
                        widgetData.getLong("schedule_1_id", 0).toInt()
                    } catch (e: Exception) {
                        0
                    }

                    views.setViewVisibility(R.id.schedule_2_container, View.VISIBLE)
                    views.setTextViewText(R.id.schedule_2_time, time2)
                    views.setTextViewText(R.id.schedule_2_title, title2)

                    // 텍스트 색상 설정
                    views.setTextColor(R.id.schedule_2_time, textColor)
                    views.setTextColor(R.id.schedule_2_title, textColor)

                    val color2 = when (status2) {
                        "확정" -> android.graphics.Color.parseColor("#2196F3")
                        else -> android.graphics.Color.parseColor("#FF9800")
                    }
                    views.setInt(R.id.schedule_2_indicator, "setBackgroundColor", color2)

                    // 스케줄 클릭 시 상세보기로 이동
                    val scheduleIntent2 = Intent(context, MainActivity::class.java).apply {
                        action = Intent.ACTION_VIEW
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        putExtra("schedule_id", scheduleId2)
                    }
                    val schedulePendingIntent2 = PendingIntent.getActivity(
                        context,
                        scheduleId2,
                        scheduleIntent2,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.schedule_2_container, schedulePendingIntent2)
                } else {
                    views.setViewVisibility(R.id.schedule_2_container, View.GONE)
                }

                // 스케줄 3
                if (scheduleCount >= 3) {
                    val time3 = widgetData.getString("schedule_2_time", "미정") ?: "미정"
                    val title3 = widgetData.getString("schedule_2_title", "스케줄") ?: "스케줄"
                    val status3 = widgetData.getString("schedule_2_status", "예정") ?: "예정"
                    val scheduleId3 = try {
                        widgetData.getLong("schedule_2_id", 0).toInt()
                    } catch (e: Exception) {
                        0
                    }

                    views.setViewVisibility(R.id.schedule_3_container, View.VISIBLE)
                    views.setTextViewText(R.id.schedule_3_time, time3)
                    views.setTextViewText(R.id.schedule_3_title, title3)

                    // 텍스트 색상 설정
                    views.setTextColor(R.id.schedule_3_time, textColor)
                    views.setTextColor(R.id.schedule_3_title, textColor)

                    val color3 = when (status3) {
                        "확정" -> android.graphics.Color.parseColor("#2196F3")
                        else -> android.graphics.Color.parseColor("#FF9800")
                    }
                    views.setInt(R.id.schedule_3_indicator, "setBackgroundColor", color3)

                    // 스케줄 클릭 시 상세보기로 이동
                    val scheduleIntent3 = Intent(context, MainActivity::class.java).apply {
                        action = Intent.ACTION_VIEW
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        putExtra("schedule_id", scheduleId3)
                    }
                    val schedulePendingIntent3 = PendingIntent.getActivity(
                        context,
                        scheduleId3,
                        scheduleIntent3,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.schedule_3_container, schedulePendingIntent3)
                } else {
                    views.setViewVisibility(R.id.schedule_3_container, View.GONE)
                }
            }

                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
