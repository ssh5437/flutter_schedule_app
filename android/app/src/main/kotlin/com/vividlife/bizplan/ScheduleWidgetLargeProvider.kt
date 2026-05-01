package com.vividlife.bizplan

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import android.view.View
import android.content.Intent
import android.app.PendingIntent
import java.util.Calendar
import android.util.Log

class ScheduleWidgetLargeProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.schedule_widget_large)

                // SharedPreferences에서 데이터 읽기
                val widgetData = HomeWidgetPlugin.getData(context)

                // 디버그: 모든 위젯 데이터 키 출력
                Log.d("ScheduleWidgetLarge", "=== All Widget Data Keys ===")
                widgetData.all.forEach { (key, value) ->
                    Log.d("ScheduleWidgetLarge", "Key: $key, Value: $value, Type: ${value?.javaClass?.simpleName}")
                }
                Log.d("ScheduleWidgetLarge", "===========================")

                // 배경색과 텍스트 색상 가져오기 (home_widget는 Long 타입으로 저장함)
                val backgroundColor = try {
                    val color = widgetData.getLong("widget_background_color", android.graphics.Color.WHITE.toLong()).toInt()
                    Log.d("ScheduleWidgetLarge", "배경색 읽기: $color (0x${Integer.toHexString(color)})")
                    color
                } catch (e: Exception) {
                    Log.e("ScheduleWidgetLarge", "배경색 읽기 실패: ${e.message}")
                    android.graphics.Color.WHITE
                }
                val textColor = try {
                    val color = widgetData.getLong("widget_text_color", android.graphics.Color.BLACK.toLong()).toInt()
                    Log.d("ScheduleWidgetLarge", "텍스트색 읽기: $color (0x${Integer.toHexString(color)})")
                    color
                } catch (e: Exception) {
                    Log.e("ScheduleWidgetLarge", "텍스트색 읽기 실패: ${e.message}")
                    android.graphics.Color.BLACK
                }

                // 위젯 배경색 설정
                views.setInt(R.id.widget_root_large, "setBackgroundColor", backgroundColor)
                Log.d("ScheduleWidgetLarge", "배경색 적용 완료: 0x${Integer.toHexString(backgroundColor)}")

                // 월 표시
                val currentMonth = widgetData.getString("calendar_month", "2025년 1월") ?: "2025년 1월"
                views.setTextViewText(R.id.calendar_month, currentMonth)
                views.setTextColor(R.id.calendar_month, textColor)

                // 선택된 날짜 표시
                val selectedDate = widgetData.getString("selected_date_text", "오늘의 스케줄") ?: "오늘의 스케줄"
                views.setTextViewText(R.id.selected_date, selectedDate)
                views.setTextColor(R.id.selected_date, textColor)

                // 요일 헤더 색상 설정 (일요일과 토요일은 다른 색상)
                val weekdayIds = listOf(
                    R.id.day_header_0, // 일
                    R.id.day_header_1, // 월
                    R.id.day_header_2, // 화
                    R.id.day_header_3, // 수
                    R.id.day_header_4, // 목
                    R.id.day_header_5, // 금
                    R.id.day_header_6  // 토
                )

                weekdayIds.forEachIndexed { index, id ->
                    // 배경이 밝으면 어두운 색, 어두우면 밝은 색
                    val weekdayColor = when (index) {
                        0 -> if (textColor == android.graphics.Color.BLACK)
                                android.graphics.Color.parseColor("#FF5252") // 밝은 배경: 빨강
                             else
                                android.graphics.Color.parseColor("#FF8A80") // 어두운 배경: 연한 빨강
                        6 -> if (textColor == android.graphics.Color.BLACK)
                                android.graphics.Color.parseColor("#2196F3") // 밝은 배경: 파랑
                             else
                                android.graphics.Color.parseColor("#64B5F6") // 어두운 배경: 연한 파랑
                        else -> textColor // 평일은 기본 텍스트 색상
                    }
                    views.setTextColor(id, weekdayColor)
                }

                // 현재 달력 생성
                val calendar = Calendar.getInstance()
                val year = calendar.get(Calendar.YEAR)
                val month = calendar.get(Calendar.MONTH)
                val today = calendar.get(Calendar.DAY_OF_MONTH)

                // 이번 달 1일로 설정
                calendar.set(year, month, 1)
                val firstDayOfWeek = calendar.get(Calendar.DAY_OF_WEEK) - 1 // 0=일요일
                val daysInMonth = calendar.getActualMaximum(Calendar.DAY_OF_MONTH)

                // 스케줄이 있는 날짜 가져오기
                val scheduleDatesStr = widgetData.getString("schedule_dates", "") ?: ""
                val scheduleDates = if (scheduleDatesStr.isNotEmpty()) {
                    scheduleDatesStr.split(",").map { it.toIntOrNull() }.filterNotNull().toSet()
                } else {
                    emptySet()
                }

                // 35개 날짜 셀 채우기 (5주 x 7일)
                try {
                    for (i in 0..34) {
                        val dayId = context.resources.getIdentifier("day_$i", "id", context.packageName)
                        if (dayId == 0) continue  // 리소스 못찾으면 건너뜀
                        val dayNumber = i - firstDayOfWeek + 1

                        if (dayNumber in 1..daysInMonth) {
                            val dayText = if (scheduleDates.contains(dayNumber)) {
                                "$dayNumber\n•"
                            } else {
                                dayNumber.toString()
                            }
                            views.setTextViewText(dayId, dayText)
                            if (dayNumber == today) {
                                views.setTextColor(dayId, android.graphics.Color.parseColor("#FFFFFF"))
                                views.setInt(dayId, "setBackgroundColor", android.graphics.Color.parseColor("#FF9800"))
                            } else {
                                views.setTextColor(dayId, textColor)
                                views.setInt(dayId, "setBackgroundColor", android.graphics.Color.parseColor("#00000000"))
                            }
                        } else {
                            views.setTextViewText(dayId, "")
                            views.setInt(dayId, "setBackgroundColor", android.graphics.Color.parseColor("#00000000"))
                        }
                    }
                } catch (e: Exception) {
                    Log.e("ScheduleWidgetLarge", "Calendar fill error: ${e.message}")
                }

                // 스케줄 표시
                val scheduleCount = try {
                    val count = widgetData.getInt("schedule_count", 0)
                    Log.d("ScheduleWidget", "Read schedule_count from widget data: $count")
                    count
                } catch (e: Exception) {
                    Log.e("ScheduleWidget", "Error reading schedule_count: ${e.message}")
                    0
                }

                Log.d("ScheduleWidget", "scheduleCount = $scheduleCount")

                if (scheduleCount == 0) {
                    Log.d("ScheduleWidget", "No schedules, showing empty message")
                    views.setViewVisibility(R.id.no_schedule_text, View.VISIBLE)
                    views.setTextColor(R.id.no_schedule_text, textColor)
                    views.setViewVisibility(R.id.schedule_1_container, View.GONE)
                    views.setViewVisibility(R.id.schedule_2_container, View.GONE)
                    views.setViewVisibility(R.id.schedule_3_container, View.GONE)
                } else {
                    Log.d("ScheduleWidget", "Has schedules: $scheduleCount")
                    views.setViewVisibility(R.id.no_schedule_text, View.GONE)

                    // 스케줄 1
                    if (scheduleCount >= 1) {
                        val time1 = widgetData.getString("schedule_0_time", "미정") ?: "미정"
                        val title1 = widgetData.getString("schedule_0_title", "스케줄") ?: "스케줄"
                        val status1 = widgetData.getString("schedule_0_status", "예정") ?: "예정"
                        Log.d("ScheduleWidget", "Schedule 1: $time1 - $title1 ($status1)")
                        val scheduleId1 = try {
                            widgetData.getInt("schedule_0_id", 0)
                        } catch (e: Exception) {
                            0
                        }

                        views.setViewVisibility(R.id.schedule_1_container, View.VISIBLE)
                        views.setTextViewText(R.id.schedule_1_time, time1)
                        views.setTextViewText(R.id.schedule_1_title, title1)

                        // 텍스트 색상 설정
                        views.setTextColor(R.id.schedule_1_time, textColor)
                        views.setTextColor(R.id.schedule_1_title, textColor)

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
                            widgetData.getInt("schedule_1_id", 0)
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
                            widgetData.getInt("schedule_2_id", 0)
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

                // 위젯 클릭 시 앱 열기
                val intent = Intent(context, MainActivity::class.java)
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.calendar_month, pendingIntent)

                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
