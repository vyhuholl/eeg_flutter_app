import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/eeg_data.dart';
import 'package:fl_chart/fl_chart.dart';

/// Enhanced data processor for EEG samples with JSON and spectrum support
class EEGDataProcessor {
  final EEGBuffer _buffer;
  final EEGJsonBuffer _jsonBuffer;
  final EEGConfig _config;
  
  late StreamController<List<EEGSample>> _processedDataController;
  late StreamController<List<EEGJsonSample>> _processedJsonDataController;
  late StreamController<PowerSpectrumData> _spectrumDataController;
  Timer? _processingTimer;
  
  // Chart data for visualization
  final Map<int, List<FlSpot>> _chartData = {};
  final List<FlSpot> _eegTimeSeriesData = [];
  final Map<int, double> _latestSpectrumData = {};
  final int _maxChartPoints = 1000; // Maximum points to display
  
  // Spectrum data aggregation
  PowerSpectrumData? _lastSpectrumData;
  DateTime? _lastSpectrumUpdate;
  final Duration _spectrumUpdateInterval = const Duration(milliseconds: 500);
  
  EEGDataProcessor({required EEGConfig config}) 
    : _config = config,
      _buffer = EEGBuffer(config.bufferSize),
      _jsonBuffer = EEGJsonBuffer(config.bufferSize) {
    _processedDataController = StreamController<List<EEGSample>>.broadcast();
    _processedJsonDataController = StreamController<List<EEGJsonSample>>.broadcast();
    _spectrumDataController = StreamController<PowerSpectrumData>.broadcast();
    _initializeChartData();
  }

  /// Stream of processed EEG data (legacy format)
  Stream<List<EEGSample>> get processedDataStream => _processedDataController.stream;
  
  /// Stream of processed JSON EEG data
  Stream<List<EEGJsonSample>> get processedJsonDataStream => _processedJsonDataController.stream;
  
  /// Stream of power spectrum data
  Stream<PowerSpectrumData> get spectrumDataStream => _spectrumDataController.stream;
  
  /// Current EEG configuration
  EEGConfig get config => _config;
  
  /// Current legacy buffer
  EEGBuffer get buffer => _buffer;
  
  /// Current JSON buffer
  EEGJsonBuffer get jsonBuffer => _jsonBuffer;
  
  /// Latest spectrum data
  PowerSpectrumData? get latestSpectrumData => _lastSpectrumData;
  
  /// Check if spectrum data is available
  bool get hasSpectrumData => _lastSpectrumData != null;

  void _initializeChartData() {
    for (int i = 0; i < _config.channelCount; i++) {
      _chartData[i] = [];
    }
  }

  /// Process a new EEG sample (legacy format)
  void processSample(EEGSample sample) {
    // Add to buffer
    _buffer.add(sample);
    
    // Update chart data
    _updateChartData(sample);
    
    // Emit processed data
    _processedDataController.add(_buffer.getLatest(100));
  }

