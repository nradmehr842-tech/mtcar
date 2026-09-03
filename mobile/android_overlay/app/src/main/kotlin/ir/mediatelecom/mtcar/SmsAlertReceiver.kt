package ir.mediatelecom.mtcar
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

class SmsAlertReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        if (!AlertStore.enabled(context)) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isEmpty()) return

        val sender = messages.first().originatingAddress.orEmpty()
        if (!AlertStore.senderMatches(context, sender)) return

        val body = messages.joinToString(separator = "") { it.messageBody.orEmpty() }
        val event = AlertClassifier.classify(body, sender) ?: return

        AlertStore.add(context, event)
        AlertNotifier.notifyCritical(context, event)

        val tamper = AlertStore.correlateTamper(context, event)
        if (tamper != null) {
            AlertStore.add(context, tamper)
            AlertNotifier.notifyCritical(context, tamper)
        }
    }
}
