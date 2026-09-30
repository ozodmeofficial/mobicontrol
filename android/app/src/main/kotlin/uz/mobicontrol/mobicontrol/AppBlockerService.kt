package uz.mobicontrol.mobicontrol

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.telecom.TelecomManager
import android.view.accessibility.AccessibilityEvent
import android.view.inputmethod.InputMethodManager
import java.util.Calendar

/**
 * Oldingi planga chiqqan ilovani kuzatadi va agar u hozir ruxsat etilgan
 * vaqtdan tashqarida bo'lsa, bloklash ekranini ko'rsatadi.
 */
class AppBlockerService : AccessibilityService() {
    private val handler = Handler(Looper.getMainLooper())
    private var config: Config = Config.EMPTY
    private var currentPackage: String? = null
    private var lastBlockedPackage: String? = null
    private var lastBlockedAt = 0L

    private val prefsListener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
        if (key == RuleStore.KEY_CONFIG) {
            config = RuleStore.load(this)
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
        config = RuleStore.load(this)
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

    /**
     * Bosh ekran (launcher) va qo'ng'iroq ilovasi hech qachon bloklanmaydi:
     * aks holda telefondan umuman foydalanib bo'lmay qoladi yoki favqulodda
     * qo'ng'iroq qilib bo'lmaydi.
     */
    private fun isEssential(pkg: String): Boolean {
        val home = packageManager.resolveActivity(
            Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME), 0
        )?.activityInfo?.packageName
        val dialer = getSystemService(TelecomManager::class.java)?.defaultDialerPackage
        return pkg == home || pkg == dialer
    }

    private fun check(pkg: String) {
        val appName = config.apps[pkg] ?: return
        if (isEssential(pkg)) return
        if (config.schedule.isAllowedAt(Calendar.getInstance())) return

        val now = SystemClock.elapsedRealtime()
        if (pkg == lastBlockedPackage && now - lastBlockedAt < DEBOUNCE_MS) return
        lastBlockedPackage = pkg
        lastBlockedAt = now

        performGlobalAction(GLOBAL_ACTION_HOME)
        startActivity(
            Intent(this, BlockActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                .putExtra(BlockActivity.EXTRA_APP_NAME, appName)
                .putExtra(BlockActivity.EXTRA_SCHEDULE, config.schedule.label)
        )
    }

    companion object {
        private const val CHECK_INTERVAL_MS = 15_000L
        private const val DEBOUNCE_MS = 1_500L
    }
}
