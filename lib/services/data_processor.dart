import 'dart:async';
import '../models/eeg_data.dart';
import 'package:fl_chart/fl_chart.dart';

/// Enhanced data processor for EEG samples with JSON support
class EEGDataProcessor {
  final EEGJsonBuffer _jsonBuffer;
  final EEGConfig _config;
  
  late StreamController<List<EEGJsonSample>> _processedJsonDataController;
  Timer? _processingTimer;
  Timer? _uiUpdateTimer;
  
  // Chart data for visualization
  final List<FlSpot> _eegTimeSeriesData = [];
  
  // UI update throttling
  bool _hasNewData = false;
  
  EEGDataProcessor({required EEGConfig config}) 
    : _config = config,
      _jsonBuffer = EEGJsonBuffer(config.bufferSize) {
    _processedJsonDataController = StreamController<List<EEGJsonSample>>.broadcast();
    _setupUIUpdateTimer();
  }
  
  /// Setup UI update timer to throttle data streaming to reasonable rate
  void _setupUIUpdateTimer() {
    // Update UI at 60 FPS maximum (every ~16ms) instead of 100 Hz data rate
    _uiUpdateTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (_hasNewData) {
        _processedJsonDataController.add(_jsonBuffer.getAll());
        _hasNewData = false;
      }
    });
  }
  
  /// Stream of processed JSON EEG data
  Stream<List<EEGJsonSample>> get processedJsonDataStream => _processedJsonDataController.stream;
  
  /// Current EEG configuration
  EEGConfig get config => _config;

  /// Process a JSON EEG sample
  void processJsonSample(EEGJsonSample sample) {
    _jsonBuffer.add(sample);
    _updateEEGTimeSeriesData(sample);
    _hasNewData = true; // Mark that new data is available for UI update
  }

  /// Update EEG time series data for JSON samples
  void _updateEEGTimeSeriesData(EEGJsonSample sample) {
    final timestamp = sample.absoluteTimestamp.millisecondsSinceEpoch.toDouble();
    _eegTimeSeriesData.add(FlSpot(timestamp, sample.eegValue.toDouble()));
    
    // Limit the size to prevent unbounded growth (keep same number as buffer)
    if (_eegTimeSeriesData.length > _config.bufferSize) {
      _eegTimeSeriesData.removeAt(0);
    }
  }

  /// Get EEG time series data (chart handles time window filtering)
  List<FlSpot> get eegTimeSeriesData {
    return _eegTimeSeriesData;
  }

  /// Start periodic processing (if needed)
  void startProcessing() {
    // Implementation for any periodic processing if needed
  }

  /// Stop periodic processing
  void stopProcessing() {
    _processingTimer?.cancel();
    _processingTimer = null;
    _uiUpdateTimer?.cancel();
    _uiUpdateTimer = null;
  }

  /// Get latest JSON samples (defaults to all available data up to 120 seconds worth)
  List<EEGJsonSample> getLatestJsonSamples([int? count]) {
    if (count != null) {
      return _jsonBuffer.getLatest(count);
    }
    
    // If count not specified, return all available data (limited by buffer size)
    // This ensures we get the maximum available data for the time window
    return _jsonBuffer.getAll();
  }

  /// Clear all data
  void clearAll() {
    _jsonBuffer.clear();
    _eegTimeSeriesData.clear();
  }

  /// Get data statistics
  Map<String, dynamic> getStatistics() {
    final jsonSampleCount = _jsonBuffer.length;
    
    return {
      'jsonSamples': jsonSampleCount,
      'chartPoints': _eegTimeSeriesData.length,
      'bufferSize': _config.bufferSize,
    };
  }

  /// Dispose of resources
  void dispose() {
    stopProcessing();
    _processedJsonDataController.close();
  }
}
