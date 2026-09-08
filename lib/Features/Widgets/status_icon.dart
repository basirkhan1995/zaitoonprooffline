import 'package:flutter/material.dart';
import 'package:zaitoonpro/Localizations/l10n/translations/app_localizations.dart';

/// ===============================
/// 1️⃣ Status Enum
/// ===============================
enum TxStatus {
  pending,
  completed,
}

/// ===============================
/// 2️⃣ String → Status
/// ===============================
TxStatus parseStatus(String? value) {
  switch (value?.toLowerCase()) {
    case 'authorized':  // ✅ Check for lowercase
      return TxStatus.completed;
    case 'pending':     // ✅ Check for lowercase (optional)
      return TxStatus.pending;
    default:
      return TxStatus.pending;
  }
}

/// ===============================
/// 3️⃣ Status Style
/// ===============================
class StatusStyle {
  final Color color;
  final IconData icon;

  const StatusStyle({
    required this.color,
    required this.icon,
  });

  static StatusStyle getStyle(TxStatus status) {
    switch (status) {
      case TxStatus.completed:
        return const StatusStyle(
          color: Color(0xFF2E7D32),
          icon: Icons.check_circle_rounded,
        );
      case TxStatus.pending:
        return const StatusStyle(
          color: Color(0xFFF9A825),
          icon: Icons.schedule_rounded,
        );
    }
  }
}

/// ===============================
/// 4️⃣ Status Icon (with background)
/// ===============================
class StatusIcon extends StatelessWidget {
  final String status; // "Pending" or "Completed"
  final double size;

  const StatusIcon({
    super.key,
    required this.status,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    final txStatus = parseStatus(status);
    final style = StatusStyle.getStyle(txStatus);

    return Container(
      padding: EdgeInsets.all(size * 0.3),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        style.icon,
        size: size,
        color: style.color,
      ),
    );
  }
}

/// ===============================
/// 5️⃣ Simple Status Icon (no background)
/// ===============================
class SimpleStatusIcon extends StatelessWidget {
  final String status; // "Pending" or "Completed"
  final double size;

  const SimpleStatusIcon({
    super.key,
    required this.status,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    final txStatus = parseStatus(status);
    final style = StatusStyle.getStyle(txStatus);

    return Icon(
      style.icon,
      size: size,
      color: style.color,
    );
  }
}

/// ===============================
/// 6️⃣ Status Badge (with label)
/// ===============================
class StatusBadge extends StatelessWidget {
  final String status; // "Pending" or "Completed"
  final bool showLabel;

  const StatusBadge({
    super.key,
    required this.status,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final txStatus = parseStatus(status);
    final style = StatusStyle.getStyle(txStatus);

    final label = txStatus == TxStatus.completed
        ? tr.completedTitle
        : tr.pendingTitle;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showLabel ? 8 : 4,
        vertical: showLabel ? 3 : 2,
      ),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: style.color.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 14, color: style.color),
          if (showLabel) ...[
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: style.color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}