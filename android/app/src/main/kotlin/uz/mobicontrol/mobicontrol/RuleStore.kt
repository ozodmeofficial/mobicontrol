package uz.mobicontrol.mobicontrol

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import java.util.Calendar

/** Kun ichidagi vaqt oralig'i (daqiqalarda). Dart'dagi TimeWindow bilan bir xil mantiq. */
data class TimeWindow(val start: Int, val end: Int) {
    fun contains(minuteOfDay: Int): Boolean = when {
        start == end -> true
        start < end -> minuteOfDay in start until end
        else -> minuteOfDay >= start || minuteOfDay < end
    }

    val label: String get() = "${format(start)}–${format(end)}"

    private fun format(minutes: Int) = "%02d:%02d".format(minutes / 60, minutes % 60)
}

/** Dart'dagi AppRule bilan bir xil mantiq. Kunlar: 1 = Dushanba ... 7 = Yakshanba. */
data class AppRule(
    val packageName: String,
    val appName: String,
    val enabled: Boolean,
    val days: Set<Int>,
    val windows: List<TimeWindow>,
) {
    fun isAllowedAt(calendar: Calendar): Boolean {
        if (!enabled) return true
        if (isoWeekday(calendar) !in days) return true
        val minute = calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE)
        return windows.any { it.contains(minute) }
    }

    val scheduleLabel: String
        get() = if (windows.isEmpty()) "Bugun ruxsat berilmagan"
        else windows.joinToString(", ") { it.label }

    companion object {
        /** Calendar.DAY_OF_WEEK (1 = Yakshanba) ni ISO (1 = Dushanba) ga o'tkazadi. */
        fun isoWeekday(calendar: Calendar): Int {
            val d = calendar.get(Calendar.DAY_OF_WEEK)
            return if (d == Calendar.SUNDAY) 7 else d - 1
        }
    }
}

object RuleStore {
    private const val PREFS = "mobicontrol_rules"
    const val KEY_RULES = "rules"

    fun prefs(context: Context): SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun loadJson(context: Context): String = prefs(context).getString(KEY_RULES, "[]") ?: "[]"

    fun saveJson(context: Context, json: String) {
        // Saqlashdan oldin JSON to'g'riligini tekshiramiz.
        parse(json)
        prefs(context).edit().putString(KEY_RULES, json).apply()
    }

    fun load(context: Context): Map<String, AppRule> =
        try {
            parse(loadJson(context)).associateBy { it.packageName }
        } catch (e: Exception) {
            emptyMap()
        }

    private fun parse(json: String): List<AppRule> {
        val array = JSONArray(json)
        return (0 until array.length()).map { i ->
            val o = array.getJSONObject(i)
            val days = o.optJSONArray("days")
            val windows = o.optJSONArray("windows")
            AppRule(
                packageName = o.getString("packageName"),
                appName = o.optString("appName", o.getString("packageName")),
                enabled = o.optBoolean("enabled", true),
                days = if (days == null) (1..7).toSet()
                else (0 until days.length()).map { days.getInt(it) }.toSet(),
                windows = if (windows == null) emptyList()
                else (0 until windows.length()).map {
                    val w = windows.getJSONObject(it)
                    TimeWindow(w.getInt("start"), w.getInt("end"))
                },
            )
        }
    }
}
