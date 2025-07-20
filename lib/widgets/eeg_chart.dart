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
    this.height = 440,
    this.showGridLines = true,
    this.showAxes = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<EEGDataProvider>(
      builder: (context, eegProvider, child) {
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2E), // Grey background
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(16),
          child: LineChart(
            _buildLineChartData(eegProvider),
            duration: const Duration(milliseconds: 150),
            curve: Curves.linear,
          ),
        );
      },
    );
  }

  LineChartData _buildLineChartData(EEGDataProvider eegProvider) {
    final lineChartData = _buildDualLineChartData(eegProvider);
    
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
      backgroundColor: const Color(0xFF2C2C2E), // Grey background
    );
  }

  /// Build dual line chart data for Focus and Relaxation
  List<LineChartBarData> _buildDualLineChartData(EEGDataProvider eegProvider) {
    final eegData = eegProvider.dataProcessor.eegTimeSeriesData;
    
    if (eegData.isEmpty) return [];
    
    // For demonstration, we'll create two lines from the same data
    // In a real implementation, you would have separate Focus and Relaxation data
    final focusData = eegData.map((spot) => FlSpot(spot.x, spot.y)).toList();
    final relaxationData = eegData.map((spot) => FlSpot(spot.x, spot.y * 0.8 + 100)).toList(); // Offset for visual distinction
    
    return [
      // Focus line (violet)
      LineChartBarData(
        spots: focusData,
        isCurved: false,
        color: const Color(0xFFBF5AF2), // Violet
        barWidth: 2.0,
        isStrokeCapRound: false,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ),
      // Relaxation line (green)
      LineChartBarData(
        spots: relaxationData,
        isCurved: false,
        color: const Color(0xFF32D74B), // Green
        barWidth: 2.0,
        isStrokeCapRound: false,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ),
    ];
  }

  /// Calculate adaptive Y-axis range from chart data
  YAxisRange _calculateAdaptiveYRange(List<LineChartBarData> lineChartData) {
    if (lineChartData.isEmpty) {
      return const YAxisRange(min: 0, max: 100); // fallback to default
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
      maxY: 100,
      titlesData: const FlTitlesData(show: false),
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      backgroundColor: const Color(0xFF2C2C2E),
    );
  }

  FlTitlesData _buildTitlesData() {
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          interval: 25,
          getTitlesWidget: (value, meta) {
            return Text(
              value.toInt().toString(),
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF8E8E93), // Light grey
              ),
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
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF8E8E93), // Light grey
                ),
              );
            } else {
              // For times older than 120 seconds, show absolute seconds
              return Text(
                '${date.second}s',
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF8E8E93), // Light grey
                ),
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
      horizontalInterval: 25,
      verticalInterval: 10000, // 10 seconds (10000ms)
      getDrawingHorizontalLine: _getDrawingHorizontalLine,
      getDrawingVerticalLine: _getDrawingVerticalLine,
    );
  }

  static FlLine _getDrawingHorizontalLine(double value) {
    return FlLine(
      color: const Color(0xFF8E8E93).withValues(alpha: 0.3), // Light grey
      strokeWidth: 1,
      dashArray: [5, 5],
    );
  }

  static FlLine _getDrawingVerticalLine(double value) {
    return FlLine(
      color: const Color(0xFF8E8E93).withValues(alpha: 0.2), // Light grey
      strokeWidth: 1,
      dashArray: [3, 3],
    );
  }

  FlBorderData _buildBorderData() {
    return FlBorderData(
      show: true,
      border: Border.all(
        color: const Color(0xFF8E8E93).withValues(alpha: 0.3), // Light grey
      ),
    );
  }

  LineTouchData _buildLineTouchData() {
    return LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(
        tooltipBgColor: const Color(0xFF2C2C2E),
        getTooltipItems: (touchedSpots) {
          return touchedSpots.map((spot) {
            final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
            final timeStr = '${date.second}.${(date.millisecond / 100).floor()}s';
            final lineType = spot.barIndex == 0 ? 'Фокус' : 'Расслабление';
            return LineTooltipItem(
              '$lineType: ${spot.y.toStringAsFixed(1)}\nВремя: $timeStr',
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
