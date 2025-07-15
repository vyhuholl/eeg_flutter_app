import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/eeg_data_provider.dart';

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

    return LineChartData(
      lineBarsData: lineChartData,
      minY: -500,
      maxY: 500,
      titlesData: showAxes ? _buildTitlesData() : const FlTitlesData(show: false),
      gridData: showGridLines ? _buildGridData() : const FlGridData(show: false),
      borderData: _buildBorderData(),
      lineTouchData: _buildLineTouchData(),
      clipData: const FlClipData.all(),
    );
  }

  LineChartData _buildEmptyChart() {
    return LineChartData(
      lineBarsData: [],
      minY: -500,
      maxY: 500,
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
          interval: 500, // 0.5 seconds (500ms)
          getTitlesWidget: (value, meta) {
            final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
            final seconds = date.second;
            final milliseconds = date.millisecond;
            
            // Show time in 0.5-second intervals
            if (milliseconds < 250) {
              return Text(
                '${seconds}s',
                style: const TextStyle(fontSize: 10),
              );
            } else {
              return Text(
                '$seconds.5s',
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
      verticalInterval: 500, // 0.5 seconds
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

/// Chart divider widget for dual visualization layout
class ChartDivider extends StatelessWidget {
  final bool isDraggable;
  final VoidCallback? onToggleSpectrum;
  final bool isSpectrumVisible;

  const ChartDivider({
    super.key,
    this.isDraggable = true,
    this.onToggleSpectrum,
    this.isSpectrumVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border.symmetric(
          horizontal: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isDraggable)
            Icon(
              Icons.drag_handle,
              color: Colors.grey.withValues(alpha: 0.6),
              size: 16,
            ),
          if (isDraggable) const SizedBox(width: 8),
          Text(
            'Power Spectrum',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          if (onToggleSpectrum != null) const SizedBox(width: 8),
          if (onToggleSpectrum != null)
            IconButton(
              icon: Icon(
                isSpectrumVisible ? Icons.visibility : Icons.visibility_off,
                size: 16,
                color: Colors.grey.withValues(alpha: 0.6),
              ),
              onPressed: onToggleSpectrum,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact EEG chart for overview display
class CompactEEGChart extends StatelessWidget {
  final double height;
  final int channelIndex;

  const CompactEEGChart({
    super.key,
    this.height = 120,
    required this.channelIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<EEGDataProvider>(
      builder: (context, eegProvider, child) {
        final data = eegProvider.getChannelData(channelIndex);
        
        if (data.isEmpty) {
          return Container(
            height: height,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('No data'),
            ),
          );
        }

        return Container(
          height: height,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: LineChart(
            LineChartData(
              lineBarsData: [
                LineChartBarData(
                  spots: data,
                  isCurved: false,
                  color: Theme.of(context).primaryColor,
                  barWidth: 1,
                  isStrokeCapRound: false,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: false),
                ),
              ],
              minY: -500,
              maxY: 500,
              titlesData: const FlTitlesData(show: false),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
            ),
          ),
        );
      },
    );
  }
} 