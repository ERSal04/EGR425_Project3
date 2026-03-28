import 'package:flutter/material.dart';
import 'constants.dart';

// ============ STYLED BUTTON COMPONENTS ============

/// Reusable glowing button with customizable color and callback
class GlowButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  final double fontSize;
  final EdgeInsets padding;
  final bool enabled;

  const GlowButton({
    Key? key,
    required this.label,
    required this.onTap,
    this.color = AppColors.cyan,
    this.fontSize = 10,
    this.padding = AppSpacing.buttonPadding,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: padding,
        decoration: AppDecorations.glowContainer(color: color),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontFamily: 'Courier New',
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            shadows: [Shadow(color: color.withOpacity(0.5), blurRadius: 4)],
          ),
        ),
      ),
    );
  }
}

/// Elevated button for tool actions (Spoof, Tunnel, Crack)
class ToolButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  const ToolButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.cyan,
        disabledBackgroundColor: AppColors.cyan.withOpacity(0.3),
        foregroundColor: AppColors.background,
        padding: AppSpacing.toolButtonPadding,
        elevation: 0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flash_on, size: 14),
          AppSpacing.spacerWidthSmall,
          Text(label),
        ],
      ),
    );
  }
}

/// Debug control button for STATUS, DBG, etc.
class DebugButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;

  const DebugButton({
    Key? key,
    required this.label,
    required this.onTap,
    this.color = AppColors.cyan,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GlowButton(
      label: label,
      color: color,
      onTap: onTap,
      fontSize: 10,
      padding: AppSpacing.buttonPadding,
    );
  }
}

// ============ STAT DISPLAY COMPONENTS ============

/// Reusable stat row for displaying label-value pairs
class StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? labelColor;
  final Color? valueColor;

  const StatRow({
    Key? key,
    required this.label,
    required this.value,
    this.labelColor,
    this.valueColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.paddingSmall,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: labelColor ?? AppColors.yellow,
              fontSize: 11,
              fontFamily: 'Courier New',
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.cyan,
              fontSize: 11,
              fontFamily: 'Courier New',
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Styled container for grouping stat displays
class StatPanel extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Color titleColor;
  final Color borderColor;

  const StatPanel({
    Key? key,
    required this.title,
    required this.children,
    this.titleColor = AppColors.cyan,
    this.borderColor = AppColors.cyan,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.panelDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Padding(
            padding: AppSpacing.paddingMedium,
            child: Text(
              title,
              style: TextStyle(
                color: titleColor,
                fontSize: 12,
                fontFamily: 'Courier New',
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                shadows: [
                  Shadow(color: titleColor.withOpacity(0.6), blurRadius: 6),
                ],
              ),
            ),
          ),
          AppSpacing.spacerSmall,
          // Content
          ...children,
          AppSpacing.spacerSmall,
        ],
      ),
    );
  }
}

// ============ CONNECTION STATUS COMPONENTS ============

/// Connection indicator dot
class ConnectionIndicator extends StatelessWidget {
  final bool isConnected;

  const ConnectionIndicator({Key? key, required this.isConnected})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = isConnected ? AppColors.connected : AppColors.disconnected;

    return Container(
      width: AppSizes.indicatorSize,
      height: AppSizes.indicatorSize,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withOpacity(0.8), blurRadius: 8)],
      ),
    );
  }
}

// ============ TEXT DISPLAY COMPONENTS ============

/// Styled label text (used in panels and dialogs)
class LabelText extends StatelessWidget {
  final String text;
  final Color color;
  final double fontSize;

  const LabelText(
    this.text, {
    Key? key,
    this.color = AppColors.yellow,
    this.fontSize = 11,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontFamily: 'Courier New',
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }
}

/// Styled value text (used in panels and dialogs)
class ValueText extends StatelessWidget {
  final String text;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;

  const ValueText(
    this.text, {
    Key? key,
    this.color = AppColors.cyan,
    this.fontSize = 11,
    this.fontWeight = FontWeight.bold,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontFamily: 'Courier New',
        fontWeight: fontWeight,
        letterSpacing: 0.5,
      ),
    );
  }
}

/// Styled heading text
class HeadingText extends StatelessWidget {
  final String text;
  final Color color;
  final double fontSize;

  const HeadingText(
    this.text, {
    Key? key,
    this.color = AppColors.cyan,
    this.fontSize = 14,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontFamily: 'Courier New',
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
        shadows: [Shadow(color: color.withOpacity(0.6), blurRadius: 6)],
      ),
    );
  }
}

// ============ ERROR/STATUS COMPONENTS ============

/// Styled error message display
class ErrorSnackbarContent extends StatelessWidget {
  final String message;
  final bool isPersistent;

  const ErrorSnackbarContent({
    Key? key,
    required this.message,
    this.isPersistent = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.neonRed.withOpacity(0.1),
        border: Border.all(color: AppColors.neonRed, width: 2),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(color: AppColors.neonRed.withOpacity(0.4), blurRadius: 8),
        ],
      ),
      padding: AppSpacing.paddingMedium,
      child: Text(message, style: AppTextStyles.errorText),
    );
  }
}

/// Styled success message display
class SuccessSnackbarContent extends StatelessWidget {
  final String message;

  const SuccessSnackbarContent({Key? key, required this.message})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.neonGreen.withOpacity(0.1),
        border: Border.all(color: AppColors.neonGreen, width: 2),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(color: AppColors.neonGreen.withOpacity(0.4), blurRadius: 8),
        ],
      ),
      padding: AppSpacing.paddingMedium,
      child: Text(message, style: AppTextStyles.successText),
    );
  }
}

// ============ MISCELLANEOUS COMPONENTS ============

/// A generic glow container that can hold any child widget
class GlowContainer extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsets padding;
  final BorderRadius? borderRadius;

  const GlowContainer({
    Key? key,
    required this.child,
    this.color = AppColors.cyan,
    this.padding = AppSpacing.paddingMedium,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 2),
        borderRadius: borderRadius ?? BorderRadius.circular(4),
        color: color.withOpacity(0.05),
        boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)],
      ),
      child: child,
    );
  }
}

/// Divider line for separating sections
class GlowDivider extends StatelessWidget {
  final Color color;
  final double height;
  final double thickness;

  const GlowDivider({
    Key? key,
    this.color = AppColors.cyan,
    this.height = 1,
    this.thickness = 1,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: color, width: thickness),
        ),
        boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 4)],
      ),
    );
  }
}
