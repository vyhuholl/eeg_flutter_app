import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/eeg_data_provider.dart';

/// Y-axis range for adaptive scaling
class YAxisRange {
  final double min;
  final double max;

  const YAxisRange({required this.min, required this.max});
}

/// Real-time EEG chart widget with time-based visualization
class EEGChart extends StatelessWidget {
  final double height;
  final bool showGridLines;
  final bool showAxes;

  const EEGChart({
    super.key,
    this.height = 400,
    this.showGridLines = true,
    this.showAxes = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<EEGDataProvider>(
      builder: (context, eegProvider, child) {
        return Container(
          height: height,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: LineChart(
                  _buildLineChartData(eegProvider),
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.linear,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  LineChartData _buildLineChartData(EEGDataProvider eegProvider) {
    final lineChartData = eegProvider.getJsonLineChartData();
    
    if (lineChartData.isEmpty) {
      return _buildEmptyChart();
    }

    // Calculate adaptive Y-axis range
    final yAxisRange = _calculateAdaptiveYRange(lineChartData);

    return LineChartData(
      lineBarsData: lineChartData,
      minY: yAxisRange.min,
      maxY: yAxisRange.max,
      titlesData: showAxes ? _buildTitlesData() : const FlTitlesData(show: false),
      gridData: showGridLines ? _buildGridData() : const FlGridData(show: false),
      borderData: _buildBorderData(),
      lineTouchData: _buildLineTouchData(),
      clipData: const FlClipData.all(),
    );
  }

  /// Calculate adaptive Y-axis range from chart data
  YAxisRange _calculateAdaptiveYRange(List<LineChartBarData> lineChartData) {
    if (lineChartData.isEmpty) {
      return const YAxisRange(min: 2300, max: 2400); // fallback to default
    }

    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    // Find min and max Y values across all data series
    for (final lineData in lineChartData) {
      for (final spot in lineData.spots) {
        if (spot.y < minY) minY = spot.y;
        if (spot.y > maxY) maxY = spot.y;
      }
    }

    // Handle edge case where min and max are the same
    if (minY == maxY) {
      const padding = 50.0;
      return YAxisRange(min: minY - padding, max: maxY + padding);
    }

    // Add padding (10% of range) to prevent data points from touching edges
    final range = maxY - minY;
    final padding = range * 0.1;
    
    return YAxisRange(
      min: minY - padding,
      max: maxY + padding,
    );
  }

  LineChartData _buildEmptyChart() {
    return LineChartData(
      lineBarsData: [],
      minY: 0,
      maxY: 2500,
      titlesData: const FlTitlesData(show: false),
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
    );
  }

  FlTitlesData _buildTitlesData() {
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          interval: 100,
          getTitlesWidget: (value, meta) {
            return Text(
              value.toInt().toString(),
              style: const TextStyle(fontSize: 10),
            );
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          interval: 10000, // 10 seconds (10000ms)
          getTitlesWidget: (value, meta) {
            final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
            final now = DateTime.now();
            final diff = now.difference(date).inSeconds;
            
            // Show relative time in seconds ago
            if (diff <= 120) {
              return Text(
                '${diff}s',
                style: const TextStyle(fontSize: 10),
              );
            } else {
              // For times older than 120 seconds, show absolute seconds
              return Text(
                '${date.second}s',
                style: const TextStyle(fontSize: 10),
              );
            }
          },
        ),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  FlGridData _buildGridData() {
    return FlGridData(
      show: true,
      drawHorizontalLine: true,
      drawVerticalLine: true,
      horizontalInterval: 100,
      verticalInterval: 10000, // 10 seconds (10000ms)
      getDrawingHorizontalLine: _getDrawingHorizontalLine,
      getDrawingVerticalLine: _getDrawingVerticalLine,
    );
  }

  static FlLine _getDrawingHorizontalLine(double value) {
    return FlLine(
      color: Colors.grey.withValues(alpha: 0.3),
      strokeWidth: 1,
      dashArray: [5, 5],
    );
  }

  static FlLine _getDrawingVerticalLine(double value) {
    return FlLine(
      color: Colors.grey.withValues(alpha: 0.2),
      strokeWidth: 1,
      dashArray: [3, 3],
    );
  }

  FlBorderData _buildBorderData() {
    return FlBorderData(
      show: true,
      border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
    );
  }

  LineTouchData _buildLineTouchData() {
    return LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(
        getTooltipItems: (touchedSpots) {
          return touchedSpots.map((spot) {
            final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
            final timeStr = '${date.second}.${(date.millisecond / 100).floor()}s';
            return LineTooltipItem(
              'EEG: ${spot.y.toStringAsFixed(1)}\nTime: $timeStr',
              const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            );
          }).toList();
        },
      ),
    );
  }
}
