import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String change;
  final IconData icon;
  final double? compactPadding;
  final double? compactIconSize;
  final double? compactValueSize;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.change,
    required this.icon,
    this.compactPadding,
    this.compactIconSize,
    this.compactValueSize,
  });

  @override
  Widget build(BuildContext context) {
    final padding = compactPadding ?? 16.0;
    final iconSize = compactIconSize ?? 19.0;
    final valueSize = compactValueSize ?? 22.0;
    final containerSize = compactPadding != null ? 32.0 : 36.0;
    final borderRadius = compactPadding != null ? 8.0 : 10.0;
    final isCompact = compactPadding != null;

    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                height: containerSize,
                width: containerSize,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                child: Icon(icon, color: AppTheme.primary, size: iconSize),
              ),
              const Spacer(),
              Icon(Icons.more_horiz, size: iconSize, color: AppTheme.textSecondary),
            ],
          ),
          SizedBox(height: isCompact ? 5 : 12),
          Text(title, style: TextStyle(fontSize: isCompact ? 10 : 11, color: AppTheme.textSecondary)),
          const SizedBox(height: 1),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: TextStyle(fontSize: valueSize, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              const SizedBox(width: 5),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(change, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
