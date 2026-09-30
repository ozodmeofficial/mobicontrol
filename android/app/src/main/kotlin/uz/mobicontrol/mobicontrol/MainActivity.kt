package uz.mobicontrol.mobicontrol

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledApps" -> runInBackground(result) { installedApps() }
                    "getAppIcon" -> runInBackground(result) {
                        try {
                            iconBytes(packageManager.getApplicationIcon(call.arguments as String))
                        } catch (e: PackageManager.NameNotFoundException) {
                            null
                        }
                    }
                    "loadConfig" -> result.success(RuleStore.loadJson(this))
                    "saveConfig" -> try {
                        RuleStore.saveJson(this, call.arguments as String)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("INVALID_CONFIG", e.message, null)
                    }
                    "isAccessibilityEnabled" -> result.success(isAccessibilityServiceEnabled(this))
                    "openAccessibilitySettings" -> {
                        startActivity(
                            Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        executor.shutdown()
        super.onDestroy()
    }

    private fun runInBackground(result: MethodChannel.Result, block: () -> Any?) {
        executor.execute {
            try {
                val value = block()
                mainHandler.post { result.success(value) }
            } catch (e: Exception) {
                mainHandler.post { result.error("ERROR", e.message, null) }
            }
        }
    }

    /** Ishga tushiriladigan (launcher'da ko'rinadigan) ilovalar ro'yxati. */
    private fun installedApps(): List<Map<String, Any?>> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return packageManager.queryIntentActivities(intent, 0)
            .map { it.activityInfo }
            .filter { it.packageName != packageName }
            .distinctBy { it.packageName }
            .map { info ->
                mapOf(
                    "packageName" to info.packageName,
                    "appName" to info.applicationInfo.loadLabel(packageManager).toString(),
                    "icon" to iconBytes(info.applicationInfo.loadIcon(packageManager)),
                )
            }
    }

    private fun iconBytes(drawable: Drawable): ByteArray {
        val size = 96
        val bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
            Bitmap.createScaledBitmap(drawable.bitmap, size, size, true)
        } else {
            Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888).also {
                val canvas = Canvas(it)
                drawable.setBounds(0, 0, size, size)
                drawable.draw(canvas)
            }
        }
        return ByteArrayOutputStream().use {
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
            it.toByteArray()
        }
    }

    companion object {
        private const val CHANNEL = "uz.mobicontrol/native"

        fun isAccessibilityServiceEnabled(context: Context): Boolean {
            val expected = ComponentName(context, AppBlockerService::class.java)
            val enabled = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
            ) ?: return false
            return enabled.split(':').any {
                ComponentName.unflattenFromString(it) == expected
            }
        }
    }
}
