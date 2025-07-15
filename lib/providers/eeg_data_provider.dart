import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/eeg_data.dart';
import '../services/data_processor.dart';

/// Chart visibility modes
enum ChartVisibility {
  eegOnly,
  spectrumOnly,
  both,
  adaptive,
}

/// Chart scaling modes
enum ChartScaling {
  auto,
  manual,
  adaptive,
}

/// Spectrum data status
enum SpectrumDataStatus {
  available,
  unavailable,
  partial,
  stale,
}

/// Chart display configuration
class ChartConfig {
  final ChartVisibility visibility;
  final ChartScaling scaling;
  final double timeWindow;
  final double amplitudeScale;
  final bool showGrid;
  final bool enableInteraction;
  final double refreshRate;

  const ChartConfig({
    this.visibility = ChartVisibility.adaptive,
    this.scaling = ChartScaling.auto,
    this.timeWindow = 10.0,
    this.amplitudeScale = 1.0,
    this.showGrid = true,
    this.enableInteraction = true,
    this.refreshRate = 30.0,
  });

  ChartConfig copyWith({
    ChartVisibility? visibility,
    ChartScaling? scaling,
    double? timeWindow,
    double? amplitudeScale,
    bool? showGrid,
    bool? showLegend,
    bool? enableInteraction,
    double? refreshRate,
  }) {
    return ChartConfig(
      visibility: visibility ?? this.visibility,
      scaling: scaling ?? this.scaling,
      timeWindow: timeWindow ?? this.timeWindow,
      amplitudeScale: amplitudeScale ?? this.amplitudeScale,
      showGrid: showGrid ?? this.showGrid,
      enableInteraction: enableInteraction ?? this.enableInteraction,
      refreshRate: refreshRate ?? this.refreshRate,
    );
  }
}

/// Provider for EEG data state management with enhanced controls
class EEGDataProvider extends ChangeNotifier {
  final EEGDataProcessor _dataProcessor;
  StreamSubscription<List<EEGSample>>? _dataSubscription;
  StreamSubscription<List<EEGJsonSample>>? _jsonDataSubscription;
  StreamSubscription<PowerSpectrumData>? _spectrumSubscription;
  
  List<EEGSample> _latestSamples = [];
  List<EEGJsonSample> _latestJsonSamples = [];
  PowerSpectrumData? _latestSpectrumData;
  
  final Map<int, List<FlSpot>> _chartData = {};
  final Map<int, SignalStats> _signalStats = {};
  final Map<int, SignalQuality> _signalQuality = {};
  
  // Display settings
  int _selectedChannel = 0;
  bool _showAllChannels = true;
  ChartConfig _chartConfig = const ChartConfig();
  
  // Spectrum data tracking
  DateTime? _lastSpectrumUpdate;
  SpectrumDataStatus _spectrumStatus = SpectrumDataStatus.unavailable;
  
  // Performance optimization
  Timer? _refreshTimer;
  bool _isRefreshing = false;
  int _updateCounter = 0;
  
  // Chart visibility controls
  bool _eegChartVisible = true;
  bool _spectrumChartVisible = true;
  bool _autoHideInactiveCharts = true;

  EEGDataProvider({required EEGConfig config}) 
    : _dataProcessor = EEGDataProcessor(config: config) {
    _initializeChartData();
    _setupRefreshTimer();
  }

  /// Latest EEG samples
  List<EEGSample> get latestSamples => _latestSamples;
  
  /// Latest JSON EEG samples
  List<EEGJsonSample> get latestJsonSamples => _latestJsonSamples;
  
  /// Latest spectrum data
  PowerSpectrumData? get latestSpectrumData => _latestSpectrumData;
  
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
  ChartConfig get chartConfig => _chartConfig;
  
  /// Spectrum data tracking
  DateTime? get lastSpectrumUpdate => _lastSpectrumUpdate;
  SpectrumDataStatus get spectrumStatus => _spectrumStatus;
  
  /// Chart visibility controls
  bool get eegChartVisible => _eegChartVisible;
  bool get spectrumChartVisible => _spectrumChartVisible;
  bool get autoHideInactiveCharts => _autoHideInactiveCharts;
  
  /// Performance metrics
  bool get isRefreshing => _isRefreshing;
  int get updateCounter => _updateCounter;
  
  /// Backward compatibility getters
  double get timeWindow => _chartConfig.timeWindow;
  double get amplitudeScale => _chartConfig.amplitudeScale;
  bool get filterEnabled => false; // Deprecated

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

  void _setupRefreshTimer() {
    _refreshTimer?.cancel();
    final refreshInterval = (1000 / _chartConfig.refreshRate).round();
    _refreshTimer = Timer.periodic(Duration(milliseconds: refreshInterval), (_) {
      _performPeriodicRefresh();
    });
  }

  void _performPeriodicRefresh() {
    if (_isRefreshing) return;
    
    _isRefreshing = true;
    _updateCounter++;
    
    // Update spectrum status
    _updateSpectrumStatus();
    
    // Update chart visibility based on adaptive mode
    if (_chartConfig.visibility == ChartVisibility.adaptive) {
      _updateAdaptiveVisibility();
    }
    
    _isRefreshing = false;
  }

