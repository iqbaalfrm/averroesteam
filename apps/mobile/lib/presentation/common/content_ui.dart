import 'package:averroes_core/averroes_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.actionText,
    this.onActionTap,
    this.leadingIcon,
  });

  final String title;
  final String? actionText;
  final VoidCallback? onActionTap;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Expanded(
          child: Row(
            children: <Widget>[
              if (leadingIcon != null) ...<Widget>[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFD1FAE5)),
                  ),
                  child: Icon(leadingIcon, size: 16, color: AppColors.emerald),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate,
                  ),
                ),
              ),
            ],
          ),
        ),
        if ((actionText ?? '').isNotEmpty)
          GestureDetector(
            onTap: onActionTap,
            child: Text(
              actionText!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.emeraldDark,
              ),
            ),
          ),
      ],
    );
  }
}

class AppEmptyStateCard extends StatelessWidget {
  const AppEmptyStateCard({
    super.key,
    required this.text,
    this.icon = Symbols.inbox,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _AppStateCardBase(
      icon: icon,
      message: text,
      backgroundColor: Colors.white,
      borderColor: const Color(0xFFE2E8F0),
      messageColor: AppColors.muted,
      iconColor: AppColors.muted,
    );
  }
}

class AppErrorStateCard extends StatelessWidget {
  const AppErrorStateCard({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Coba lagi',
  });

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return _AppStateCardBase(
      icon: Symbols.error,
      title: 'Terjadi Masalah',
      message: message,
      backgroundColor: const Color(0xFFFEF2F2),
      borderColor: const Color(0xFFFECACA),
      titleColor: const Color(0xFF991B1B),
      messageColor: const Color(0xFFB91C1C),
      iconColor: const Color(0xFFDC2626),
      action: onRetry == null
          ? const SizedBox.shrink()
          : AppSecondaryButton(
              label: retryLabel,
              icon: Symbols.refresh,
              onPressed: onRetry,
              foregroundColor: const Color(0xFFB91C1C),
              borderColor: const Color(0xFFFCA5A5),
            ),
    );
  }
}

class AppLoadingStateCard extends StatelessWidget {
  const AppLoadingStateCard({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _AppStateCardBase(
      leading: Container(
        width: 54,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.emeraldSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD1FAE5)),
        ),
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.emeraldDark),
          ),
        ),
      ),
      title: title,
      message: message,
      backgroundColor: Colors.white,
      borderColor: const Color(0xFFE2E8F0),
      titleColor: AppColors.slate,
      messageColor: AppColors.muted,
      iconColor: AppColors.emeraldDark,
    );
  }
}

class AppInfoStateCard extends StatelessWidget {
  const AppInfoStateCard({
    super.key,
    required this.title,
    required this.message,
    this.icon = Symbols.info,
    this.action,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return _AppStateCardBase(
      icon: icon,
      title: title,
      message: message,
      backgroundColor: Colors.white,
      borderColor: const Color(0xFFE2E8F0),
      titleColor: AppColors.slate,
      messageColor: AppColors.muted,
      iconColor: AppColors.emeraldDark,
      action: action,
    );
  }
}

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Icon(icon ?? Symbols.arrow_forward, size: 18),
      label: Text(
        isLoading ? 'Memuat...' : label,
        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.emeraldDark,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
    );
  }
}

class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.foregroundColor = const Color(0xFF334155),
    this.borderColor = const Color(0xFFCBD5E1),
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color foregroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Symbols.arrow_forward, size: 18),
      label: Text(
        label,
        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: foregroundColor,
        side: BorderSide(color: borderColor),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _AppStateCardBase extends StatelessWidget {
  const _AppStateCardBase({
    this.icon,
    this.leading,
    this.title,
    required this.message,
    required this.backgroundColor,
    required this.borderColor,
    this.titleColor = AppColors.slate,
    required this.messageColor,
    required this.iconColor,
    this.action,
  });

  final IconData? icon;
  final Widget? leading;
  final String? title;
  final String message;
  final Color backgroundColor;
  final Color borderColor;
  final Color titleColor;
  final Color messageColor;
  final Color iconColor;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: <Widget>[
          if (leading != null)
            leading!
          else if (icon != null)
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor.withValues(alpha: 0.85)),
              ),
              child: Icon(icon, size: 22, color: iconColor),
            ),
          const SizedBox(height: 8),
          if ((title ?? '').isNotEmpty) ...<Widget>[
            Text(
              title!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: titleColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
          ],
          Text(
            message,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: messageColor,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          if (action != null && action is! SizedBox) ...<Widget>[
            const SizedBox(height: 10),
            action!,
          ],
        ],
      ),
    );
  }
}
