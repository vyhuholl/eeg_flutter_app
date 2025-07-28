import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/eeg_data.dart';
import '../services/data_processor.dart';
import '../services/logger_service.dart';

/// Chart visibility options
enum ChartVisibility {
  eegOnly,
  dual,
  adaptive,
}

/// Chart display configuration
class ChartConfig {
  final double refreshRate;
  final bool showGrid;
  final bool enableInteraction;

  const ChartConfig({
    this.refreshRate = 100.0, // Match 100Hz data rate (10ms intervals)
    this.showGrid = true,
    this.enableInteraction = true,
  });

  ChartConfig copyWith({
    double? refreshRate,
    bool? showGrid,
    bool? enableInteraction,
  }) {
    return ChartConfig(
      refreshRate: refreshRate ?? this.refreshRate,
      showGrid: showGrid ?? this.showGrid,
      enableInteraction: enableInteraction ?? this.enableInteraction,
    );
  }
}

/// EEG data provider with Provider pattern
class EEGDataProvider with ChangeNotifier {
  final EEGDataProcessor _dataProcessor;
  
  // Data subscriptions
  StreamSubscription<List<EEGJsonSample>>? _jsonDataSubscription;
  
  List<EEGJsonSample> _latestJsonSamples = [];
  
  // Display settings
  ChartConfig _chartConfig = const ChartConfig();
  
  // Performance optimization
  Timer? _refreshTimer;
  bool _isRefreshing = false;
  int _updateCounter = 0;
  
  // Chart visibility controls
  bool _eegChartVisible = true;
  final bool _autoHideInactiveCharts = true;

  EEGDataProvider({required EEGConfig config}) 
    : _dataProcessor = EEGDataProcessor(config: config) {
    _setupRefreshTimer();
  }
  
  /// Latest JSON EEG samples
  List<EEGJsonSample> get latestJsonSamples => _latestJsonSamples;
  
  /// Current EEG configuration
  EEGConfig get config => _dataProcessor.config;
  
  /// Data processor instance
  EEGDataProcessor get dataProcessor => _dataProcessor;
  
  /// Display settings
  ChartConfig get chartConfig => _chartConfig;
  
  /// Chart visibility
  bool get eegChartVisible => _eegChartVisible;
  
  /// Data stream status
  bool get isReceivingJsonData => _latestJsonSamples.isNotEmpty;


  void _setupRefreshTimer() {
    _refreshTimer?.cancel();
    // Periodic maintenance timer for visibility updates only
    // Data updates are now throttled by the data processor at 60 FPS
    const maintenanceInterval = 1000; // 1 second for visibility updates
    _refreshTimer = Timer.periodic(const Duration(milliseconds: maintenanceInterval), (timer) {
      if (!_isRefreshing) {
        _refreshData();
      }
    });
  }

  void _refreshData() {
    _isRefreshing = true;
    // Update chart visibility based on data availability
    _updateAdaptiveVisibility();
    
    // Only notify listeners if there were visibility changes
    // Main data updates are handled directly in _onJsonSamplesReceived
    
    _isRefreshing = false;
  }

  void _updateAdaptiveVisibility() {
    if (!_autoHideInactiveCharts) return;
    
    final hasEegData = _latestJsonSamples.isNotEmpty;

    // Auto-hide charts based on data availability
    _eegChartVisible = hasEegData;
  }

  /// Start listening to data updates
  void startDataStream() {
    _jsonDataSubscription = _dataProcessor.processedJsonDataStream.listen(
      _onJsonSamplesReceived,
      onError: _onDataError,
    );
    
    _dataProcessor.startProcessing();
  }

  /// Stop listening to data updates
  void stopDataStream() {
    _jsonDataSubscription?.cancel();
    _jsonDataSubscription = null;
    _dataProcessor.stopProcessing();
  }

  /// Process a new JSON EEG sample
  void processJsonSample(EEGJsonSample sample) {
    _dataProcessor.processJsonSample(sample);
  }

  void _onJsonSamplesReceived(List<EEGJsonSample> samples) {
    _latestJsonSamples = samples;
    _updateCounter++;
    // Data processing is handled by the data processor, no need for duplicate processing
    notifyListeners(); // Update UI with throttled data (max 60 FPS)
  }

  void _onDataError(error) async  {
    await LoggerService.error('EEG data error: $error');
  }

  /// Get EEG time series data for charts
  List<FlSpot> getEEGTimeSeriesData() {
    return _dataProcessor.eegTimeSeriesData;
  }

  /// Get JSON line chart data for fl_chart
  List<LineChartBarData> getJsonLineChartData() {
    final eegData = _dataProcessor.eegTimeSeriesData;
    
    if (eegData.isEmpty) return [];
    
    return [
      LineChartBarData(
        spots: eegData,
        isCurved: false,
        color: const Color(0xFF2196F3), // Blue for EEG signal
        barWidth: 2.0,
        isStrokeCapRound: false,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ),
    ];
  }

  /// Update chart configuration
  void updateChartConfig(ChartConfig newConfig) {
    _chartConfig = newConfig;
    _setupRefreshTimer(); // Restart timer with new refresh rate
    notifyListeners();
  }

  /// Chart visibility controls
  void setChartVisibility(ChartVisibility visibility) {
    _eegChartVisible = true;
    notifyListeners();
  }

  void setEEGChartVisible(bool visible) {
    _eegChartVisible = visible;
    notifyListeners();
  }

  /// Performance metrics
  int get updateCount => _updateCounter;
  
  double get updateRate {
    // Simple calculation based on refresh timer
    return _chartConfig.refreshRate;
  }

  /// Data management
  void clearData() {
    _latestJsonSamples = [];
    _updateCounter = 0;
    
    _dataProcessor.clearAll();
    notifyListeners();
  }

  /// Get current data summary
  String getDataSummary() {
    final sampleCount = _latestJsonSamples.length;
    
    return 'EEG Samples: $sampleCount';
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    stopDataStream();
    _dataProcessor.dispose();
    super.dispose();
  }
}