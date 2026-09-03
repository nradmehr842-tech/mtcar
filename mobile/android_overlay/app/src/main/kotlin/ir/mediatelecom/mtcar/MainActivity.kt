package ir.mediatelecom.mtcar

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.telephony.SmsManager
import android.widget.Toast
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "ir.mediatelecom.mtcar/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openUrl" -> {
                        val url = call.argument<String>("url").orEmpty()
                        try {
                            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("open_failed", e.message, null)
                        }
                    }
                    "monitorMode" -> {
                        val phone = call.argument<String>("phone").orEmpty()
                        val password = call.argument<String>("password").orEmpty()
                        if (phone.isBlank()) {
                            result.error("missing_phone", "Tracker SIM is not configured", null)
                            return@setMethodCallHandler
                        }
                        sendTrackerSmsAndDial(phone, "monitor$password")
                        result.success(true)
                    }
                    "trackerMode" -> {
                        val phone = call.argument<String>("phone").orEmpty()
                        val password = call.argument<String>("password").orEmpty()
                        if (phone.isBlank()) {
                            result.error("missing_phone", "Tracker SIM is not configured", null)
                            return@setMethodCallHandler
                        }
                        sendTrackerSms(phone, "tracker$password")
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun sendTrackerSmsAndDial(phone: String, body: String) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED) {
            try {
                SmsManager.getDefault().sendTextMessage(phone, null, body, null, null)
                Toast.makeText(this, "Monitor command sent", Toast.LENGTH_SHORT).show()
                startActivity(Intent(Intent.ACTION_DIAL, Uri.parse("tel:$phone")))
            } catch (e: Exception) {
                openSmsComposer(phone, body)
            }
        } else {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.SEND_SMS), 5101)
            openSmsComposer(phone, body)
        }
    }

    private fun sendTrackerSms(phone: String, body: String) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED) {
            try {
                SmsManager.getDefault().sendTextMessage(phone, null, body, null, null)
                Toast.makeText(this, "Tracker command sent", Toast.LENGTH_SHORT).show()
                return
            } catch (_: Exception) { }
        }
        openSmsComposer(phone, body)
    }

    private fun openSmsComposer(phone: String, body: String) {
        val intent = Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:$phone"))
        intent.putExtra("sms_body", body)
        startActivity(intent)
    }
}
