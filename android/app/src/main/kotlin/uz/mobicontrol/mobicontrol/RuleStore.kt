package uz.mobicontrol.mobicontrol

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject
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

/** Umumiy jadval. Dart'dagi Schedule bilan bir xil mantiq. Kunlar: 1 = Dushanba ... 7 = Yakshanba. */
data class Schedule(
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

    val label: String
        get() = if (windows.isEmpty()) "Bugun ruxsat berilmagan"
        else windows.joinToString(", ") { it.label }

    companion object {
        val DISABLED = Schedule(enabled = false, days = emptySet(), windows = emptyList())

        /** Calendar.DAY_OF_WEEK (1 = Yakshanba) ni ISO (1 = Dushanba) ga o'tkazadi. */
        fun isoWeekday(calendar: Calendar): Int {
            val d = calendar.get(Calendar.DAY_OF_WEEK)
            return if (d == Calendar.SUNDAY) 7 else d - 1
        }
    }
}

/** Umumiy jadval va unga bo'ysunadigan ilovalar (paket nomi -> ilova nomi). */
data class Config(val schedule: Schedule, val apps: Map<String, String>) {
    companion object {
        val EMPTY = Config(Schedule.DISABLED, emptyMap())
    }
}

object RuleStore {
    private const val PREFS = "mobicontrol_rules"
    const val KEY_CONFIG = "config"

    fun prefs(context: Context): SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun loadJson(context: Context): String? = prefs(context).getString(KEY_CONFIG, null)

    fun saveJson(context: Context, json: String) {
        // Saqlashdan oldin JSON to'g'riligini tekshiramiz.
        parse(json)
        prefs(context).edit().putString(KEY_CONFIG, json).apply()
    }

    fun load(context: Context): Config =
        try {
            loadJson(context)?.let(::parse) ?: Config.EMPTY
        } catch (e: Exception) {
            Config.EMPTY
        }

    private fun parse(json: String): Config {
        val root = JSONObject(json)
        val s = root.getJSONObject("schedule")
        val days = s.optJSONArray("days")
        val windows = s.optJSONArray("windows")
        val schedule = Schedule(
            enabled = s.optBoolean("enabled", true),
            days = if (days == null) (1..7).toSet()
            else (0 until days.length()).map { days.getInt(it) }.toSet(),
            windows = if (windows == null) emptyList()
            else (0 until windows.length()).map {
                val w = windows.getJSONObject(it)
                TimeWindow(w.getInt("start"), w.getInt("end"))
            },
        )
        val appsJson = root.optJSONArray("apps")
        val apps = if (appsJson == null) emptyMap()
        else (0 until appsJson.length()).associate {
            val a = appsJson.getJSONObject(it)
            val pkg = a.getString("packageName")
            pkg to a.optString("appName", pkg)
        }
        return Config(schedule, apps)
    }
}
