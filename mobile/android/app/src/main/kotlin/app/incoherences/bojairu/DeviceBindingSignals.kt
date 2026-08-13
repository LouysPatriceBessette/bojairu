package app.incoherences.bojairu

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorManager
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.provider.Settings
import android.view.inputmethod.InputMethodManager
import java.security.MessageDigest

object DeviceBindingSignals {
    fun collect(context: Context): Map<String, String> {
        val signals = linkedMapOf<String, String>()
        signals["build_fingerprint"] = Build.FINGERPRINT
        signals["build_model"] = Build.MODEL
        signals["build_manufacturer"] = Build.MANUFACTURER
        signals["build_device"] = Build.DEVICE
        signals["build_product"] = Build.PRODUCT
        signals["build_brand"] = Build.BRAND
        // SOC_MODEL exists only from API 31 (Android 12). Unguarded access
        // throws NoSuchFieldError on API 30 and below and kills the process.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            signals["build_soc_model"] = Build.SOC_MODEL
        }
        signals["sdk_int"] = Build.VERSION.SDK_INT.toString()
        signals["android_id"] =
            Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
                ?: ""
        val metrics = context.resources.displayMetrics
        signals["display_width_px"] = metrics.widthPixels.toString()
        signals["display_height_px"] = metrics.heightPixels.toString()
        signals["display_density_dpi"] = metrics.densityDpi.toString()
        val sensorManager =
            context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val sensorDigest =
            sensorManager
                .getSensorList(Sensor.TYPE_ALL)
                .map { "${it.name}:${it.vendor}:${it.version}" }
                .sorted()
                .joinToString("|")
        signals["sensors_digest"] = sha256Hex(sensorDigest)
        val stat = StatFs(Environment.getDataDirectory().path)
        signals["data_storage_bytes"] =
            (stat.blockSizeLong * stat.blockCountLong).toString()
        val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
        signals["enabled_ime"] =
            imm.enabledInputMethodList
                .map { it.packageName }
                .sorted()
                .joinToString(",")
        return signals
    }

    private fun sha256Hex(input: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val hash = digest.digest(input.toByteArray(Charsets.UTF_8))
        return hash.joinToString("") { byte -> "%02x".format(byte) }
    }
}
