import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/electrode_validation_provider.dart';

/// Widget that displays the current electrode validation status
/// Shows green text for good connection, red text for poor connection
class ElectrodeStatusWidget extends StatelessWidget {
  /// Whether to show the status indicator
  final bool show;
  
  /// Custom positioning from top
  final double? top;
  
  /// Custom positioning from left
  final double? left;

  const ElectrodeStatusWidget({
    super.key,
    this.show = true,
    this.top,
    this.left,
  });

  @override
  Widget build(BuildContext context) {
    if (!show) {
      return const SizedBox.shrink();
    }

    return Consumer<ElectrodeValidationProvider>(
      builder: (context, provider, child) {
        // Show different states based on validation status
        Color backgroundColor;
        IconData iconData;
        String statusText;

        if (!provider.hasValidationResult) {
          // No validation data yet - show checking state
          backgroundColor = Colors.orange.withValues(alpha: 0.9);
          iconData = Icons.help_outline;
          statusText = 'Проверка электродов...';
        } else {
          final result = provider.lastValidationResult!;
          final isValid = result.isValid;
          backgroundColor = isValid ? Colors.green.withValues(alpha: 0.9) : Colors.red.withValues(alpha: 0.9);
          iconData = isValid ? Icons.check_circle : Icons.error;
          statusText = isValid ? 'Электроды подключены' : 'Проблемы с контактом электродов';
        }

        return Positioned(
          top: top ?? 16.0,
          left: left ?? 16.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  iconData,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  statusText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Simple electrode status indicator without positioning
/// Useful for embedding in existing layouts
class ElectrodeStatusIndicator extends StatelessWidget {
  const ElectrodeStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ElectrodeValidationProvider>(
      builder: (context, provider, child) {
        // Don't show if no validation data available
        if (!provider.hasValidationResult) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.help_outline,
                  color: Colors.white,
                  size: 16,
                ),
                SizedBox(width: 6),
                Text(
                  'Проверка электродов...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        final result = provider.lastValidationResult!;
        final isValid = result.isValid;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isValid ? Colors.green.withValues(alpha: 0.9) : Colors.red.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isValid ? Icons.check_circle : Icons.error,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                isValid ? 'Электроды подключены' : 'Проблемы с контактом электродов',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
} 