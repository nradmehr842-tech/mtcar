import 'package:flutter/material.dart';

class AccountMembershipPage extends StatelessWidget {
  const AccountMembershipPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          child: ListTile(
            leading: CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text('نام کاربری'),
            subtitle: Text('شناسه ورود MTcar'),
            trailing: Icon(Icons.verified_outlined),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.password),
            title: const Text('تغییر رمز ورود برنامه'),
            subtitle: const Text('با واردکردن رمز فعلی؛ بدون پیامک'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {},
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.workspace_premium_outlined),
                    SizedBox(width: 8),
                    Expanded(child: Text('اشتراک سالانه')),
                    Chip(label: Text('فعال')),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('فعال تا: ۱۴۰۶/۰۶/۱۲'),
                const SizedBox(height: 4),
                const Text(
                  'قیمت اشتراک از سرور خوانده می‌شود؛ داخل APK ثابت نیست.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: null,
                  icon: Icon(Icons.credit_card),
                  label: Text('تمدید / پرداخت اشتراک'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline, color: Color(0xFFE10600)),
            title: Text('تمدید اشتراک'),
            subtitle: Text(
              'در صورت پایان اعتبار، ورود به حساب و پرداخت همچنان فعال می‌ماند '
              'تا بتوانید اشتراک را تمدید کنید.',
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Card(
          child: ListTile(
            leading: Icon(Icons.receipt_long_outlined),
            title: Text('تاریخچه پرداخت‌ها'),
            subtitle: Text('رسید، مبلغ، وضعیت و تاریخ تمدید'),
            trailing: Icon(Icons.chevron_left),
          ),
        ),
      ],
    );
  }
}
