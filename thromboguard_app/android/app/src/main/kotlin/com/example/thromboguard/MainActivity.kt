package com.example.thromboguard

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.telephony.SmsManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Native side of the emergency flow: sends SMS directly (SmsManager) and
 * places a phone call (ACTION_CALL) without any user interaction, as long as
 * the SEND_SMS / CALL_PHONE permissions were granted.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "thromboguard/emergency"
    private val permRequestCode = 4242
    private var pendingResult: MethodChannel.Result? = null
    private val needed = arrayOf(Manifest.permission.SEND_SMS, Manifest.permission.CALL_PHONE)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasPermissions" -> result.success(hasAll())
                    "requestPermissions" -> requestPermissions(result)
                    "sendSms" -> {
                        val numbers = call.argument<List<String>>("numbers") ?: emptyList()
                        val message = call.argument<String>("message") ?: ""
                        sendSms(numbers, message, result)
                    }
                    "call" -> placeCall(call.argument<String>("number") ?: "", result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasAll(): Boolean = needed.all {
        ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestPermissions(result: MethodChannel.Result) {
        if (hasAll()) {
            result.success(true)
            return
        }
        if (pendingResult != null) {
            result.error("busy", "A permission request is already running", null)
            return
        }
        pendingResult = result
        ActivityCompat.requestPermissions(this, needed, permRequestCode)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == permRequestCode) {
            val ok = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            pendingResult?.success(ok)
            pendingResult = null
        }
    }

    @Suppress("DEPRECATION")
    private fun smsManager(): SmsManager =
        if (Build.VERSION.SDK_INT >= 31) getSystemService(SmsManager::class.java) else SmsManager.getDefault()

    /** Returns how many contacts the message was handed to. */
    private fun sendSms(numbers: List<String>, message: String, result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
            result.success(0)
            return
        }
        try {
            val sms = smsManager()
            val parts = sms.divideMessage(message) // long / Arabic texts are split automatically
            var sent = 0
            for (n in numbers) {
                try {
                    sms.sendMultipartTextMessage(n, null, parts, null, null)
                    sent++
                } catch (e: Exception) {
                    // try the remaining contacts
                }
            }
            result.success(sent)
        } catch (e: Exception) {
            result.error("sms_failed", e.message, null)
        }
    }

    private fun placeCall(number: String, result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE) != PackageManager.PERMISSION_GRANTED) {
            result.success(false)
            return
        }
        try {
            val intent = Intent(Intent.ACTION_CALL, Uri.fromParts("tel", number, null))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.success(false)
        }
    }
}
