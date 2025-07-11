import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/eeg_data.dart';
import '../services/data_processor.dart';

/// Provider for EEG data state management
class EEGDataProvider extends ChangeNotifier {
  final EEGDataProcessor _dataProcessor;
  StreamSubscription<List<EEGSample>>? _dataSubscription;
  
  List<EEGSample> _latestSamples = [];
  final Map<int, List<FlSpot>> _chartData = {};
  final Map<int, SignalStats> _signalStats = {};
  final Map<int, SignalQuality> _signalQuality = {};
  
  // Display settings
  int _selectedChannel = 0;
  bool _showAllChannels = true;
  double _timeWindow = 10.0; // seconds
  double _amplitudeScale = 1.0;
  bool _filterEnabled = false;

  EEGDataProvider({required EEGConfig config}) 
    : _dataProcessor = EEGDataProcessor(config: config) {
    _initializeChartData();
  }

  /// Latest EEG samples
  List<EEGSample> get latestSamples => _latestSamples;
  
  /// Chart data for visualization
  Map<int, List<FlSpot>> get chartData => _chartData;
  
  /// Signal statistics for each channel
  Map<int, SignalStats> get signalStats => _signalStats;
  
  /// Signal quality for each channel
  Map<int, SignalQuality> get signalQuality => _signalQuality;
  
  /// Current EEG configuration
  EEGConfig get config => _dataProcessor.config;
  
  /// Data processor instance
  EEGDataProcessor get dataProcessor => _dataProcessor;
  
  /// Display settings
  int get selectedChannel => _selectedChannel;
  bool get showAllChannels => _showAllChannels;
  double get timeWindow => _timeWindow;
  double get amplitudeScale => _amplitudeScale;
  bool get filterEnabled => _filterEnabled;

  void _initializeChartData() {
    for (int i = 0; i < config.channelCount; i++) {
      _chartData[i] = [];
      _signalStats[i] = SignalStats.empty();
      _signalQuality[i] = SignalQuality(
        level: SignalQualityLevel.good,
        snr: 0,
        artifacts: [],
      );
    }
  }

  /// Start listening to data updates
  void startDataStream() {
    _dataSubscription = _dataProcessor.processedDataStream.listen(
      _onDataReceived,
      onError: _onDataError,
    );
    _dataProcessor.startProcessing();
  }

  /// Stop listening to data updates
  void stopDataStream() {
    _dataSubscription?.cancel();
    _dataSubscription = null;
    _dataProcessor.stopProcessing();
  }

  /// Process a new EEG sample
  void processSample(EEGSample sample) {
    _dataProcessor.processSample(sample);
  }

  void _onDataReceived(List<EEGSample> samples) {
    _latestSamples = samples;
    
    // Update chart data
    _updateChartData();
    
    // Update signal statistics
    _updateSignalStats();
    
    // Update signal quality
    _updateSignalQuality();
    
    notifyListeners();
  }

  void _onDataError(error) {
    debugPrint('EEG data error: $error');
  }

  void _updateChartData() {
    final allChartData = _dataProcessor.getAllChartData();
    
    // Apply time window filtering
    final now = DateTime.now().millisecondsSinceEpoch.toDouble();
    final timeWindowMs = _timeWindow * 1000;
    
    for (int channel = 0; channel < config.channelCount; channel++) {
      final channelData = allChartData[channel] ?? [];
      
      // Filter data by time window
      final filteredData = channelData
          .where((spot) => (now - spot.x) <= timeWindowMs)
          .toList();
      
      // Apply amplitude scaling
      final scaledData = filteredData.map((spot) => 
        FlSpot(spot.x, spot.y * _amplitudeScale)
      ).toList();
      
      _chartData[channel] = scaledData;
    }
  }

  void _updateSignalStats() {
    for (int channel = 0; channel < config.channelCount; channel++) {
      _signalStats[channel] = _dataProcessor.calculateStats(channel);
    }
  }

  void _updateSignalQuality() {
    for (int channel = 0; channel < config.channelCount; channel++) {
      _signalQuality[channel] = _dataProcessor.getSignalQuality(channel);
    }
  }

  /// Get chart data for a specific channel
  List<FlSpot> getChannelData(int channel) {
    if (channel >= config.channelCount) return [];
    return _chartData[channel] ?? [];
  }

  /// Get line chart data for fl_chart
  List<LineChartBarData> getLineChartData() {
    final lines = <LineChartBarData>[];
    
    if (_showAllChannels) {
      // Show all channels
      for (int i = 0; i < config.channelCount; i++) {
        lines.add(_createLineChartBarData(i));
      }
    } else {
      // Show only selected channel
      lines.add(_createLineChartBarData(_selectedChannel));
    }
    
    return lines;
  }

  LineChartBarData _createLineChartBarData(int channel) {
    final data = getChannelData(channel);
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
    
    return LineChartBarData(
      spots: data,
      isCurved: false,
      color: colors[channel % colors.length],
      barWidth: 1.5,
      isStrokeCapRound: false,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  /// Update display settings
  void setSelectedChannel(int channel) {
    if (channel >= 0 && channel < config.channelCount) {
      _selectedChannel = channel;
      notifyListeners();
    }
  }

  void setShowAllChannels(bool show) {
    _showAllChannels = show;
    notifyListeners();
  }

  void setTimeWindow(double seconds) {
    if (seconds > 0) {
      _timeWindow = seconds;
      notifyListeners();
    }
  }

  void setAmplitudeScale(double scale) {
    if (scale > 0) {
      _amplitudeScale = scale;
      notifyListeners();
    }
  }

  void setFilterEnabled(bool enabled) {
    _filterEnabled = enabled;
    // TODO: Implement actual filtering
    notifyListeners();
  }

  /// Clear all data
  void clearData() {
    _dataProcessor.clearData();
    _latestSamples = [];
    _initializeChartData();
    notifyListeners();
  }

  /// Get summary statistics
  String getSummaryStats() {
    if (_latestSamples.isEmpty) return 'No data';
    
    final latest = _latestSamples.last;
    final sampleRate = latest.sampleRate;
    final channelCount = latest.channels.length;
    
    return 'Channels: $channelCount, Rate: ${sampleRate}Hz, Samples: ${_latestSamples.length}';
  }

  /// Check if data is actively being received
  bool get isReceivingData {
    if (_latestSamples.isEmpty) return false;
    
    final lastSample = _latestSamples.last;
    final timeSinceLastSample = DateTime.now().difference(lastSample.timestamp);
    
    return timeSinceLastSample.inSeconds < 5; // Consider active if data within 5 seconds
  }

  @override
  void dispose() {
    stopDataStream();
    _dataProcessor.dispose();
    super.dispose();
  }
} 