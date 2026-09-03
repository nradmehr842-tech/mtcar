package ir.mediatelecom.mtcar
import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class SmsNotificationListener : NotificationListenerService() {
    private val likelySmsPackages = setOf(
        "com.google.android.apps.messaging",
        "com.samsung.android.messaging",
        "com.android.mms",
    )

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null || sbn.packageName == packageName) return
        if (!likelySmsPackages.contains(sbn.packageName)) return
        if (!AlertStore.enabled(this)) return

        val extras = sbn.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty()
        val combined = "$title $text"

        if (!AlertStore.senderMatches(this, title) && !AlertStore.senderMatches(this, combined)) return

        val event = AlertClassifier.classify(text, title) ?: return
        AlertStore.add(this, event)
        AlertNotifier.notifyCritical(this, event)

        val tamper = AlertStore.correlateTamper(this, event)
        if (tamper != null) {
            AlertStore.add(this, tamper)
            AlertNotifier.notifyCritical(this, tamper)
        }
    }
}