  void _updateSpectrumStatus() {
    if (_latestSpectrumData == null) {
      _spectrumStatus = SpectrumDataStatus.unavailable;
      return;
    }
    
    if (_lastSpectrumUpdate == null) {
      _spectrumStatus = SpectrumDataStatus.partial;
      return;
    }
    
    final timeSinceLastUpdate = DateTime.now().difference(_lastSpectrumUpdate!);
    
    if (timeSinceLastUpdate.inSeconds > 30) {
      _spectrumStatus = SpectrumDataStatus.stale;
    } else if (timeSinceLastUpdate.inSeconds > 5) {
      _spectrumStatus = SpectrumDataStatus.partial;
    } else {
      _spectrumStatus = SpectrumDataStatus.available;
    }
  }

  void _updateAdaptiveVisibility() {
    if (!_autoHideInactiveCharts) return;
    
    final hasEegData = _latestJsonSamples.isNotEmpty;
    final hasSpectrumData = _spectrumStatus == SpectrumDataStatus.available;
    
    _eegChartVisible = hasEegData;
    _spectrumChartVisible = hasSpectrumData;
  }

  /// Start listening to data updates
  void startDataStream() {
    _dataSubscription = _dataProcessor.processedDataStream.listen(
      _onDataReceived,
      onError: _onDataError,
    );
    
    _jsonDataSubscription = _dataProcessor.processedJsonDataStream.listen(
      _onJsonDataReceived,
      onError: _onDataError,
    );
    
    _spectrumSubscription = _dataProcessor.spectrumDataStream.listen(
      _onSpectrumDataReceived,
      onError: _onDataError,
    );
    
    _dataProcessor.startProcessing();
  }

  /// Stop listening to data updates
  void stopDataStream() {
    _dataSubscription?.cancel();
    _dataSubscription = null;
    _jsonDataSubscription?.cancel();
    _jsonDataSubscription = null;
    _spectrumSubscription?.cancel();
    _spectrumSubscription = null;
    _dataProcessor.stopProcessing();
  }

  /// Process a new EEG sample
  void processSample(EEGSample sample) {
    _dataProcessor.processSample(sample);
  }

