import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NexaTheme {
  // ── COULEURS ──────────────────────────────────────────────
  static const Color noir        = Color(0xFF080C08);
  static const Color noir2       = Color(0xFF0F160F);
  static const Color vertDeep    = Color(0xFF1B4332);
  static const Color vert        = Color(0xFF22C55E);
  static const Color vertLight   = Color(0xFFD1FAE5);
  static const Color blanc       = Color(0xFFF5F0E8);
  static const Color gris        = Color(0xFF6B7280);
  static const Color or          = Color(0xFFD4A017);
  static const Color rouge       = Color(0xFFEF4444);
  static const Color orange      = Color(0xFFF97316);

  // Statuts pâturage
  static const Color excellent   = Color(0xFF22C55E);
  static const Color bon         = Color(0xFFF59E0B);
  static const Color attention   = Color(0xFFF97316);
  static const Color critique    = Color(0xFFEF4444);

  // ── TYPOGRAPHIE ───────────────────────────────────────────
  static const String fontDisplay = 'BebasNeue';
  static const String fontBody    = 'PlusJakarta';

  static const TextStyle displayXL = TextStyle(
    fontFamily: fontDisplay,
    fontSize: 72,
    letterSpacing: 2,
    color: blanc,
    height: 0.9,
  );

  static const TextStyle displayL = TextStyle(
    fontFamily: fontDisplay,
    fontSize: 48,
    letterSpacing: 1.5,
    color: blanc,
    height: 1,
  );

  static const TextStyle displayM = TextStyle(
    fontFamily: fontDisplay,
    fontSize: 32,
    letterSpacing: 1,
    color: blanc,
  );

  static const TextStyle titleL = TextStyle(
    fontFamily: fontBody,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: blanc,
  );

  static const TextStyle titleM = TextStyle(
    fontFamily: fontBody,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: blanc,
  );

  static const TextStyle bodyL = TextStyle(
    fontFamily: fontBody,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: blanc,
    height: 1.6,
  );

  static const TextStyle bodyM = TextStyle(
    fontFamily: fontBody,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: blanc,
    height: 1.5,
  );

  static const TextStyle bodyS = TextStyle(
    fontFamily: fontBody,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: blanc,
  );

  static const TextStyle label = TextStyle(
    fontFamily: fontBody,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,
    color: blanc,
  );

  // ── THEME DATA ────────────────────────────────────────────
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: noir,
      primaryColor: vert,
      colorScheme: const ColorScheme.dark(
        primary: vert,
        secondary: or,
        surface: noir2,
        background: noir,
        error: rouge,
        onPrimary: noir,
        onSecondary: noir,
        onSurface: blanc,
        onBackground: blanc,
      ),
      fontFamily: fontBody,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: titleL,
        iconTheme: IconThemeData(color: blanc),
      ),
      cardTheme: CardThemeData(
        color: noir2,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: blanc.withOpacity(0.07)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: vert,
          foregroundColor: noir,
          textStyle: const TextStyle(
            fontFamily: fontBody,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(double.infinity, 54),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: blanc.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: blanc.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: blanc.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: vert),
        ),
        labelStyle: TextStyle(color: blanc.withOpacity(0.5)),
        hintStyle: TextStyle(color: blanc.withOpacity(0.3)),
      ),
    );
  }
}

// ── COMPOSANTS RÉUTILISABLES ──────────────────────────────

class NexaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final VoidCallback? onTap;
  final double radius;

  const NexaCard({
    super.key,
    required this.child,
    this.padding,
    this.borderColor,
    this.onTap,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: NexaTheme.noir2,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: borderColor ?? NexaTheme.blanc.withOpacity(0.07),
          ),
        ),
        child: child,
      ),
    );
  }
}

class NexaButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  final Color? color;
  final Color? textColor;
  final Widget? icon;
  final bool outlined;

  const NexaButton({
    super.key,
    required this.label,
    this.onTap,
    this.isLoading = false,
    this.color,
    this.textColor,
    this.icon,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? NexaTheme.vert;
    final buttonTextColor = outlined ? buttonColor : (textColor ?? NexaTheme.noir);

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : buttonColor,
          borderRadius: BorderRadius.circular(12),
          border: outlined ? Border.all(color: buttonColor, width: 1.5) : null,
          boxShadow: [
            if (onTap != null && !outlined)
              BoxShadow(
                color: buttonColor.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: buttonTextColor,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[icon!, const SizedBox(width: 8)],
                    Text(
                      label,
                      style: NexaTheme.titleM.copyWith(
                        color: buttonTextColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class NexaEyebrow extends StatelessWidget {
  final String text;
  const NexaEyebrow(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: NexaTheme.vert.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NexaTheme.vert.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: NexaTheme.vert,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text.toUpperCase(),
            style: NexaTheme.label.copyWith(color: NexaTheme.vert),
          ),
        ],
      ),
    );
  }
}
