import 'dart:ui';
import 'package:flutter/material.dart';
import '../app/mtcar_theme.dart';

class MtPremiumHeader extends StatelessWidget {
  final VoidCallback onTheme;
  final VoidCallback? onBell;
  final bool darkMode;
  final int notificationCount;
  final bool showBack;
  final VoidCallback? onBack;

  const MtPremiumHeader({
    super.key,
    required this.onTheme,
    this.onBell,
    required this.darkMode,
    this.notificationCount = 0,
    this.showBack = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF00918), Color(0xFFC7000A), Color(0xFF8D0006)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: MtColors.red.withOpacity(.24),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _HeaderWavePainter()),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
              child: Row(
                textDirection: TextDirection.ltr,
                children: [
                  if (showBack)
                    _GlassRoundButton(
                      icon: Icons.chevron_left_rounded,
                      onTap: onBack ?? () => Navigator.maybePop(context),
                    )
                  else
                    _GlassRoundButton(
                      icon: darkMode
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      onTap: onTheme,
                    ),
                  const Spacer(),
                  Image.asset(
                    'assets/images/mtcar_logo_white.png',
                    width: 190,
                    height: 62,
                    fit: BoxFit.contain,
                  ),
                  const Spacer(),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _GlassRoundButton(
                        icon: Icons.notifications_none_rounded,
                        onTap: onBell ?? () {},
                      ),
                      if (notificationCount > 0)
                        Positioned(
                          right: -3,
                          top: -4,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 22),
                            height: 22,
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF1717),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              notificationCount > 9 ? '9+' : '$notificationCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassRoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassRoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: Colors.white.withOpacity(.14),
          child: InkWell(
            onTap: onTap,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(.22)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 14,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 27),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()
      ..color = Colors.white.withOpacity(.045)
      ..style = PaintingStyle.fill;
    final p2 = Paint()
      ..color = Colors.black.withOpacity(.05)
      ..style = PaintingStyle.fill;

    final path1 = Path()
      ..moveTo(0, size.height * .62)
      ..quadraticBezierTo(
        size.width * .36,
        size.height * .28,
        size.width * .64,
        size.height * .62,
      )
      ..quadraticBezierTo(
        size.width * .82,
        size.height * .84,
        size.width,
        size.height * .58,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path1, p1);

    final path2 = Path()
      ..moveTo(0, size.height * .88)
      ..quadraticBezierTo(
        size.width * .52,
        size.height * .48,
        size.width,
        size.height * .70,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path2, p2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MtCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;

  const MtCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF171B22) : Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: dark
              ? Colors.white.withOpacity(.065)
              : Colors.black.withOpacity(.055),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(dark ? .15 : .07),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: card,
      ),
    );
  }
}

class MtRedButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double height;
  final bool outlined;

  const MtRedButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.height = 54,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 21),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
      ],
    );

    if (outlined) {
      return SizedBox(
        height: height,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: MtColors.red,
            side: const BorderSide(color: MtColors.red, width: 1.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: child,
        ),
      );
    }

    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF20A1A), Color(0xFFC3000A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: MtColors.red.withOpacity(.28),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
          const BoxShadow(
            color: Color(0x55FFFFFF),
            blurRadius: 2,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.white),
            child: IconTheme(
              data: const IconThemeData(color: Colors.white),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class MtStatusPill extends StatelessWidget {
  final String text;
  final Color color;

  const MtStatusPill({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class MtBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final int alertCount;

  const MtBottomNav({
    super.key,
    required this.index,
    required this.onChanged,
    this.alertCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_outlined, 'خانه'),
      (Icons.map_outlined, 'نقشه'),
      (Icons.notifications_none_rounded, 'هشدارها'),
      (Icons.support_agent_outlined, 'پشتیبانی'),
      (Icons.person_outline_rounded, 'حساب'),
    ];

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF9F0008), Color(0xFFE40715), Color(0xFF970006)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        left: 6,
        right: 6,
        top: 7,
        bottom: 7 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final selected = index == i;
          final icon = Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                items[i].$1,
                color: Colors.white,
                size: selected ? 27 : 24,
              ),
              if (i == 2 && alertCount > 0)
                Positioned(
                  right: -10,
                  top: -8,
                  child: Container(
                    width: 19,
                    height: 19,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF1818),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      alertCount > 9 ? '9+' : '$alertCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          );

          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: selected ? Colors.white.withOpacity(.10) : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                border: selected
                    ? Border.all(color: Colors.white.withOpacity(.34), width: 1.1)
                    : null,
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFF2C39).withOpacity(.46),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onChanged(i),
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        icon,
                        const SizedBox(height: 4),
                        Text(
                          items[i].$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class MtSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;

  const MtSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 23),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                        height: 1.5,
                      ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class MtDivider extends StatelessWidget {
  const MtDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).dividerColor.withOpacity(.08),
    );
  }
}
