package uz.mobicontrol.mobicontrol

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.window.OnBackInvokedDispatcher

/** Ilova ruxsat etilmagan vaqtda ochilganda ko'rsatiladigan ekran. */
class BlockActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(buildLayout())
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            onBackInvokedDispatcher.registerOnBackInvokedCallback(
                OnBackInvokedDispatcher.PRIORITY_DEFAULT
            ) { goHome() }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        setContentView(buildLayout())
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        goHome()
    }

    private fun goHome() {
        startActivity(
            Intent(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_HOME)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
        finish()
    }

    private fun buildLayout(): LinearLayout {
        val appName = intent.getStringExtra(EXTRA_APP_NAME) ?: "Bu ilova"
        val schedule = intent.getStringExtra(EXTRA_SCHEDULE) ?: ""

        fun text(value: String, sizeSp: Float, bold: Boolean = false, alpha: Float = 1f) =
            TextView(this).apply {
                text = value
                setTextColor(Color.WHITE)
                this.alpha = alpha
                setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp)
                gravity = Gravity.CENTER
                if (bold) typeface = Typeface.DEFAULT_BOLD
                setPadding(0, dp(8), 0, dp(8))
            }

        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#1E1B4B"))
            setPadding(dp(32), dp(32), dp(32), dp(32))
            addView(text("⏳", 64f))
            addView(text("$appName hozir bloklangan", 24f, bold = true))
            addView(text("Ruxsat berilgan vaqt:", 16f, alpha = 0.7f))
            addView(text(schedule, 20f, bold = true))
            addView(Button(this@BlockActivity).apply {
                text = "Bosh ekranga qaytish"
                setOnClickListener { goHome() }
            }, LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { topMargin = dp(32) })
        }
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    companion object {
        const val EXTRA_APP_NAME = "app_name"
        const val EXTRA_SCHEDULE = "schedule"
    }
}
