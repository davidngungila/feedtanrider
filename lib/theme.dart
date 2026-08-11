import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FT {
  static const Color green900 = Color(0xFF013618);
  static const Color green800 = Color(0xFF014A22);
  static const Color green700 = Color(0xFF015425);
  static const Color green600 = Color(0xFF017A36);
  static const Color green500 = Color(0xFF029642);
  static const Color green100 = Color(0xFFE3F3E9);
  static const Color green50 = Color(0xFFF2F9F5);

  static const Color gold = Color(0xFFFF8A00);
  static const Color goldDark = Color(0xFFE07200);
  static const Color goldLight = Color(0xFFFFF3E0);

  static const Color ink = Color(0xFF0E1A14);
  static const Color inkSoft = Color(0xFF6B7C73);
  static const Color line = Color(0xFFE6ECE8);
  static const Color white = Color(0xFFFFFFFF);
  static const Color bg = Color(0xFFF2F5F2);
  static const Color danger = Color(0xFFD64545);

  /// Soft translucent surface used for glassmorphism cards.
  static Color glass(Color c) => c.withValues(alpha: 0.6);

  static BoxShadow cardShadow = BoxShadow(
    color: green700.withValues(alpha: 0.06),
    blurRadius: 18,
    offset: const Offset(0, 6),
  );
}

final NumberFormat tzs = NumberFormat.currency(
  locale: 'en_TZ',
  symbol: 'TZS',
  decimalDigits: 0,
);

String fmtTZS(num n) => tzs.format(n);

String fmtShort(num n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K';
  return n.round().toString();
}

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h ${d.inMinutes % 60}m';
  return '${d.inDays}d';
}

String timeAgoStr(String iso) {
  final t = DateTime.tryParse(iso);
  if (t == null) return '';
  return timeAgo(t);
}

String greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

String formatDate(String iso) {
  final t = DateTime.tryParse(iso);
  if (t == null) return iso;
  return DateFormat('dd MMM yyyy, HH:mm').format(t.toLocal());
}

/// Bottom clearance so scrollable content can clear the frosted nav bar.
double ftNavClearance(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom + 68 + 20;

/// Frosted-glass style for primary buttons.
ButtonStyle ftGlassFilledStyle(Color color) => ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return color.withValues(alpha: 0.4);
        return color.withValues(alpha: 0.92);
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        final fill = color.withValues(alpha: states.contains(WidgetState.disabled) ? 0.4 : 0.92);
        return Color.alphaBlend(fill, FT.bg).computeLuminance() > 0.45 ? FT.ink : Colors.white;
      }),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: WidgetStatePropertyAll(color.withValues(alpha: 0.35)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
      side: WidgetStatePropertyAll(BorderSide(color: Colors.white.withValues(alpha: 0.9))),
    );

/// Frosted-glass style for secondary / outline buttons.
ButtonStyle ftGlassOutlinedStyle(Color color) => OutlinedButton.styleFrom(
      foregroundColor: color,
      side: BorderSide(color: color.withValues(alpha: 0.85), width: 1.5),
      backgroundColor: color.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
    );

InputDecoration ftInputDecoration({
  required String label,
  String? hint,
  required IconData icon,
  Widget? suffix,
  bool glass = false,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Icon(icon, color: FT.green600, size: 20),
    suffixIcon: suffix,
    filled: true,
    fillColor: glass ? Colors.white.withValues(alpha: 0.55) : FT.green50,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: glass ? Colors.white.withValues(alpha: 0.9) : FT.line,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: FT.green600, width: 1.6),
    ),
    contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 14),
    labelStyle: const TextStyle(color: FT.inkSoft, fontSize: 13),
    hintStyle: const TextStyle(color: FT.inkSoft, fontSize: 12.5),
  );
}

class FTButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final Color? textColor;
  final bool loading;
  final IconData? icon;
  const FTButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = FT.green700,
    this.textColor,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    final fill = Color.alphaBlend(color.withValues(alpha: enabled ? 0.92 : 0.4), FT.bg);
    final fg = textColor ?? (fill.computeLuminance() > 0.45 ? FT.ink : Colors.white);
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: BorderRadius.circular(100),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      color.withValues(alpha: enabled ? 0.96 : 0.45),
                      color.withValues(alpha: enabled ? 0.88 : 0.42),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: enabled ? 0.35 : 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: loading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (icon != null) ...[
                                Icon(icon, size: 18, color: fg),
                                const SizedBox(width: 8),
                              ],
                              Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: fg)),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Frosted-surface decoration shared by glassmorphism cards.
BoxDecoration glassCardDecoration({Color color = FT.white, double radius = 18}) {
  return BoxDecoration(
    color: FT.glass(color),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
    boxShadow: [
      BoxShadow(
        color: FT.green700.withValues(alpha: 0.07),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

/// Full-bleed soft gradient with pre-blurred color blobs that sits behind
/// every screen, so translucent cards read as frosted glass.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE7F3EC),
            Color(0xFFFCF4E7),
            Color(0xFFE9EFF7),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -70, right: -60, child: _blob(300, FT.green600.withValues(alpha: 0.26))),
          Positioned(top: 240, left: -90, child: _blob(280, FT.gold.withValues(alpha: 0.22))),
          Positioned(bottom: -100, right: 10, child: _blob(340, FT.green500.withValues(alpha: 0.2))),
          Positioned(bottom: 170, left: -70, child: _blob(220, FT.green100)),
          child,
        ],
      ),
    );
  }

  Widget _blob(double size, Color color) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

class FTCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  const FTCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color = FT.white,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: padding,
          decoration: glassCardDecoration(color: color),
          child: child,
        ),
      ),
    );
  }
}

Widget sectionTitle(String text, {Widget? trailing}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(0, 4, 0, 10),
    child: Row(
      children: [
        Expanded(child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: FT.ink))),
        ?trailing,
      ],
    ),
  );
}

Widget emptyState(IconData icon, String title, String desc) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 26),
    child: Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: FT.green50, shape: BoxShape.circle),
          child: Icon(icon, size: 28, color: FT.inkSoft),
        ),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: FT.ink)),
        const SizedBox(height: 4),
        Text(desc, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: FT.inkSoft, height: 1.4)),
      ],
    ),
  );
}

void showFTSnack(BuildContext context, String msg, {Color? background}) {
  showFTSnackMessenger(ScaffoldMessenger.of(context), msg, background: background);
}

void showFTSnackMessenger(ScaffoldMessengerState messenger, String msg, {Color? background}) {
  final bg = background ?? FT.ink;
  final icon = background == FT.green700
      ? Icons.check_circle_rounded
      : background == FT.danger
          ? Icons.error_rounded
          : Icons.info_rounded;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: const TextStyle(color: Colors.white))),
        ],
      ),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
}

/// Frosted-glass dialog wrapper shared by all popups in the app.
class FTGlassDialog extends StatelessWidget {
  final Widget child;
  const FTGlassDialog({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
            decoration: glassCardDecoration(radius: 24),
            child: child,
          ),
        ),
      ),
    );
  }
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => FTGlassDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline_rounded, color: FT.green700, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(message, style: const TextStyle(fontSize: 13, color: FT.inkSoft, height: 1.4)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel', style: TextStyle(color: FT.inkSoft, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: ftGlassFilledStyle(FT.green700),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}
