import 'package:flutter/material.dart';

class SubscriptionExpiredBanner extends StatelessWidget {
  final bool expired;
  final VoidCallback onOpenAccount;

  const SubscriptionExpiredBanner({
    super.key,
    required this.expired,
    required this.onOpenAccount,
  });

  @override
  Widget build(BuildContext context) {
    if (!expired) return const SizedBox.shrink();

    return Card(
      color: const Color(0xFFFFECEB),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE10600)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.workspace_premium_outlined,
              color: Color(0xFFE10600),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'دوره اعتبار حساب شما به پایان رسیده است. '
                'برای شارژ به پنل حساب کاربری خود مراجعه کنید.',
                style: TextStyle(
                  color: Color(0xFF2B2F36),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onOpenAccount,
              child: const Text('تمدید'),
            ),
          ],
        ),
      ),
    );
  }
}
