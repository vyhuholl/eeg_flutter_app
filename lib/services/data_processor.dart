import 'dart:async';
import 'dart:math' as math;
import '../models/eeg_data.dart';
import 'package:fl_chart/fl_chart.dart';

/// Enhanced data processor for EEG samples with JSON support
class EEGDataProcessor {
  final EEGBuffer _buffer;
  final EEGJsonBuffer _jsonBuffer;
  final EEGConfig _config;
  
  late StreamController<List<EEGSample>> _processedDataController;
  late StreamController<List<EEGJsonSample>> _processedJsonDataController;
  Timer? _processingTimer;
  
  // Chart data for visualization
  final Map<int, List<FlSpot>> _chartData = {};
  final List<FlSpot> _eegTimeSeriesData = [];
  final int _maxChartPoints = 1000; // Maximum points to display
  
  EEGDataProcessor({required EEGConfig config}) 
    : _config = config,
      _buffer = EEGBuffer(config.bufferSize),
      _jsonBuffer = EEGJsonBuffer(config.bufferSize) {
    _processedDataController = StreamController<List<EEGSample>>.broadcast();
    _processedJsonDataController = StreamController<List<EEGJsonSample>>.broadcast();
    _initializeChartData();
  }

  /// Stream of processed EEG data (legacy format)
  Stream<List<EEGSample>> get processedDataStream => _processedDataController.stream;
  
  /// Stream of processed JSON EEG data
  Stream<List<EEGJsonSample>> get processedJsonDataStream => _processedJsonDataController.stream;
  
  /// Current EEG configuration
  EEGConfig get config => _config;

  /// Initialize chart data structures
  void _initializeChartData() {
    for (int i = 0; i < _config.channelCount; i++) {
      _chartData[i] = [];
    }
  }

  /// Process a single EEG sample
  void processSample(EEGSample sample) {
    _buffer.add(sample);
    _updateChartData(sample);
    _processedDataController.add(_buffer.getLatest(100));
  }

  /// Process a JSON EEG sample
  void processJsonSample(EEGJsonSample sample) {
    _jsonBuffer.add(sample);
    _updateEEGTimeSeriesData(sample);
    _processedJsonDataController.add(_jsonBuffer.getLatest(100));
  }

  /// Update chart data with new sample
  void _updateChartData(EEGSample sample) {
    final timestamp = sample.timestamp.millisecondsSinceEpoch.toDouble();
    
    for (int i = 0; i < sample.channels.length && i < _config.channelCount; i++) {
      final chartData = _chartData[i]!;
      chartData.add(FlSpot(timestamp, sample.channels[i]));
      
      // Maintain maximum points
      if (chartData.length > _maxChartPoints) {
        chartData.removeAt(0);
      }
    }
  }

  /// Update EEG time series data for JSON samples
  void _updateEEGTimeSeriesData(EEGJsonSample sample) {
    final timestamp = sample.absoluteTimestamp.millisecondsSinceEpoch.toDouble();
    _eegTimeSeriesData.add(FlSpot(timestamp, sample.eegValue));
    
    // Maintain maximum points
    if (_eegTimeSeriesData.length > _maxChartPoints) {
      _eegTimeSeriesData.removeAt(0);
    }
  }

  /// Get chart data for specific channel
  List<FlSpot> getChartData(int channel) {
    return _chartData[channel] ?? [];
  }

  /// Get EEG time series data
  List<FlSpot> get eegTimeSeriesData => List.from(_eegTimeSeriesData);

  /// Start periodic processing (if needed)
  void startProcessing() {
    // Implementation for any periodic processing if needed
  }

  /// Stop periodic processing
  void stopProcessing() {
    _processingTimer?.cancel();
    _processingTimer = null;
  }

  /// Apply noise filtering to samples
  List<EEGJsonSample> applyFiltering(List<EEGJsonSample> samples) {
    if (samples.isEmpty) return samples;
    
    final filtered = <EEGJsonSample>[];
    
    for (final sample in samples) {
      // Apply simple low-pass filter (basic noise reduction)
      final filteredEegValue = _applyLowPassFilter(sample.eegValue);
      
      filtered.add(EEGJsonSample(
        timeDelta: sample.timeDelta,
        eegValue: filteredEegValue,
        absoluteTimestamp: sample.absoluteTimestamp,
        sequenceNumber: sample.sequenceNumber,
      ));
    }
    
    return filtered;
  }

  /// Simple low-pass filter implementation
  double _applyLowPassFilter(double value) {
    // Simple moving average or other filter
    return value; // Placeholder - implement actual filtering if needed
  }

  /// Get latest processed samples
  List<EEGSample> getLatestSamples([int count = 100]) {
    return _buffer.getLatest(count);
  }

  /// Get latest JSON samples
  List<EEGJsonSample> getLatestJsonSamples([int count = 100]) {
    return _jsonBuffer.getLatest(count);
  }

  /// Clear all data
  void clearAll() {
    _buffer.clear();
    _jsonBuffer.clear();
    _chartData.forEach((key, value) => value.clear());
    _eegTimeSeriesData.clear();
  }

  /// Get data statistics
  Map<String, dynamic> getStatistics() {
    final legacySampleCount = _buffer.length;
    final jsonSampleCount = _jsonBuffer.length;
    
    return {
      'legacySamples': legacySampleCount,
      'jsonSamples': jsonSampleCount,
      'chartPoints': _eegTimeSeriesData.length,
      'bufferSize': _config.bufferSize,
    };
  }

  /// Get signal quality assessment
  SignalQuality assessSignalQuality(List<EEGJsonSample> samples) {
    if (samples.isEmpty) {
      return SignalQuality(
        quality: QualityLevel.poor,
        score: 0.0,
        metrics: {'reason': 'No data available'},
      );
    }

    // Basic signal quality assessment
    final values = samples.map((s) => s.eegValue).toList();
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
    final standardDeviation = math.sqrt(variance);
    
    // Simple quality scoring based on standard deviation
    double score;
    QualityLevel quality;
    
    if (standardDeviation < 10) {
      score = 0.9;
      quality = QualityLevel.excellent;
    } else if (standardDeviation < 50) {
      score = 0.7;
      quality = QualityLevel.good;
    } else if (standardDeviation < 100) {
      score = 0.5;
      quality = QualityLevel.fair;
    } else {
      score = 0.2;
      quality = QualityLevel.poor;
    }

    return SignalQuality(
      quality: quality,
      score: score,
      metrics: {
        'mean': mean,
        'standardDeviation': standardDeviation,
        'sampleCount': samples.length,
      },
    );
  }

  /// Dispose of resources
  void dispose() {
    stopProcessing();
    _processedDataController.close();
    _processedJsonDataController.close();
  }
}

/// Signal quality levels
enum QualityLevel {
  excellent,
  good,
  fair,
  poor,
}

/// Signal quality information
class SignalQuality {
  final QualityLevel quality;
  final double score;
  final Map<String, dynamic> metrics;

  const SignalQuality({
    required this.quality,
    required this.score,
    required this.metrics,
  });

  String get qualityText {
    switch (quality) {
      case QualityLevel.excellent:
        return 'Excellent';
      case QualityLevel.good:
        return 'Good';
      case QualityLevel.fair:
        return 'Fair';
      case QualityLevel.poor:
        return 'Poor';
    }
  }
  
  bool get hasArtifacts => false; // No artifacts in this simplified model
} 