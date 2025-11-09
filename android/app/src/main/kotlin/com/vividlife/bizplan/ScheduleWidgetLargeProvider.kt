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
                views.setInt(R.id.widget_root_large, "setBackgroundColor", backgroundColor)

                // 월 표시
                val currentMonth = widgetData.getString("calendar_month", "2025년 1월") ?: "2025년 1월"
                views.setTextViewText(R.id.calendar_month, currentMonth)
                views.setTextColor(R.id.calendar_month, textColor)

                // 선택된 날짜 표시
                val selectedDate = widgetData.getString("selected_date_text", "오늘의 스케줄") ?: "오늘의 스케줄"
                views.setTextViewText(R.id.selected_date, selectedDate)
                views.setTextColor(R.id.selected_date, textColor)

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
                for (i in 0..34) {
                    val dayId = context.resources.getIdentifier("day_$i", "id", context.packageName)
                    val dayNumber = i - firstDayOfWeek + 1

                    if (dayNumber in 1..daysInMonth) {
                        // 이번 달 날짜
                        val dayText = if (scheduleDates.contains(dayNumber)) {
                            "$dayNumber\n•"  // 스케줄이 있는 날은 점 추가
                        } else {
                            dayNumber.toString()
                        }
                        views.setTextViewText(dayId, dayText)

                        // 오늘 날짜는 주황색 배경
                        if (dayNumber == today) {
                            views.setTextColor(dayId, android.graphics.Color.parseColor("#FFFFFF"))
                            views.setInt(dayId, "setBackgroundColor", android.graphics.Color.parseColor("#FF9800"))
                        } else {
                            // 일반 날짜
                            views.setTextColor(dayId, android.graphics.Color.parseColor("#333333"))
                            views.setInt(dayId, "setBackgroundColor", android.graphics.Color.parseColor("#00000000"))
                        }
                    } else {
                        // 빈 셀 (이전달/다음달)
                        views.setTextViewText(dayId, "")
                        views.setInt(dayId, "setBackgroundColor", android.graphics.Color.parseColor("#00000000"))
                    }
                }

                // 스케줄 표시
                val scheduleCount = try {
                    widgetData.getLong("schedule_count", 0).toInt()
                } catch (e: Exception) {
                    0
                }

                if (scheduleCount == 0) {
                    views.setViewVisibility(R.id.no_schedule_text, View.VISIBLE)
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
