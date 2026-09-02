import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  // ── Base scale (4pt grid) ─────────────────────────────────────────────────
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double base = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double huge = 48;
  static const double massive = 64;

  // ── Semantic spacers ──────────────────────────────────────────────────────
  static const SizedBox gapXs = SizedBox(height: xs, width: xs);
  static const SizedBox gapSm = SizedBox(height: sm, width: sm);
  static const SizedBox gapMd = SizedBox(height: md, width: md);
  static const SizedBox gapBase = SizedBox(height: base, width: base);
  static const SizedBox gapLg = SizedBox(height: lg, width: lg);
  static const SizedBox gapXl = SizedBox(height: xl, width: xl);
  static const SizedBox gapXxl = SizedBox(height: xxl, width: xxl);

  static const SizedBox vXs = SizedBox(height: xs);
  static const SizedBox vSm = SizedBox(height: sm);
  static const SizedBox vMd = SizedBox(height: md);
  static const SizedBox vBase = SizedBox(height: base);
  static const SizedBox vLg = SizedBox(height: lg);
  static const SizedBox vXl = SizedBox(height: xl);
  static const SizedBox vXxl = SizedBox(height: xxl);

  static const SizedBox hXs = SizedBox(width: xs);
  static const SizedBox hSm = SizedBox(width: sm);
  static const SizedBox hMd = SizedBox(width: md);
  static const SizedBox hBase = SizedBox(width: base);
  static const SizedBox hLg = SizedBox(width: lg);
  static const SizedBox hXl = SizedBox(width: xl);
  static const SizedBox hXxl = SizedBox(width: xxl);

  // ── Padding presets ───────────────────────────────────────────────────────
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: base);
  static const EdgeInsets cardPadding = EdgeInsets.all(base);
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(
    horizontal: base,
    vertical: md,
  );
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: xl,
    vertical: md,
  );
}

class AppRadius {
  AppRadius._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double base = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double pill = 100;

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(base));
  static const BorderRadius buttonRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius chipRadius = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius bottomSheetRadius = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
  static const BorderRadius pillRadius = BorderRadius.all(Radius.circular(pill));
}

class AppElevation {
  AppElevation._();

  static const double none = 0;
  static const double xs = 1;
  static const double sm = 2;
  static const double md = 4;
  static const double lg = 8;
  static const double xl = 16;
}
