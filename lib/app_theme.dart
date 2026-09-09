
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ============================================================
// APP COLORS
// ============================================================

const Color kInk = Color(0xFF171717);
const Color kMutedInk = Color(0xFF6E6E69);

const Color kPageBg = Color(0xFFF2F2EE);
const Color kSurface = Color(0xFFFFFFFF);
const Color kSoft = Color(0xFFE9E9E4);
const Color kLine = Color(0xFFDCDCD5);

const Color kAccent = Color(0xFF171717);

// Success
const Color kGreen = Color(0xFF277A55);
const Color kGreenSoft = Color(0xFFE2F1E8);

// Warning
const Color kOrange = Color(0xFFD97721);
const Color kOrangeSoft = Color(0xFFFFEBDD);

// Error
const Color kRed = Color(0xFFC84A4A);
const Color kRedSoft = Color(0xFFF8E5E3);

// Information
const Color kBlue = Color(0xFF3A83C6);
const Color kBlueSoft = Color(0xFFE4F0FA);

// ============================================================
// APP THEME
// ============================================================

ThemeData buildAppTheme() {
  // ----------------------------------------------------------
  // COLOR SCHEME
  // ----------------------------------------------------------

  final colorScheme = ColorScheme.fromSeed(
    seedColor: kInk,
    brightness: Brightness.light,
  ).copyWith(
    primary: kInk,
    onPrimary: Colors.white,

    secondary: kInk,
    onSecondary: Colors.white,

    surface: kSurface,
    onSurface: kInk,

    surfaceContainerHighest: kSoft,

    outline: kLine,
    outlineVariant: kLine,

    error: kRed,
    onError: Colors.white,
  );

  // ----------------------------------------------------------
  // BASE THEME
  // ----------------------------------------------------------

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    colorScheme: colorScheme,

    scaffoldBackgroundColor: kPageBg,

    visualDensity: VisualDensity.standard,

    splashFactory: InkRipple.splashFactory,
  );

  // ----------------------------------------------------------
  // MANROPE TYPOGRAPHY
  // ----------------------------------------------------------

  final textTheme = GoogleFonts.manropeTextTheme(
    base.textTheme,
  ).apply(
    bodyColor: kInk,
    displayColor: kInk,
  );

  // ----------------------------------------------------------
  // INDIVIDUAL MANROPE STYLES
  // ----------------------------------------------------------

  final labelLarge = GoogleFonts.manrope(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: kInk,
  );

  final labelMedium = GoogleFonts.manrope(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: kInk,
  );

  final labelSmall = GoogleFonts.manrope(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: kMutedInk,
  );

  // ----------------------------------------------------------
  // RETURN THE COMPLETE THEME
  // ----------------------------------------------------------

  return base.copyWith(
    // --------------------------------------------------------
    // TEXT
    // --------------------------------------------------------

    textTheme: textTheme,
    primaryTextTheme: textTheme,

    // --------------------------------------------------------
    // SCAFFOLD
    // --------------------------------------------------------

    scaffoldBackgroundColor: kPageBg,

    // --------------------------------------------------------
    // APP BAR
    // --------------------------------------------------------

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: kInk,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),

    // --------------------------------------------------------
    // INPUT FIELDS
    // --------------------------------------------------------

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurface,

      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 17,
      ),

      hintStyle: GoogleFonts.manrope(
        color: kMutedInk,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),

      labelStyle: GoogleFonts.manrope(
        color: kMutedInk,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),

      floatingLabelStyle: GoogleFonts.manrope(
        color: kInk,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),

      helperStyle: GoogleFonts.manrope(
        color: kMutedInk,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),

      errorStyle: GoogleFonts.manrope(
        color: kRed,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),

      prefixIconColor: kMutedInk,
      suffixIconColor: kMutedInk,

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: kLine,
        ),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: kLine,
        ),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: kInk,
          width: 1.5,
        ),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: kRed,
        ),
      ),

      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: kRed,
          width: 1.5,
        ),
      ),

      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: kLine,
        ),
      ),
    ),

    // --------------------------------------------------------
    // FILLED BUTTON
    // --------------------------------------------------------

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kInk,
        foregroundColor: Colors.white,

        minimumSize: const Size(
          0,
          52,
        ),

        padding: const EdgeInsets.symmetric(
          horizontal: 22,
          vertical: 14,
        ),

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),

        elevation: 0,

        textStyle: labelLarge,
      ),
    ),

    // --------------------------------------------------------
    // OUTLINED BUTTON
    // --------------------------------------------------------

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kInk,

        minimumSize: const Size(
          0,
          52,
        ),

        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),

        side: const BorderSide(
          color: kLine,
        ),

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),

        textStyle: labelLarge,
      ),
    ),

    // --------------------------------------------------------
    // TEXT BUTTON
    // --------------------------------------------------------

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kInk,

        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),

        textStyle: labelLarge,
      ),
    ),

    // --------------------------------------------------------
    // ICON BUTTON
    // --------------------------------------------------------

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: kInk,
        backgroundColor: Colors.transparent,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    // --------------------------------------------------------
    // FLOATING ACTION BUTTON
    // --------------------------------------------------------

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: kInk,
      foregroundColor: Colors.white,

      elevation: 0,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    ),

    // --------------------------------------------------------
    // CARD
    // --------------------------------------------------------

    cardTheme: CardThemeData(
      color: kSurface,
      surfaceTintColor: Colors.transparent,

      elevation: 0,

      margin: EdgeInsets.zero,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),

        side: const BorderSide(
          color: kLine,
        ),
      ),
    ),

    // --------------------------------------------------------
    // CHIP
    // --------------------------------------------------------

    chipTheme: ChipThemeData(
      backgroundColor: kSoft,

      disabledColor: kSoft,

      selectedColor: kInk,

      secondarySelectedColor: kInk,

      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),

      labelStyle: labelMedium,

      secondaryLabelStyle: GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),

      side: const BorderSide(
        color: kLine,
      ),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),

      elevation: 0,
    ),

    // --------------------------------------------------------
    // DIALOG
    // --------------------------------------------------------

    dialogTheme: DialogThemeData(
      backgroundColor: kSurface,
      surfaceTintColor: Colors.transparent,

      elevation: 0,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),

      titleTextStyle: GoogleFonts.manrope(
        color: kInk,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),

      contentTextStyle: GoogleFonts.manrope(
        color: kMutedInk,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
    ),

    // --------------------------------------------------------
    // BOTTOM SHEET
    // --------------------------------------------------------

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: kSurface,

      surfaceTintColor: Colors.transparent,

      elevation: 0,

      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
    ),

    // --------------------------------------------------------
    // SNACKBAR
    // --------------------------------------------------------

    snackBarTheme: SnackBarThemeData(
      backgroundColor: kInk,
      contentTextStyle: GoogleFonts.manrope(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),

      behavior: SnackBarBehavior.floating,

      elevation: 0,
    ),

    // --------------------------------------------------------
    // TOOLTIP
    // --------------------------------------------------------

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: kInk,
        borderRadius: BorderRadius.circular(10),
      ),

      textStyle: GoogleFonts.manrope(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),

    // --------------------------------------------------------
    // DROPDOWN MENU
    // --------------------------------------------------------

    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: GoogleFonts.manrope(
        color: kInk,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),

      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(
          kSurface,
        ),

        elevation: const WidgetStatePropertyAll(
          0,
        ),

        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(
              color: kLine,
            ),
          ),
        ),
      ),
    ),

    // --------------------------------------------------------
    // MENU
    // --------------------------------------------------------

    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(
          kSurface,
        ),

        elevation: const WidgetStatePropertyAll(
          0,
        ),

        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(
              color: kLine,
            ),
          ),
        ),

        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            vertical: 8,
          ),
        ),
      ),
    ),

    // --------------------------------------------------------
    // TAB BAR
    // --------------------------------------------------------

    tabBarTheme: TabBarThemeData(
      labelColor: kInk,
      unselectedLabelColor: kMutedInk,

      labelStyle: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),

      unselectedLabelStyle: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),

      indicatorColor: kInk,

      dividerColor: kLine,

      indicatorSize: TabBarIndicatorSize.label,
    ),

    // --------------------------------------------------------
    // NAVIGATION BAR
    // --------------------------------------------------------

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: kSurface,

      surfaceTintColor: Colors.transparent,

      elevation: 0,

      height: 72,

      labelTextStyle: WidgetStatePropertyAll(
        GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),

      indicatorColor: kSoft,
    ),

    // --------------------------------------------------------
    // NAVIGATION RAIL
    // --------------------------------------------------------

    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: kSurface,

      elevation: 0,

      selectedIconTheme: const IconThemeData(
        color: kInk,
      ),

      unselectedIconTheme: const IconThemeData(
        color: kMutedInk,
      ),

      selectedLabelTextStyle: GoogleFonts.manrope(
        color: kInk,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),

      unselectedLabelTextStyle: GoogleFonts.manrope(
        color: kMutedInk,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),

      indicatorColor: kSoft,
    ),

    // --------------------------------------------------------
    // LIST TILE
    // --------------------------------------------------------

    listTileTheme: ListTileThemeData(
      textColor: kInk,

      iconColor: kMutedInk,

      titleTextStyle: GoogleFonts.manrope(
        color: kInk,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),

      subtitleTextStyle: GoogleFonts.manrope(
        color: kMutedInk,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),

    // --------------------------------------------------------
    // DATA TABLE
    // --------------------------------------------------------

    dataTableTheme: DataTableThemeData(
      headingTextStyle: GoogleFonts.manrope(
        color: kInk,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),

      dataTextStyle: GoogleFonts.manrope(
        color: kInk,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),

      dividerThickness: 1,

      headingRowColor: const WidgetStatePropertyAll(
        kSoft,
      ),
    ),

    // --------------------------------------------------------
    // PROGRESS INDICATOR
    // --------------------------------------------------------

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: kInk,
      linearTrackColor: kSoft,
      circularTrackColor: kSoft,
    ),

    // --------------------------------------------------------
    // DIVIDER
    // --------------------------------------------------------

    dividerTheme: const DividerThemeData(
      color: kLine,
      thickness: 1,
      space: 1,
    ),

    // --------------------------------------------------------
    // CHECKBOX
    // --------------------------------------------------------

    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5),
      ),

      side: const BorderSide(
        color: kLine,
        width: 1.5,
      ),

      fillColor: WidgetStateProperty.resolveWith<Color?>(
        (states) {
          if (states.contains(WidgetState.selected)) {
            return kInk;
          }

          return Colors.transparent;
        },
      ),

      checkColor: const WidgetStatePropertyAll(
        Colors.white,
      ),
    ),

    // --------------------------------------------------------
    // RADIO
    // --------------------------------------------------------

    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color?>(
        (states) {
          if (states.contains(WidgetState.selected)) {
            return kInk;
          }

          return kMutedInk;
        },
      ),
    ),

    // --------------------------------------------------------
    // SWITCH
    // --------------------------------------------------------

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color?>(
        (states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }

          return kMutedInk;
        },
      ),

      trackColor: WidgetStateProperty.resolveWith<Color?>(
        (states) {
          if (states.contains(WidgetState.selected)) {
            return kInk;
          }

          return kSoft;
        },
      ),

      trackOutlineColor: WidgetStatePropertyAll(
        kLine,
      ),
    ),

    // --------------------------------------------------------
    // SLIDER
    // --------------------------------------------------------

    sliderTheme: SliderThemeData(
      activeTrackColor: kInk,
      inactiveTrackColor: kSoft,

      thumbColor: kInk,

      overlayColor: kSoft,

      valueIndicatorColor: kInk,

      valueIndicatorTextStyle: GoogleFonts.manrope(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

// ============================================================
// CARD DECORATION
// ============================================================

BoxDecoration softCardDecoration({
  double radius = 24,
  bool border = true,
  bool shadow = false,
}) {
  return BoxDecoration(
    color: kSurface,

    borderRadius: BorderRadius.circular(
      radius,
    ),

    border: border
        ? Border.all(
            color: kLine,
          )
        : null,

    boxShadow: shadow
        ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.055),
              blurRadius: 26,
              offset: const Offset(
                0,
                12,
              ),
            ),
          ]
        : null,
  );
}

// ============================================================
// STATUS FORMATTER
// ============================================================

String prettyStatus(String value) {
  final normalized = value
      .replaceAll('_', ' ')
      .trim();

  if (normalized.isEmpty) {
    return 'Unknown';
  }

  return normalized
      .split(RegExp(r'\s+'))
      .map(
        (part) {
          if (part.isEmpty) {
            return part;
          }

          return '${part[0].toUpperCase()}'
              '${part.substring(1).toLowerCase()}';
        },
      )
      .join(' ');
}

