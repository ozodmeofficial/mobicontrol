package uz.mobicontrol.mobicontrol

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.accessibility.AccessibilityEvent
import android.view.inputmethod.InputMethodManager
import java.util.Calendar

/**
 * Oldingi planga chiqqan ilovani kuzatadi va agar u hozir ruxsat etilgan
 * vaqtdan tashqarida bo'lsa, bloklash ekranini ko'rsatadi.
 */
class AppBlockerService : AccessibilityService() {
    private val handler = Handler(Looper.getMainLooper())
    private var rules: Map<String, AppRule> = emptyMap()
    private var currentPackage: String? = null
    private var lastBlockedPackage: String? = null
    private var lastBlockedAt = 0L

    private val prefsListener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
        if (key == RuleStore.KEY_RULES) {
            rules = RuleStore.load(this)
            currentPackage?.let { check(it) }
        }
    }

    /** Ilova ochiq turgan paytda ruxsat vaqti tugasa ham bloklash uchun davriy tekshiruv. */
    private val periodicCheck = object : Runnable {
        override fun run() {
            currentPackage?.let { check(it) }
            handler.postDelayed(this, CHECK_INTERVAL_MS)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        rules = RuleStore.load(this)
        RuleStore.prefs(this).registerOnSharedPreferenceChangeListener(prefsListener)
        handler.postDelayed(periodicCheck, CHECK_INTERVAL_MS)
    }

    override fun onDestroy() {
        handler.removeCallbacks(periodicCheck)
        RuleStore.prefs(this).unregisterOnSharedPreferenceChangeListener(prefsListener)
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return
        if (pkg == packageName) {
            // Bloklash ekrani yoki MobiControl'ning o'zi ochiq — tekshiradigan narsa yo'q.
            currentPackage = null
            return
        }
        if (isIgnored(pkg)) return
        currentPackage = pkg
        check(pkg)
    }

    override fun onInterrupt() {}

    private fun isIgnored(pkg: String): Boolean {
        if (pkg == "com.android.systemui") return true
        // Klaviatura oynalari oldingi ilovani "yashirmasligi" kerak.
        val imm = getSystemService(InputMethodManager::class.java) ?: return false
        return imm.enabledInputMethodList.any { it.packageName == pkg }
    }

    private fun check(pkg: String) {
        val rule = rules[pkg] ?: return
        if (rule.isAllowedAt(Calendar.getInstance())) return

        val now = SystemClock.elapsedRealtime()
        if (pkg == lastBlockedPackage && now - lastBlockedAt < DEBOUNCE_MS) return
        lastBlockedPackage = pkg
        lastBlockedAt = now

        performGlobalAction(GLOBAL_ACTION_HOME)
        startActivity(
            Intent(this, BlockActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                .putExtra(BlockActivity.EXTRA_APP_NAME, rule.appName)
                .putExtra(BlockActivity.EXTRA_SCHEDULE, rule.scheduleLabel)
        )
    }

    companion object {
        private const val CHECK_INTERVAL_MS = 15_000L
        private const val DEBOUNCE_MS = 1_500L
    }
}
