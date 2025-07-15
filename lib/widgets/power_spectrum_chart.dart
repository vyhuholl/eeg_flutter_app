import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/eeg_data.dart';

/// Power spectrum histogram chart widget
class PowerSpectrumChart extends StatefulWidget {
  final PowerSpectrumData? spectrumData;
  final double height;
  final bool showGrid;
  final bool showAxisLabels;
  final bool showInteractiveFeatures;
  final VoidCallback? onTap;

  const PowerSpectrumChart({
    super.key,
    this.spectrumData,
    this.height = 300,
    this.showGrid = true,
    this.showAxisLabels = true,
    this.showInteractiveFeatures = true,
    this.onTap,
  });

  @override
  State<PowerSpectrumChart> createState() => _PowerSpectrumChartState();
}

class _PowerSpectrumChartState extends State<PowerSpectrumChart> {
  int? _hoveredFrequency;
  FrequencyBand? _hoveredBand;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildChartHeader(),
          const SizedBox(height: 8),
          Expanded(
            child: widget.spectrumData == null 
              ? _buildEmptyChart()
              : _buildSpectrumChart(),
          ),
          if (widget.showInteractiveFeatures) _buildFrequencyBandLegend(),
        ],
      ),
    );
  }

  Widget _buildChartHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Power Spectrum (1-49 Hz)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (widget.spectrumData != null) _buildSpectrumInfo(),
      ],
    );
  }

  Widget _buildSpectrumInfo() {
    final spectrum = widget.spectrumData!;
    final peakFreq = spectrum.peakFrequency;
    final totalPower = spectrum.totalPower;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Peak: ${peakFreq ?? 'N/A'}Hz',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
          Text(
            'Total: ${totalPower.toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChart() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart,
              size: 48,
              color: Colors.grey,
            ),
            SizedBox(height: 12),
            Text(
              'No spectrum data available',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Spectrum data will appear when available',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpectrumChart() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 100, // Power percentage 0-100%
        minY: 0,
        barTouchData: widget.showInteractiveFeatures 
          ? _buildBarTouchData() 
          : BarTouchData(enabled: false),
        titlesData: widget.showAxisLabels 
          ? _buildTitlesData() 
          : const FlTitlesData(show: false),
        gridData: widget.showGrid 
          ? _buildGridData() 
          : const FlGridData(show: false),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        barGroups: _buildBarGroups(),
        backgroundColor: Theme.of(context).cardColor.withValues(alpha: 0.05),
      ),
    );
  }

  BarTouchData _buildBarTouchData() {
    return BarTouchData(
      enabled: true,
      handleBuiltInTouches: false,
      touchCallback: (FlTouchEvent event, barTouchResponse) {
        if (event is FlTapUpEvent) {
          widget.onTap?.call();
        }
        
        setState(() {
          if (barTouchResponse != null && 
              barTouchResponse.spot != null &&
              event.isInterestedForInteractions) {
            final touchedIndex = barTouchResponse.spot!.touchedBarGroupIndex;
            final frequency = touchedIndex + 1; // 1-49 Hz
            _hoveredFrequency = frequency;
            _hoveredBand = _getFrequencyBand(frequency);
          } else {
            _hoveredFrequency = null;
            _hoveredBand = null;
          }
        });
      },
      touchTooltipData: BarTouchTooltipData(
        getTooltipItem: (group, groupIndex, rod, rodIndex) {
          final frequency = group.x + 1;
          final power = rod.toY;
          final band = _getFrequencyBand(frequency);
          
          return BarTooltipItem(
            '${frequency}Hz (${band.name})\n${power.toStringAsFixed(1)}%',
            const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          );
        },
      ),
    );
  }

  FlTitlesData _buildTitlesData() {
    return FlTitlesData(
      show: true,
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          interval: 5,
          getTitlesWidget: (value, meta) {
            final freq = value.toInt();
            if (freq % 5 == 0) {
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${freq}Hz',
                  style: const TextStyle(fontSize: 10),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          interval: 20,
          getTitlesWidget: (value, meta) {
            return Text(
              '${value.toInt()}%',
              style: const TextStyle(fontSize: 10),
            );
          },
        ),
      ),
      topTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      rightTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
    );
  }

  FlGridData _buildGridData() {
    return FlGridData(
      show: true,
      horizontalInterval: 20,
      verticalInterval: 10,
      getDrawingHorizontalLine: (value) {
        return FlLine(
          color: Colors.grey.withValues(alpha: 0.2),
          strokeWidth: 1,
          dashArray: [3, 3],
        );
      },
      getDrawingVerticalLine: (value) {
        return FlLine(
          color: Colors.grey.withValues(alpha: 0.1),
          strokeWidth: 1,
        );
      },
    );
  }

  List<BarChartGroupData> _buildBarGroups() {
    final barGroups = <BarChartGroupData>[];
    
    for (int freq = 1; freq <= 49; freq++) {
      final power = widget.spectrumData!.getPowerAt(freq) ?? 0.0;
      final isHovered = _hoveredFrequency == freq;
      final band = _getFrequencyBand(freq);
      final isBandHovered = _hoveredBand == band;
      
      barGroups.add(
        BarChartGroupData(
          x: freq - 1, // 0-48 for chart indexing
          barRods: [
            BarChartRodData(
              toY: power,
              color: _getBarColor(freq, isHovered, isBandHovered),
              width: _getBarWidth(freq, isHovered),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(2),
              ),
            ),
          ],
        ),
      );
    }
    
    return barGroups;
  }

  Color _getBarColor(int frequency, bool isHovered, bool isBandHovered) {
    final band = _getFrequencyBand(frequency);
    Color baseColor;
    
    switch (band) {
      case FrequencyBand.delta:
        baseColor = const Color(0xFF1565C0); // Deep Blue
        break;
      case FrequencyBand.theta:
        baseColor = const Color(0xFF1976D2); // Blue
        break;
      case FrequencyBand.alpha:
        baseColor = const Color(0xFF388E3C); // Green
        break;
      case FrequencyBand.beta:
        baseColor = const Color(0xFFF57C00); // Orange
        break;
      case FrequencyBand.gamma:
        baseColor = const Color(0xFFD32F2F); // Red
        break;
    }
    
    if (isHovered) {
      return baseColor.withValues(alpha: 1.0);
    } else if (isBandHovered) {
      return baseColor.withValues(alpha: 0.7);
    } else {
      return baseColor.withValues(alpha: 0.8);
    }
  }

  double _getBarWidth(int frequency, bool isHovered) {
    return isHovered ? 3.0 : 2.0;
  }

  FrequencyBand _getFrequencyBand(int frequency) {
    for (final band in FrequencyBand.values) {
      if (frequency >= band.minFreq && frequency <= band.maxFreq) {
        return band;
      }
    }
    return FrequencyBand.gamma; // Default fallback
  }

  Widget _buildFrequencyBandLegend() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Frequency Bands',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: FrequencyBand.values.map((band) {
              final isHovered = _hoveredBand == band;
              
              return GestureDetector(
                onTap: () => _highlightBand(band),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isHovered 
                      ? _getBandColor(band).withValues(alpha: 0.2)
                      : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _getBandColor(band),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${band.name} (${band.minFreq}-${band.maxFreq}Hz)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isHovered ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color _getBandColor(FrequencyBand band) {
    switch (band) {
      case FrequencyBand.delta:
        return const Color(0xFF1565C0);
      case FrequencyBand.theta:
        return const Color(0xFF1976D2);
      case FrequencyBand.alpha:
        return const Color(0xFF388E3C);
      case FrequencyBand.beta:
        return const Color(0xFFF57C00);
      case FrequencyBand.gamma:
        return const Color(0xFFD32F2F);
    }
  }

  void _highlightBand(FrequencyBand band) {
    setState(() {
      _hoveredBand = _hoveredBand == band ? null : band;
      _hoveredFrequency = null;
    });
  }
} 