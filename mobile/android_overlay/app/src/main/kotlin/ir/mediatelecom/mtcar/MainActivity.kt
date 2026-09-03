package ir.mediatelecom.mtcar
import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.telephony.SmsManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "mtcar/alerts"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveSettings" -> {
                    val number = call.argument<String>("trackerNumber").orEmpty()
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    val trackerPassword = call.argument<String>("trackerPassword").orEmpty().ifBlank { "123456" }
                    val carrierServiceNumber = call.argument<String>("carrierServiceNumber").orEmpty()
                    val balanceCode = call.argument<String>("balanceCode").orEmpty()
                    val prefs = getSharedPreferences(AlertStore.PREFS, Context.MODE_PRIVATE)
                    prefs.edit()
                        .putString("tracker_number", AlertStore.normalizePhone(number))
                        .putBoolean("alerts_enabled", enabled)
                        .putString("tracker_password", trackerPassword.filter { it.isDigit() }.take(6))
                        .putString("carrier_service_number", carrierServiceNumber.trim())
                        .putString("balance_code", balanceCode.trim())
                        .apply()
                    result.success(true)
                }

                "getStatus" -> {
                    val prefs = getSharedPreferences(AlertStore.PREFS, Context.MODE_PRIVATE)
                    val nm = getSystemService(NotificationManager::class.java)
                    val fullScreen = if (Build.VERSION.SDK_INT >= 34) nm.canUseFullScreenIntent() else true
                    val listenerEnabled = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
                        ?.contains(packageName) == true
                    result.success(
                        mapOf(
                            "trackerNumber" to prefs.getString("tracker_number", "").orEmpty(),
                            "enabled" to prefs.getBoolean("alerts_enabled", true),
                            "trackerPassword" to prefs.getString("tracker_password", "123456").orEmpty(),
                            "carrierServiceNumber" to prefs.getString("carrier_service_number", "").orEmpty(),
                            "balanceCode" to prefs.getString("balance_code", "").orEmpty(),
                            "smsPermission" to (ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED),
                            "notificationPermission" to (
                                Build.VERSION.SDK_INT < 33 ||
                                ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                            ),
                            "fullScreenAllowed" to fullScreen,
                            "notificationListenerEnabled" to listenerEnabled,
                        )
                    )
                }

                "requestPermissions" -> {
                    val permissions = mutableListOf(Manifest.permission.RECEIVE_SMS, Manifest.permission.SEND_SMS)
                    if (Build.VERSION.SDK_INT >= 33) permissions.add(Manifest.permission.POST_NOTIFICATIONS)
                    ActivityCompat.requestPermissions(this, permissions.toTypedArray(), 901)
                    result.success(true)
                }

                "openNotificationAccess" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(true)
                }

                "openFullScreenSettings" -> {
                    if (Build.VERSION.SDK_INT >= 34) {
                        startActivity(
                            Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
                                data = android.net.Uri.parse("package:$packageName")
                            }
                        )
                    }
                    result.success(true)
                }


                "sendTrackerCommand" -> {
                    val prefs = getSharedPreferences(AlertStore.PREFS, Context.MODE_PRIVATE)
                    val trackerNumber = prefs.getString("tracker_number", "").orEmpty()
                    val password = prefs.getString("tracker_password", "123456").orEmpty()
                    val service = prefs.getString("carrier_service_number", "").orEmpty()
                    val balanceCode = prefs.getString("balance_code", "").orEmpty()
                    val type = call.argument<String>("command").orEmpty()

                    if (trackerNumber.isBlank()) {
                        result.error("missing_tracker_number", "Tracker SIM number is not configured", null)
                        return@setMethodCallHandler
                    }

                    val smsBody = when (type) {
                        "check" -> "check$password"
                        "balance" -> {
                            if (service.isBlank() || balanceCode.isBlank()) {
                                result.error("missing_balance_config", "Carrier service number/code is not configured", null)
                                return@setMethodCallHandler
                            }
                            "balance$password $service $balanceCode"
                        }
                        "extpower_on" -> "extpower$password on"
                        "extpower_off" -> "extpower$password off"
                        "gpssignal_on" -> "gpssignal$password on"
                        "gpssignal_off" -> "gpssignal$password off"
                        "monitor_on" -> "monitor$password"
                        "tracker_mode" -> "tracker$password"
                        "arm" -> "arm$password"
                        "disarm" -> "disarm$password"
                        else -> {
                            result.error("bad_command", "Unsupported tracker command", null)
                            return@setMethodCallHandler
                        }
                    }

                    try {
                        val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            getSystemService(SmsManager::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            SmsManager.getDefault()
                        }
                        smsManager.sendTextMessage(trackerNumber, null, smsBody, null, null)
                        result.success(true)
                    } catch (e: SecurityException) {
                        result.error("sms_permission", "SEND_SMS permission is required", null)
                    } catch (e: Exception) {
                        result.error("sms_send_failed", e.message, null)
                    }
                }


                "openTrackerDialer" -> {
                    val prefs = getSharedPreferences(AlertStore.PREFS, Context.MODE_PRIVATE)
                    val trackerNumber = prefs.getString("tracker_number", "").orEmpty()
                    if (trackerNumber.isBlank()) {
                        result.error("missing_tracker_number", "Tracker SIM number is not configured", null)
                        return@setMethodCallHandler
                    }
                    try {
                        startActivity(Intent(Intent.ACTION_DIAL, Uri.parse("tel:$trackerNumber")))
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("dialer_failed", e.message, null)
                    }
                }

                "getEvents" -> result.success(AlertStore.getEvents(this))
                "clearEvents" -> {
                    AlertStore.clear(this)
                    result.success(true)
                }

                "testCriticalAlarm" -> {
                    val event = VehicleAlert(
                        type = "test",
                        title = "تست آلارم خودرو",
                        body = "این هشدار برای بررسی سیستم اعلان MTcar ایجاد شده است.",
                        sender = "TEST",
                        time = System.currentTimeMillis(),
                    )
                    AlertStore.add(this, event)
                    AlertNotifier.notifyCritical(this, event)
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }
}