  /// Process a new JSON EEG sample
  void processJsonSample(EEGJsonSample sample) {
    _dataProcessor.processJsonSample(sample);
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

  void _onJsonDataReceived(List<EEGJsonSample> samples) {
    _latestJsonSamples = samples;
    notifyListeners();
  }

  void _onSpectrumDataReceived(PowerSpectrumData spectrumData) {
    _latestSpectrumData = spectrumData;
    _lastSpectrumUpdate = DateTime.now();
    _spectrumStatus = SpectrumDataStatus.available;
    notifyListeners();
  }

  void _onDataError(error) {
    debugPrint('EEG data error: $error');
  }

  void _updateChartData() {
    final allChartData = _dataProcessor.getAllChartData();
    
    // Apply time window filtering
    final now = DateTime.now().millisecondsSinceEpoch.toDouble();
    final timeWindowMs = _chartConfig.timeWindow * 1000;
    
    for (int channel = 0; channel < config.channelCount; channel++) {
      final channelData = allChartData[channel] ?? [];
      
      // Filter data by time window
      final filteredData = channelData
          .where((spot) => (now - spot.x) <= timeWindowMs)
          .toList();
      
      // Apply amplitude scaling
      final scaledData = filteredData.map((spot) => 
        FlSpot(spot.x, spot.y * _chartConfig.amplitudeScale)
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

  /// Get JSON line chart data for fl_chart
  List<LineChartBarData> getJsonLineChartData() {
    final eegData = _dataProcessor.getEegTimeSeriesData();
    
    if (eegData.isEmpty) return [];
    
    // Apply time window filtering
    final now = DateTime.now().millisecondsSinceEpoch.toDouble();
    final timeWindowMs = _chartConfig.timeWindow * 1000;
    
    final filteredData = eegData
        .where((spot) => (now - spot.x) <= timeWindowMs)
        .toList();
    
    // Apply amplitude scaling
    final scaledData = filteredData.map((spot) => 
      FlSpot(spot.x, spot.y * _chartConfig.amplitudeScale)
    ).toList();
    
    return [
      LineChartBarData(
        spots: scaledData,
        isCurved: false,
        color: const Color(0xFF2196F3), // Blue for EEG signal
        barWidth: 2.0,
        isStrokeCapRound: false,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ),
    ];
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

  /// Enhanced chart configuration methods
  void updateChartConfig(ChartConfig config) {
    _chartConfig = config;
    _setupRefreshTimer(); // Update refresh timer with new rate
    notifyListeners();
  }

  void setChartVisibility(ChartVisibility visibility) {
    _chartConfig = _chartConfig.copyWith(visibility: visibility);
    
    // Update individual chart visibility based on mode
    switch (visibility) {
      case ChartVisibility.eegOnly:
        _eegChartVisible = true;
        _spectrumChartVisible = false;
        break;
      case ChartVisibility.spectrumOnly:
        _eegChartVisible = false;
        _spectrumChartVisible = true;
        break;
      case ChartVisibility.both:
        _eegChartVisible = true;
        _spectrumChartVisible = true;
        break;
      case ChartVisibility.adaptive:
        _updateAdaptiveVisibility();
        break;
    }
    
    notifyListeners();
  }

  void setChartScaling(ChartScaling scaling) {
    _chartConfig = _chartConfig.copyWith(scaling: scaling);
    notifyListeners();
  }

  void setRefreshRate(double rate) {
    _chartConfig = _chartConfig.copyWith(refreshRate: rate);
    _setupRefreshTimer();
    notifyListeners();
  }

  /// Individual chart visibility controls
  void setEegChartVisible(bool visible) {
    _eegChartVisible = visible;
    notifyListeners();
  }

  void setSpectrumChartVisible(bool visible) {
    _spectrumChartVisible = visible;
    notifyListeners();
  }

  void setAutoHideInactiveCharts(bool autoHide) {
    _autoHideInactiveCharts = autoHide;
    notifyListeners();
  }

  /// Spectrum data indicator methods
  bool get hasSpectrumData => _latestSpectrumData != null;
  
  bool get isSpectrumDataFresh => _spectrumStatus == SpectrumDataStatus.available;
  
  bool get isSpectrumDataStale => _spectrumStatus == SpectrumDataStatus.stale;
  
  String get spectrumDataStatusMessage {
    switch (_spectrumStatus) {
      case SpectrumDataStatus.available:
        return 'Spectrum data available';
      case SpectrumDataStatus.partial:
        return 'Spectrum data partial';
      case SpectrumDataStatus.stale:
        return 'Spectrum data stale';
      case SpectrumDataStatus.unavailable:
        return 'No spectrum data';
    }
  }

  Color get spectrumDataStatusColor {
    switch (_spectrumStatus) {
      case SpectrumDataStatus.available:
        return Colors.green;
      case SpectrumDataStatus.partial:
        return Colors.orange;
      case SpectrumDataStatus.stale:
        return Colors.red;
      case SpectrumDataStatus.unavailable:
        return Colors.grey;
    }
  }

  /// Performance optimization methods
  void optimizePerformance() {
    // Reduce update frequency for inactive charts
    if (!_eegChartVisible && !_spectrumChartVisible) {
      setRefreshRate(1.0); // 1 FPS for hidden charts
    } else if (_eegChartVisible && _spectrumChartVisible) {
      setRefreshRate(30.0); // 30 FPS for both charts
    } else {
      setRefreshRate(60.0); // 60 FPS for single chart
    }
  }

  void resetPerformanceOptimization() {
    setRefreshRate(30.0); // Reset to default
  }

  /// Update display settings (backward compatibility)
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
      _chartConfig = _chartConfig.copyWith(timeWindow: seconds);
      notifyListeners();
    }
  }

  void setAmplitudeScale(double scale) {
    if (scale > 0) {
      _chartConfig = _chartConfig.copyWith(amplitudeScale: scale);
      notifyListeners();
    }
  }

  void setFilterEnabled(bool enabled) {
    // Deprecated - kept for backward compatibility
    notifyListeners();
  }

  /// Clear all data
  void clearData() {
    _dataProcessor.clearData();
    _latestSamples = [];
    _latestJsonSamples = [];
    _latestSpectrumData = null;
    _lastSpectrumUpdate = null;
    _spectrumStatus = SpectrumDataStatus.unavailable;
    _updateCounter = 0;
    _initializeChartData();
    notifyListeners();
  }

  /// Get JSON summary statistics
  String getJsonSummaryStats() {
    if (_latestJsonSamples.isEmpty) return 'No data';
    
    final sampleCount = _latestJsonSamples.length;
    final hasSpectrum = _latestSpectrumData != null;
    
    return 'EEG Samples: $sampleCount, Spectrum: ${hasSpectrum ? 'Available' : 'N/A'}';
  }

  /// Get JSON signal quality
  SignalQuality getJsonSignalQuality() {
    return _dataProcessor.getJsonSignalQuality();
  }

  /// Check if data is actively being received
  bool get isReceivingData {
    if (_latestSamples.isEmpty) return false;
    
    final lastSample = _latestSamples.last;
    final timeSinceLastSample = DateTime.now().difference(lastSample.timestamp);
    
    return timeSinceLastSample.inSeconds < 5; // Consider active if data within 5 seconds
  }

  /// Check if JSON data is actively being received
  bool get isReceivingJsonData {
    if (_latestJsonSamples.isEmpty) return false;
    
    final lastSample = _latestJsonSamples.last;
    final timeSinceLastSample = DateTime.now().difference(lastSample.absoluteTimestamp);
    
    return timeSinceLastSample.inSeconds < 5; // Consider active if data within 5 seconds
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    stopDataStream();
    _dataProcessor.dispose();
    super.dispose();
  }
} 