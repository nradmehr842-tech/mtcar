package ir.mediatelecom.mtcar
object AlertClassifier {
    fun classify(body: String, sender: String): VehicleAlert? {
        val text = body.lowercase()

        val match = when {
            containsAny(text, "door alarm", "door open", "door!") ->
                Triple("door", "🚨 در خودرو باز شد", "Door Alarm")

            containsAny(text, "acc alarm", "acc on", "ignition on", "acc:on") ->
                Triple("ignition", "🚨 خودرو روشن شد", "ACC / Ignition ON")

            containsAny(text, "move alarm", "movement alarm", "moved", "move!") ->
                Triple("movement", "🚨 حرکت خودرو تشخیص داده شد", "Movement Alarm")

            containsAny(text, "sensor alarm", "shock alarm", "vibration", "shake alarm") ->
                Triple("shock", "🚨 ضربه یا لرزش خودرو", "Shock / Vibration Alarm")

            containsAny(text, "power alarm", "power cut", "power off", "battery cut", "external power off") ->
                Triple("power", "🚨 برق خارجی ردیاب قطع شد", "External Power Cut / Battery Disconnect")

            containsAny(text, "low battery") ->
                Triple("low_battery", "⚠️ باتری داخلی ردیاب کم است", "Low Battery")

            containsAny(text, "sos alarm", "help me", "sos!") ->
                Triple("sos", "🚨 SOS خودرو", "SOS Alarm")

            containsAny(text, "monitor ok", "monitor mode") ->
                Triple("monitor_ready", "میکروفون آماده شنیدن است", "Monitor Mode Ready")

            containsAny(text, "tracker ok", "track mode") ->
                Triple("tracker_mode", "رهگیری GPS دوباره فعال شد", "Tracker Mode Restored")

            text.contains("battery:") && (text.contains("gprs:") || text.contains("gps:")) ->
                Triple("device_status", "وضعیت ردیاب خودرو بروزرسانی شد", "Device Status")

            containsAny(text, "balance", "credit", "rial", "toman", "ریال", "تومان", "اعتبار", "موجودی") ->
                Triple("sim_balance", "مانده شارژ سیم‌کارت", "SIM Balance")

            else ->
                Triple("tracker_sms", "پیام ردیاب خودرو", "Tracker SMS")
        }

        return VehicleAlert(
            type = match.first,
            title = match.second,
            body = body.take(800),
            sender = sender,
            time = System.currentTimeMillis(),
        )
    }

    private fun containsAny(text: String, vararg terms: String): Boolean =
        terms.any { text.contains(it) }
}