  /// Process a new JSON EEG sample
  void processJsonSample(EEGJsonSample sample) {
    // Add to JSON buffer
    _jsonBuffer.add(sample);
    
    // Update EEG time series data
    _updateEegTimeSeriesData(sample);
    
    // Update spectrum data if available
    if (sample.hasSpectrumData) {
      _updateSpectrumData(sample.spectrumData!);
    }
    
    // Emit processed data
    _processedJsonDataController.add(_jsonBuffer.getLatest(100));
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

  void _updateEegTimeSeriesData(EEGJsonSample sample) {
    final timestamp = sample.absoluteTimestamp.millisecondsSinceEpoch.toDouble();
    
    // Add new EEG data point
    _eegTimeSeriesData.add(FlSpot(timestamp, sample.eegValue));
    
    // Remove old data points to maintain performance
    while (_eegTimeSeriesData.length > _maxChartPoints) {
      _eegTimeSeriesData.removeAt(0);
    }
  }

  void _updateSpectrumData(PowerSpectrumData spectrumData) {
    // Update latest spectrum data
    _lastSpectrumData = spectrumData;
    _lastSpectrumUpdate = DateTime.now();
    
    // Update spectrum chart data
    for (final freq in spectrumData.frequencies) {
      final power = spectrumData.getPowerAt(freq);
      if (power != null) {
        _latestSpectrumData[freq] = power;
      }
    }
    
    // Emit spectrum data with rate limiting
    if (_shouldEmitSpectrumData()) {
      _spectrumDataController.add(spectrumData);
    }
  }

  bool _shouldEmitSpectrumData() {
    if (_lastSpectrumUpdate == null) return true;
    
    final timeSinceLastEmit = DateTime.now().difference(_lastSpectrumUpdate!);
    return timeSinceLastEmit >= _spectrumUpdateInterval;
  }

  /// Get chart data for a specific channel (legacy format)
  List<FlSpot> getChartData(int channel) {
    if (channel >= _config.channelCount) return [];
    return _chartData[channel] ?? [];
  }

  /// Get EEG time series data for JSON format
  List<FlSpot> getEegTimeSeriesData() {
    return List.from(_eegTimeSeriesData);
  }

  /// Get spectrum chart data for histogram
  List<BarChartGroupData> getSpectrumChartData() {
    if (_latestSpectrumData.isEmpty) return [];
    
    final barGroups = <BarChartGroupData>[];
    
    for (int freq = 1; freq <= 49; freq++) {
      final power = _latestSpectrumData[freq] ?? 0.0;
      
      barGroups.add(
        BarChartGroupData(
          x: freq,
          barRods: [
            BarChartRodData(
              toY: power,
              color: _getFrequencyColor(freq),
              width: 8,
              borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
            ),
          ],
        ),
      );
    }
    
    return barGroups;
  }

  /// Get frequency color based on clinical bands
  Color _getFrequencyColor(int frequency) {
    for (final band in FrequencyBand.values) {
      if (frequency >= band.minFreq && frequency <= band.maxFreq) {
        switch (band) {
          case FrequencyBand.delta:
            return const Color(0xFF1565C0); // Deep Blue
          case FrequencyBand.theta:
            return const Color(0xFF1976D2); // Blue
          case FrequencyBand.alpha:
            return const Color(0xFF388E3C); // Green
          case FrequencyBand.beta:
            return const Color(0xFFF57C00); // Orange
          case FrequencyBand.gamma:
            return const Color(0xFFD32F2F); // Red
        }
      }
    }
    return const Color(0xFF757575); // Default gray
  }

  /// Get chart data for all channels (legacy format)
  Map<int, List<FlSpot>> getAllChartData() {
    return Map.from(_chartData);
  }

  /// Get the latest samples for display (legacy format)
  List<EEGSample> getLatestSamples([int count = 100]) {
    return _buffer.getLatest(count);
  }

  /// Get the latest JSON samples for display
  List<EEGJsonSample> getLatestJsonSamples([int count = 100]) {
    return _jsonBuffer.getLatest(count);
  }

  /// Get samples with spectrum data
  List<EEGJsonSample> getSpectrumSamples([int count = 100]) {
    return _jsonBuffer.getSpectrumSamples(count);
  }

  /// Get spectrum data statistics
  Map<String, dynamic> getSpectrumStats() {
    if (_lastSpectrumData == null) {
      return {
        'hasData': false,
        'frequencyCount': 0,
        'totalPower': 0.0,
        'peakFrequency': null,
        'dominantBand': null,
      };
    }
    
    final spectrum = _lastSpectrumData!;
    final bandPowers = spectrum.powerByBands;
    
    // Find dominant frequency band
    String? dominantBand;
    double maxBandPower = 0.0;
    
    for (final entry in bandPowers.entries) {
      if (entry.value > maxBandPower) {
        maxBandPower = entry.value;
        dominantBand = entry.key.name;
      }
    }
    
    return {
      'hasData': true,
      'frequencyCount': spectrum.frequencyCount,
      'totalPower': spectrum.totalPower,
      'peakFrequency': spectrum.peakFrequency,
      'dominantBand': dominantBand,
      'bandPowers': bandPowers.map((k, v) => MapEntry(k.name, v)),
      'lastUpdate': _lastSpectrumUpdate?.millisecondsSinceEpoch,
    };
  }

  /// Apply basic filtering to the data (legacy format)
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

  /// Apply basic filtering to JSON samples
  List<EEGJsonSample> applyBasicFilterToJson(List<EEGJsonSample> samples) {
    if (samples.isEmpty) return samples;
    
    // Simple moving average filter for EEG values
    const windowSize = 5;
    final filtered = <EEGJsonSample>[];
    
    for (int i = 0; i < samples.length; i++) {
      final sample = samples[i];
      double sum = 0;
      int count = 0;
      
      // Calculate moving average for EEG value
      for (int j = math.max(0, i - windowSize + 1); j <= i; j++) {
        if (j < samples.length) {
          sum += samples[j].eegValue;
          count++;
        }
      }
      
      final filteredEegValue = count > 0 ? sum / count : sample.eegValue;
      
      filtered.add(EEGJsonSample(
        timeDelta: sample.timeDelta,
        eegValue: filteredEegValue,
        powerSpectrum: sample.powerSpectrum, // Keep spectrum data unchanged
        absoluteTimestamp: sample.absoluteTimestamp,
        sequenceNumber: sample.sequenceNumber,
      ));
    }
    
    return filtered;
  }

  /// Calculate signal statistics (legacy format)
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

  /// Calculate JSON EEG signal statistics
  SignalStats calculateJsonStats([int sampleCount = 100]) {
    final samples = _jsonBuffer.getLatest(sampleCount);
    if (samples.isEmpty) return SignalStats.empty();
    
    final values = samples.map((s) => s.eegValue).toList();
    
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

  /// Get signal quality indicators (legacy format)
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

  /// Get JSON signal quality indicators
  SignalQuality getJsonSignalQuality() {
    final stats = calculateJsonStats();
    
    // Simple quality assessment based on standard deviation
    final quality = stats.standardDeviation < 50 ? SignalQualityLevel.good :
                   stats.standardDeviation < 100 ? SignalQualityLevel.fair :
                   SignalQualityLevel.poor;
    
    return SignalQuality(
      level: quality,
      snr: _calculateJsonSNR(),
      artifacts: _detectJsonArtifacts(),
    );
  }

  double _calculateSNR(int channel) {
    // Simplified SNR calculation
    final stats = calculateStats(channel);
    if (stats.standardDeviation == 0) return 0;
    return 20 * math.log(stats.mean.abs() / stats.standardDeviation) / math.ln10;
  }

  double _calculateJsonSNR() {
    // Simplified SNR calculation for JSON data
    final stats = calculateJsonStats();
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

  List<String> _detectJsonArtifacts() {
    final artifacts = <String>[];
    final stats = calculateJsonStats();
    
    // Simple artifact detection for JSON data
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
      // Periodic processing tasks
      if (!_buffer.isEmpty) {
        _processedDataController.add(_buffer.getLatest(100));
      }
      
      if (!_jsonBuffer.isEmpty) {
        _processedJsonDataController.add(_jsonBuffer.getLatest(100));
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
    _jsonBuffer.clear();
    _eegTimeSeriesData.clear();
    _latestSpectrumData.clear();
    _lastSpectrumData = null;
    _lastSpectrumUpdate = null;
    _initializeChartData();
  }

  /// Dispose of resources
  Future<void> dispose() async {
    stopProcessing();
    await _processedDataController.close();
    await _processedJsonDataController.close();
    await _spectrumDataController.close();
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

/// Network statistics
class NetworkStats {
  final int totalPacketsReceived;
  final int totalPacketsLost;
  final double averageDataRate;
  final double currentDataRate;
  final DateTime startTime;
  final Duration connectionDuration;

  const NetworkStats({
    required this.totalPacketsReceived,
    required this.totalPacketsLost,
    required this.averageDataRate,
    required this.currentDataRate,
    required this.startTime,
    required this.connectionDuration,
  });

  double get packetLossRate {
    final total = totalPacketsReceived + totalPacketsLost;
    return total > 0 ? (totalPacketsLost / total) * 100 : 0.0;
  }
} 