import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/eeg_data_provider.dart';
import '../services/data_processor.dart';

/// Real-time EEG chart widget
class EEGChart extends StatelessWidget {
  final double height;
  final bool showGridLines;
  final bool showAxes;
  final bool showLegend;

  const EEGChart({
    super.key,
    this.height = 400,
    this.showGridLines = true,
    this.showAxes = true,
    this.showLegend = true,
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
              if (showLegend) _buildLegend(context, eegProvider),
              if (showLegend) const SizedBox(height: 8),
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
    final lineChartData = eegProvider.getLineChartData();
    
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
          interval: 5000, // 5 seconds
          getTitlesWidget: (value, meta) {
            final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
            return Text(
              '${date.second}s',
              style: const TextStyle(fontSize: 10),
            );
          },
        ),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  FlGridData _buildGridData() {
    return const FlGridData(
      show: true,
      drawHorizontalLine: true,
      drawVerticalLine: false,
      horizontalInterval: 100,
      getDrawingHorizontalLine: _getDrawingHorizontalLine,
    );
  }

  static FlLine _getDrawingHorizontalLine(double value) {
    return FlLine(
      color: Colors.grey.withValues(alpha: 0.3),
      strokeWidth: 1,
      dashArray: [5, 5],
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
            return LineTooltipItem(
              'CH${spot.barIndex + 1}\n${spot.y.toStringAsFixed(1)}\n${date.millisecond}ms',
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

  Widget _buildLegend(BuildContext context, EEGDataProvider eegProvider) {
    final config = eegProvider.config;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Text(
            'Channels: ',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(
                  config.channelCount,
                  (index) => _buildLegendItem(index, eegProvider),
                ),
              ),
            ),
          ),
          _buildDataInfo(eegProvider),
        ],
      ),
    );
  }

  Widget _buildLegendItem(int channel, EEGDataProvider eegProvider) {
    final config = eegProvider.config;
    final signalQuality = eegProvider.signalQuality[channel];
    
    final colors = [
      const Color(0xFF2196F3), // Blue
      const Color(0xFF4CAF50), // Green
      const Color(0xFFF44336), // Red
      const Color(0xFF9C27B0), // Purple
      const Color(0xFFFF9800), // Orange
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFF8BC34A), // Light Green
      const Color(0xFFE91E63), // Pink
    ];

    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: colors[channel % colors.length],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                config.channelNames[channel],
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
              if (signalQuality != null)
                Text(
                  signalQuality.qualityText,
                  style: TextStyle(
                    fontSize: 8,
                    color: _getQualityColor(signalQuality.level),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataInfo(EEGDataProvider eegProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          eegProvider.getSummaryStats(),
          style: const TextStyle(fontSize: 10),
        ),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: eegProvider.isReceivingData ? Colors.green : Colors.red,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  Color _getQualityColor(SignalQualityLevel level) {
    switch (level) {
      case SignalQualityLevel.good:
        return Colors.green;
      case SignalQualityLevel.fair:
        return Colors.orange;
      case SignalQualityLevel.poor:
        return Colors.red;
    }
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