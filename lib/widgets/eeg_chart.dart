import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/eeg_data_provider.dart';
import '../providers/connection_provider.dart';
import '../models/eeg_data.dart';

/// Y-axis range for adaptive scaling
class YAxisRange {
  final double min;
  final double max;

  const YAxisRange({required this.min, required this.max});
}

/// X-axis range for time window control
class XAxisRange {
  final double min;
  final double max;

  const XAxisRange({required this.min, required this.max});
}

/// Chart modes for different screens
enum EEGChartMode {
  main,       // Main screen with focus + relaxation lines
  meditation, // Meditation screen with Pope + BTR/ATR/GTR lines
}

/// Real-time EEG chart widget with time-based visualization
class EEGChart extends StatelessWidget {
  final double height;
  final bool showGridLines;
  final bool showAxes;
  final EEGChartMode chartMode;

  const EEGChart({
    super.key,
    this.height = 440,
    this.showGridLines = true,
    this.showAxes = true,
    this.chartMode = EEGChartMode.main,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<EEGDataProvider, ConnectionProvider>(
      builder: (context, eegProvider, connectionProvider, child) {
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2E), // Grey background
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(16),
          child: LineChart(
            _buildLineChartData(eegProvider, connectionProvider),
            duration: const Duration(milliseconds: 0), // No animation for real-time data
            curve: Curves.linear,
          ),
        );
      },
    );
  }

  LineChartData _buildLineChartData(EEGDataProvider eegProvider, ConnectionProvider connectionProvider) {
    final lineChartData = chartMode == EEGChartMode.meditation 
        ? _buildMeditationChartData(eegProvider, connectionProvider)
        : _buildMainChartData(eegProvider, connectionProvider);
    
    if (lineChartData.isEmpty) {
      return _buildEmptyChart();
    }

    // Calculate adaptive Y-axis range
    final yAxisRange = _calculateAdaptiveYRange(lineChartData);
    
    // Calculate X-axis range for 120-second window
    final connectionStartTime = connectionProvider.connectionStartTime;
    final xAxisRange = _calculateXAxisRange(connectionStartTime);

    return LineChartData(
      lineBarsData: lineChartData,
      minX: xAxisRange.min,
      maxX: xAxisRange.max,
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

  /// Build main screen chart data with focus + relaxation lines  
  List<LineChartBarData> _buildMainChartData(EEGDataProvider eegProvider, ConnectionProvider connectionProvider) {
    final jsonSamples = eegProvider.dataProcessor.getLatestJsonSamples();
    final connectionStartTime = connectionProvider.connectionStartTime;
    
    if (jsonSamples.isEmpty || connectionStartTime == null) return [];
    
    // Filter to show last 120 seconds of data, or all data since connection if less than 120 seconds
    final now = DateTime.now();
    final timeSinceConnection = now.difference(connectionStartTime).inSeconds;
    
    final cutoffTime = timeSinceConnection > 120 
        ? now.millisecondsSinceEpoch - (120 * 1000)  // Show last 120 seconds
        : connectionStartTime.millisecondsSinceEpoch; // Show all data since connection
        
    final recentSamples = jsonSamples.where((sample) => 
      sample.absoluteTimestamp.millisecondsSinceEpoch >= cutoffTime).toList();
    
    if (recentSamples.isEmpty) return [];
    
    // Calculate brainwave ratios and apply moving average to both focus and relaxation
    final focusData = _calculateFocusMovingAverage(recentSamples, connectionStartTime);
    final relaxationData = _calculateRelaxationMovingAverage(recentSamples, connectionStartTime);
    
    final lines = <LineChartBarData>[];
    
    // Add focus line (violet) if we have data
    if (focusData.isNotEmpty) {
      lines.add(LineChartBarData(
        spots: focusData,
        isCurved: false,
        color: const Color(0xFFBF5AF2), // Violet
        barWidth: 2.0,
        isStrokeCapRound: false,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }
    
    // Add relaxation line (green) if we have data
    if (relaxationData.isNotEmpty) {
      lines.add(LineChartBarData(
        spots: relaxationData,
        isCurved: false,
        color: const Color(0xFF32D74B), // Green
        barWidth: 2.0,
        isStrokeCapRound: false,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }
    
    return lines;
  }

  /// Calculate 10-second moving average for focus values using O(n) sliding window approach
  List<FlSpot> _calculateFocusMovingAverage(List<EEGJsonSample> samples, DateTime connectionStartTime) {
    final focusData = <FlSpot>[];
    const movingAverageWindowMs = 10 * 1000; // 10 seconds in milliseconds
    
    if (samples.isEmpty) return focusData;
    
    // Sliding window variables for O(n) complexity
    double runningSum = 0.0;
    int validSamplesCount = 0;
    int windowStart = 0;
    
    for (int i = 0; i < samples.length; i++) {
      final currentSample = samples[i];
      final currentTimestamp = currentSample.absoluteTimestamp.millisecondsSinceEpoch.toDouble();
      final relativeTimeSeconds = currentSample.absoluteTimestamp.difference(connectionStartTime).inMilliseconds.toDouble() / 1000.0;
      
      // Skip samples with invalid Pope values
      if (currentSample.pope == 0.0) continue;
      
      // Add current sample to window
      runningSum += currentSample.pope;
      validSamplesCount++;
      
      // Remove samples that fall outside the 10-second window
      final windowStartTime = currentTimestamp - movingAverageWindowMs;
      while (windowStart <= i) {
        final windowSample = samples[windowStart];
        final windowSampleTimestamp = windowSample.absoluteTimestamp.millisecondsSinceEpoch.toDouble();
        
        if (windowSampleTimestamp >= windowStartTime) {
          break; // This sample is still within the window
        }
        
        // Remove this sample from the running calculation
        if (windowSample.pope != 0.0) {
          runningSum -= windowSample.pope;
          validSamplesCount--;
        }
        windowStart++;
      }
      
      // Calculate moving average if we have valid data
      if (validSamplesCount > 0) {
        final average = runningSum / validSamplesCount;
        focusData.add(FlSpot(relativeTimeSeconds, average));
      }
    }
    
    return focusData;
  }

  /// Calculate 10-second moving average for relaxation values using O(n) sliding window approach
  List<FlSpot> _calculateRelaxationMovingAverage(List<EEGJsonSample> samples, DateTime connectionStartTime) {
    final relaxationData = <FlSpot>[];
    const movingAverageWindowMs = 10 * 1000; // 10 seconds in milliseconds
    
    if (samples.isEmpty) return relaxationData;
    
    // Sliding window variables for O(n) complexity
    double runningSum = 0.0;
    int validSamplesCount = 0;
    int windowStart = 0;
    
    for (int i = 0; i < samples.length; i++) {
      final currentSample = samples[i];
      final currentTimestamp = currentSample.absoluteTimestamp.millisecondsSinceEpoch.toDouble();
      final relativeTimeSeconds = currentSample.absoluteTimestamp.difference(connectionStartTime).inMilliseconds.toDouble() / 1000.0;
      
      // Skip samples with invalid RAB values
      if (currentSample.rab == 0.0) continue;
      
      // Add current sample to window
      runningSum += currentSample.rab;
      validSamplesCount++;
      
      // Remove samples that fall outside the 10-second window
      final windowStartTime = currentTimestamp - movingAverageWindowMs;
      while (windowStart <= i) {
        final windowSample = samples[windowStart];
        final windowSampleTimestamp = windowSample.absoluteTimestamp.millisecondsSinceEpoch.toDouble();
        
        if (windowSampleTimestamp >= windowStartTime) {
          break; // This sample is still within the window
        }
        
        // Remove this sample from the running calculation
        if (windowSample.rab != 0.0) {
          runningSum -= windowSample.rab;
          validSamplesCount--;
        }
        windowStart++;
      }
      
      // Calculate moving average if we have valid data
      if (validSamplesCount > 0) {
        final average = runningSum / validSamplesCount;
        relaxationData.add(FlSpot(relativeTimeSeconds, average));
      }
    }
    
    return relaxationData;
  }

  /// Build meditation screen chart data with Pope, BTR, ATR, GTR lines
  List<LineChartBarData> _buildMeditationChartData(EEGDataProvider eegProvider, ConnectionProvider connectionProvider) {
    final jsonSamples = eegProvider.dataProcessor.getLatestJsonSamples();
    final connectionStartTime = connectionProvider.connectionStartTime;
    
    if (jsonSamples.isEmpty || connectionStartTime == null) return [];
    
    // Filter to show last 120 seconds of data, or all data since connection if less than 120 seconds
    final now = DateTime.now();
    final timeSinceConnection = now.difference(connectionStartTime).inSeconds;
    
    final cutoffTime = timeSinceConnection > 120 
        ? now.millisecondsSinceEpoch - (120 * 1000)  // Show last 120 seconds
        : connectionStartTime.millisecondsSinceEpoch; // Show all data since connection
        
    final recentSamples = jsonSamples.where((sample) => 
      sample.absoluteTimestamp.millisecondsSinceEpoch >= cutoffTime).toList();
    
    if (recentSamples.isEmpty) return [];
    
    // Calculate meditation-specific lines
    final popeData = _calculateFocusMovingAverage(recentSamples, connectionStartTime); // Reuse for Pope line
    final btrData = <FlSpot>[];
    final atrData = <FlSpot>[];
    final gtrData = <FlSpot>[];
    
    // Calculate BTR, ATR, GTR lines (theta-based ratios) using relative time with fractional seconds
    for (final sample in recentSamples) {
      final relativeTimeSeconds = sample.absoluteTimestamp.difference(connectionStartTime).inMilliseconds.toDouble() / 1000.0;
      
      btrData.add(FlSpot(relativeTimeSeconds, sample.btr));
      atrData.add(FlSpot(relativeTimeSeconds, sample.atr));
      gtrData.add(FlSpot(relativeTimeSeconds, sample.gtr));
    }
    
    final lines = <LineChartBarData>[];
    
    // Add BTR line (orange) if we have data - moved up to draw below Pope line
    if (btrData.isNotEmpty) {
      lines.add(LineChartBarData(
        spots: btrData,
        isCurved: false,
        color: const Color(0xFFFF9500), // Orange
        barWidth: 1.0, // Made thinner
        isStrokeCapRound: false,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }
    
    // Add ATR line (blue) if we have data - moved up to draw below Pope line
    if (atrData.isNotEmpty) {
      lines.add(LineChartBarData(
        spots: atrData,
        isCurved: false,
        color: const Color(0xFF007AFF), // Blue
        barWidth: 1.0, // Made thinner
        isStrokeCapRound: false,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }
    
    // Add GTR line (red) if we have data - moved up to draw below Pope line
    if (gtrData.isNotEmpty) {
      lines.add(LineChartBarData(
        spots: gtrData,
        isCurved: false,
        color: const Color(0xFFFF3B30), // Red
        barWidth: 1.0, // Made thinner
        isStrokeCapRound: false,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }
    
    // Add Pope line (violet) last so it appears on top of all other lines
    if (popeData.isNotEmpty) {
      lines.add(LineChartBarData(
        spots: popeData,
        isCurved: false,
        color: const Color(0xFFBF5AF2), // Violet
        barWidth: 1.0, // Made thinner
        isStrokeCapRound: false,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }
    
    return lines;
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

  /// Calculate X-axis range for 120-second time window
  XAxisRange _calculateXAxisRange(DateTime? connectionStartTime) {
    if (connectionStartTime == null) {
      return const XAxisRange(min: 0, max: 120);
    }

    final now = DateTime.now();
    final timeSinceConnection = now.difference(connectionStartTime).inMilliseconds.toDouble() / 1000.0;
    
    if (timeSinceConnection <= 120) {
      // Show from connection start to current time
      return XAxisRange(min: 0, max: timeSinceConnection.clamp(10, 120)); // Min 10 seconds for visibility
    } else {
      // Show sliding 120-second window
      return XAxisRange(min: timeSinceConnection - 120, max: timeSinceConnection);
    }
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
          interval: 10, // 10 seconds (now using relative time in seconds)
          getTitlesWidget: (value, meta) {
            final seconds = value.toInt();
            
            // Show relative time in seconds since connection
            return Text(
              '${seconds}s',
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF8E8E93), // Light grey
              ),
            );
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
      verticalInterval: 10, // 10 seconds (now using relative time in seconds)
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
              final seconds = spot.x.toInt();
              final timeStr = '${seconds}s';
              
              // Determine line type based on color and chart mode
              String lineType;
              if (chartMode == EEGChartMode.meditation) {
                // Meditation chart colors
                if (spot.bar.color == const Color(0xFFBF5AF2)) {
                  lineType = 'Pope';
                } else if (spot.bar.color == const Color(0xFFFF9500)) {
                  lineType = 'BTR';
                } else if (spot.bar.color == const Color(0xFF007AFF)) {
                  lineType = 'ATR';
                } else if (spot.bar.color == const Color(0xFFFF3B30)) {
                  lineType = 'GTR';
                } else {
                  lineType = 'Неизвестно';
                }
              } else {
                // Main chart colors
                if (spot.bar.color == const Color(0xFFBF5AF2)) {
                  lineType = 'Фокус';
                } else if (spot.bar.color == const Color(0xFF32D74B)) {
                  lineType = 'Расслабление';
                } else {
                  lineType = 'Неизвестно';
                }
              }
              
              return LineTooltipItem(
                '$lineType: ${spot.y.toStringAsFixed(2)}\nВремя: $timeStr',
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
