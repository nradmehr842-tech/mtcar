import 'package:flutter/material.dart';

class DeviceSimPage extends StatelessWidget {
  const DeviceSimPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.sim_card_outlined),
                title: Text('وضعیت سیم‌کارت دستگاه'),
                subtitle: Text('موجودی فقط از آخرین استعلام معتبر نمایش داده می‌شود'),
              ),
              Divider(height: 1),
              ListTile(
                title: Text('اپراتور'),
                trailing: Text('همراه اول / ایرانسل'),
              ),
              Divider(height: 1),
              ListTile(
                title: Text('شارژ اصلی'),
                trailing: Text('در دسترس نیست'),
              ),
              Divider(height: 1),
              ListTile(
                title: Text('باقی‌مانده اینترنت'),
                trailing: Text('در دسترس نیست'),
              ),
              Divider(height: 1),
              ListTile(
                title: Text('آخرین استعلام'),
                trailing: Text('—'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: null,
          icon: Icon(Icons.refresh),
          label: Text('استعلام مجدد'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: null,
          icon: Icon(Icons.account_balance_wallet_outlined),
          label: Text('شارژ اصلی سیم‌کارت'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: null,
          icon: Icon(Icons.public),
          label: Text('خرید بسته اینترنت'),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'MTcar عدد ساختگی برای شارژ یا اینترنت نشان نمی‌دهد. '
              'اگر اپراتور/Provider نتواند مقدار واقعی را برگرداند، '
              'عبارت «در دسترس نیست» نمایش داده می‌شود.',
            ),
          ),
        ),
      ],
    );
  }
}
