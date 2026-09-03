package ir.mediatelecom.mtcar
import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

data class VehicleAlert(
    val type: String,
    val title: String,
    val body: String,
    val sender: String,
    val time: Long,
)

object AlertStore {
    const val PREFS = "mtcar_alerts"
    private const val TAMPER_WINDOW_MS = 120_000L
    private const val EVENTS = "events"

    fun normalizePhone(value: String): String =
        value.filter { it.isDigit() }.takeLast(12)

    fun senderMatches(context: Context, sender: String): Boolean {
        val expected = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString("tracker_number", "")
            .orEmpty()
        if (expected.isBlank()) return false
        val a = normalizePhone(expected)
        val b = normalizePhone(sender)
        return a.isNotBlank() && b.endsWith(a.takeLast(minOf(10, a.length)))
    }

    fun enabled(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getBoolean("alerts_enabled", true)

    @Synchronized
    fun add(context: Context, event: VehicleAlert) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val old = try { JSONArray(prefs.getString(EVENTS, "[]")) } catch (_: Exception) { JSONArray() }
        val fresh = JSONArray()
        fresh.put(toJson(event))
        val max = minOf(old.length(), 99)
        for (i in 0 until max) fresh.put(old.get(i))
        prefs.edit().putString(EVENTS, fresh.toString()).apply()
    }

    fun getEvents(context: Context): List<Map<String, Any>> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val array = try { JSONArray(prefs.getString(EVENTS, "[]")) } catch (_: Exception) { JSONArray() }
        val out = mutableListOf<Map<String, Any>>()
        for (i in 0 until array.length()) {
            val o = array.optJSONObject(i) ?: continue
            out += mapOf(
                "type" to o.optString("type"),
                "title" to o.optString("title"),
                "body" to o.optString("body"),
                "sender" to o.optString("sender"),
                "time" to o.optLong("time"),
            )
        }
        return out
    }


    fun correlateTamper(context: Context, event: VehicleAlert): VehicleAlert? {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val now = event.time
        val lastPower = prefs.getLong("last_power_cut", 0L)
        val lastShock = prefs.getLong("last_shock_or_move", 0L)

        when (event.type) {
            "power" -> prefs.edit().putLong("last_power_cut", now).apply()
            "shock", "movement" -> prefs.edit().putLong("last_shock_or_move", now).apply()
        }

        val powerNearShock =
            event.type == "power" && lastShock > 0L && now - lastShock in 0..TAMPER_WINDOW_MS
        val shockNearPower =
            event.type in setOf("shock", "movement") && lastPower > 0L && now - lastPower in 0..TAMPER_WINDOW_MS

        if (!powerNearShock && !shockNearPower) return null

        return VehicleAlert(
            type = "tamper",
            title = "🚨 احتمال جدا شدن ردیاب از خودرو",
            body = "قطع برق خارجی همراه با حرکت/لرزش ردیاب در فاصله کمتر از ۲ دقیقه تشخیص داده شد.",
            sender = event.sender,
            time = now,
        )
    }

    fun markPowerRestored(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .remove("last_power_cut")
            .apply()
    }

    fun clear(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(EVENTS).apply()
    }

    private fun toJson(event: VehicleAlert) = JSONObject().apply {
        put("type", event.type)
        put("title", event.title)
        put("body", event.body)
        put("sender", event.sender)
        put("time", event.time)
    }
}
