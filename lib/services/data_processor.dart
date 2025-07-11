import 'dart:async';
import 'dart:math' as math;
import '../models/eeg_data.dart';
import 'package:fl_chart/fl_chart.dart';

/// Data processor for EEG samples
class EEGDataProcessor {
  final EEGBuffer _buffer;
  final EEGConfig _config;
  
  late StreamController<List<EEGSample>> _processedDataController;
  Timer? _processingTimer;
  
  // Chart data for visualization
  final Map<int, List<FlSpot>> _chartData = {};
  final int _maxChartPoints = 1000; // Maximum points to display
  
  EEGDataProcessor({required EEGConfig config}) 
    : _config = config,
      _buffer = EEGBuffer(config.bufferSize) {
    _processedDataController = StreamController<List<EEGSample>>.broadcast();
    _initializeChartData();
  }

  /// Stream of processed EEG data
  Stream<List<EEGSample>> get processedDataStream => _processedDataController.stream;
  
  /// Current EEG configuration
  EEGConfig get config => _config;
  
  /// Current buffer
  EEGBuffer get buffer => _buffer;

  void _initializeChartData() {
    for (int i = 0; i < _config.channelCount; i++) {
      _chartData[i] = [];
    }
  }

  /// Process a new EEG sample
  void processSample(EEGSample sample) {
    // Add to buffer
    _buffer.add(sample);
    
    // Update chart data
    _updateChartData(sample);
    
    // Emit processed data
    _processedDataController.add(_buffer.getLatest(100));
  }

  void _updateChartData(EEGSample sample) {
    final timestamp = sample.timestamp.millisecondsSinceEpoch.toDouble();
    
    // Update chart data for each channel
    for (int i = 0; i < sample.channels.length && i < _config.channelCount; i++) {
      final channelData = _chartData[i]!;
      
      // Add new data point
      channelData.add(FlSpot(timestamp, sample.channels[i]));
      
      // Remove old data points to maintain performance
      while (channelData.length > _maxChartPoints) {
        channelData.removeAt(0);
      }
    }
  }

  /// Get chart data for a specific channel
  List<FlSpot> getChartData(int channel) {
    if (channel >= _config.channelCount) return [];
    return _chartData[channel] ?? [];
  }

  /// Get chart data for all channels
  Map<int, List<FlSpot>> getAllChartData() {
    return Map.from(_chartData);
  }

  /// Get the latest samples for display
  List<EEGSample> getLatestSamples([int count = 100]) {
    return _buffer.getLatest(count);
  }

  /// Apply basic filtering to the data
  List<EEGSample> applyBasicFilter(List<EEGSample> samples) {
    if (samples.isEmpty) return samples;
    
    // Simple moving average filter
    const windowSize = 5;
    final filtered = <EEGSample>[];
    
    for (int i = 0; i < samples.length; i++) {
      final sample = samples[i];
      final filteredChannels = <double>[];
      
      for (int ch = 0; ch < sample.channels.length; ch++) {
        double sum = 0;
        int count = 0;
        
        // Calculate moving average
        for (int j = math.max(0, i - windowSize + 1); j <= i; j++) {
          if (j < samples.length && ch < samples[j].channels.length) {
            sum += samples[j].channels[ch];
            count++;
          }
        }
        
        filteredChannels.add(count > 0 ? sum / count : sample.channels[ch]);
      }
      
      filtered.add(EEGSample(
        timestamp: sample.timestamp,
        channels: filteredChannels,
        sampleRate: sample.sampleRate,
        sequenceNumber: sample.sequenceNumber,
      ));
    }
    
    return filtered;
  }

  /// Calculate signal statistics
  SignalStats calculateStats(int channel, [int sampleCount = 100]) {
    final samples = _buffer.getLatest(sampleCount);
    if (samples.isEmpty || channel >= _config.channelCount) {
      return SignalStats.empty();
    }
    
    final values = samples
        .where((s) => channel < s.channels.length)
        .map((s) => s.channels[channel])
        .toList();
    
    if (values.isEmpty) return SignalStats.empty();
    
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
    final standardDeviation = math.sqrt(variance);
    
    return SignalStats(
      mean: mean,
      standardDeviation: standardDeviation,
      minimum: values.reduce(math.min),
      maximum: values.reduce(math.max),
      sampleCount: values.length,
    );
  }

  /// Get signal quality indicators
  SignalQuality getSignalQuality(int channel) {
    final stats = calculateStats(channel);
    
    // Simple quality assessment based on standard deviation
    final quality = stats.standardDeviation < 50 ? SignalQualityLevel.good :
                   stats.standardDeviation < 100 ? SignalQualityLevel.fair :
                   SignalQualityLevel.poor;
    
    return SignalQuality(
      level: quality,
      snr: _calculateSNR(channel),
      artifacts: _detectArtifacts(channel),
    );
  }

  double _calculateSNR(int channel) {
    // Simplified SNR calculation
    final stats = calculateStats(channel);
    if (stats.standardDeviation == 0) return 0;
    return 20 * math.log(stats.mean.abs() / stats.standardDeviation) / math.ln10;
  }

  List<String> _detectArtifacts(int channel) {
    final artifacts = <String>[];
    final stats = calculateStats(channel);
    
    // Simple artifact detection
    if (stats.standardDeviation > 200) {
      artifacts.add('High noise');
    }
    if (stats.maximum > 1000 || stats.minimum < -1000) {
      artifacts.add('Signal clipping');
    }
    
    return artifacts;
  }

  /// Start real-time processing
  void startProcessing() {
    _processingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      // Periodic processing tasks can be added here
      // For now, just emit the latest data
      if (!_buffer.isEmpty) {
        _processedDataController.add(_buffer.getLatest(100));
      }
    });
  }

  /// Stop real-time processing
  void stopProcessing() {
    _processingTimer?.cancel();
    _processingTimer = null;
  }

  /// Clear all data
  void clearData() {
    _buffer.clear();
    _initializeChartData();
  }

  /// Dispose of resources
  Future<void> dispose() async {
    stopProcessing();
    await _processedDataController.close();
  }
}

/// Signal statistics
class SignalStats {
  final double mean;
  final double standardDeviation;
  final double minimum;
  final double maximum;
  final int sampleCount;

  const SignalStats({
    required this.mean,
    required this.standardDeviation,
    required this.minimum,
    required this.maximum,
    required this.sampleCount,
  });

  factory SignalStats.empty() {
    return const SignalStats(
      mean: 0,
      standardDeviation: 0,
      minimum: 0,
      maximum: 0,
      sampleCount: 0,
    );
  }

  double get range => maximum - minimum;
  double get rms => math.sqrt(mean * mean + standardDeviation * standardDeviation);
}

/// Signal quality levels
enum SignalQualityLevel {
  good,
  fair,
  poor,
}

/// Signal quality information
class SignalQuality {
  final SignalQualityLevel level;
  final double snr;
  final List<String> artifacts;

  const SignalQuality({
    required this.level,
    required this.snr,
    required this.artifacts,
  });

  String get qualityText {
    switch (level) {
      case SignalQualityLevel.good:
        return 'Good';
      case SignalQualityLevel.fair:
        return 'Fair';
      case SignalQualityLevel.poor:
        return 'Poor';
    }
  }

  bool get hasArtifacts => artifacts.isNotEmpty;
} 