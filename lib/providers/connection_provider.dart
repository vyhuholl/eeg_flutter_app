import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/connection_state.dart';
import '../models/eeg_data.dart';
import '../services/udp_receiver.dart';
import 'eeg_data_provider.dart';

/// Connection configuration for different data formats
class ConnectionConfig {
  final String deviceAddress;
  final int devicePort;
  final bool enableSpectrum;
  final double reconnectDelay;
  final int maxReconnectAttempts;

  const ConnectionConfig({
    this.deviceAddress = '0.0.0.0',
    this.devicePort = 2000,
    this.enableSpectrum = true,
    this.reconnectDelay = 5.0,
    this.maxReconnectAttempts = 5,
  });

  ConnectionConfig copyWith({
    String? deviceAddress,
    int? devicePort,
    bool? enableSpectrum,
    double? reconnectDelay,
    int? maxReconnectAttempts,
  }) {
    return ConnectionConfig(
      deviceAddress: deviceAddress ?? this.deviceAddress,
      devicePort: devicePort ?? this.devicePort,
      enableSpectrum: enableSpectrum ?? this.enableSpectrum,
      reconnectDelay: reconnectDelay ?? this.reconnectDelay,
      maxReconnectAttempts: maxReconnectAttempts ?? this.maxReconnectAttempts,
    );
  }
}

/// Provider for managing UDP connection state with JSON support
class ConnectionProvider extends ChangeNotifier {
  final UDPReceiver _udpReceiver;
  final EEGDataProvider _eegDataProvider;
  
  StreamSubscription<ConnectionState>? _connectionSubscription;
  StreamSubscription<EEGSample>? _dataSubscription;
  StreamSubscription<EEGJsonSample>? _jsonDataSubscription;
  
  ConnectionState _currentState = ConnectionState.disconnected();
  ConnectionConfig _connectionConfig = const ConnectionConfig();
  EEGConfig _eegConfig = EEGConfig.defaultConfig();
  
  // Connection attempt tracking
  int _reconnectAttempts = 0;
  
  bool _spectrumDataAvailable = false;
  DateTime? _lastSpectrumUpdate;
  
  // Performance tracking
  int _jsonPacketsReceived = 0;
  int _binaryPacketsReceived = 0;
  int _spectrumPacketsReceived = 0;
  
  ConnectionProvider({required EEGDataProvider eegDataProvider})
      : _eegDataProvider = eegDataProvider,
        _udpReceiver = UDPReceiver() {
    _initializeSubscriptions();
  }

  /// Current connection state
  ConnectionState get currentState => _currentState;
  
  /// Current connection configuration
  ConnectionConfig get connectionConfig => _connectionConfig;
  
  /// Current EEG configuration
  EEGConfig get eegConfig => _eegConfig;
  
  /// UDP receiver instance
  UDPReceiver get udpReceiver => _udpReceiver;
  
  /// Whether spectrum data is available
  bool get spectrumDataAvailable => _spectrumDataAvailable;
  
  /// Last spectrum data update time
  DateTime? get lastSpectrumUpdate => _lastSpectrumUpdate;
  
  /// Whether currently connected
  bool get isConnected => _currentState.isConnected;
  
  /// Whether currently connecting
  bool get isConnecting => _currentState.isConnecting;
  
  /// Whether in error state
  bool get hasError => _currentState.hasError;
  
  /// Current connection status message
  String get statusMessage => _currentState.statusMessage;
  
  /// Network statistics
  NetworkStats get networkStats => _udpReceiver.networkStats;

  /// JSON packet count
  int get jsonPacketsReceived => _jsonPacketsReceived;
  
  /// Binary packet count
  int get binaryPacketsReceived => _binaryPacketsReceived;
  
  /// Spectrum packet count
  int get spectrumPacketsReceived => _spectrumPacketsReceived;

  void _initializeSubscriptions() {
    // Listen to connection state changes
    _connectionSubscription = _udpReceiver.connectionStream.listen(
      _onConnectionStateChanged,
      onError: _onConnectionError,
    );
    
    // Listen to EEG data
    _dataSubscription = _udpReceiver.dataStream.listen(
      _onEEGDataReceived,
      onError: _onDataError,
    );
    
    // Listen to JSON EEG data
    _jsonDataSubscription = _udpReceiver.jsonDataStream.listen(
      _onJsonEEGDataReceived,
      onError: _onDataError,
    );
  }

  /// Connect to EEG device with specified configuration
  Future<void> connect({
    String? address,
    int? port,
    EEGConfig? eegConfig,
    ConnectionConfig? connectionConfig,
  }) async {
    if (_currentState.isConnecting || _currentState.isConnected) {
      return; // Already connecting or connected
    }

    try {
      // Update configurations if provided
      if (eegConfig != null) {
        _eegConfig = eegConfig;
      }
      if (connectionConfig != null) {
        _connectionConfig = connectionConfig;
      } else {
        _connectionConfig = _connectionConfig.copyWith(
          deviceAddress: address,
          devicePort: port,
        );
      }

      final deviceAddress = _connectionConfig.deviceAddress;
      final devicePort = _connectionConfig.devicePort;

      debugPrint('Connecting to EEG device at $deviceAddress:$devicePort');
      
      // Start EEG data stream
      _eegDataProvider.startDataStream();
      
      // Start UDP receiver
      await _udpReceiver.start(deviceAddress, devicePort);
      
      _reconnectAttempts = 0;
      
    } catch (error) {
      debugPrint('Connection error: $error');
      _updateConnectionState(ConnectionState.error(error.toString()));
    }
  }

  /// Disconnect from EEG device
  Future<void> disconnect() async {
    debugPrint('Disconnecting from EEG device');
    
    // Stop EEG data stream
    _eegDataProvider.stopDataStream();
    
    // Stop UDP receiver
    await _udpReceiver.stop();
    
    // Reset tracking variables
    _reconnectAttempts = 0;
    _spectrumDataAvailable = false;
    _lastSpectrumUpdate = null;
    _jsonPacketsReceived = 0;
    _binaryPacketsReceived = 0;
    _spectrumPacketsReceived = 0;
  }

  /// Reconnect to EEG device
  Future<void> reconnect() async {
    if (_reconnectAttempts >= _connectionConfig.maxReconnectAttempts) {
      _updateConnectionState(ConnectionState.error('Maximum reconnection attempts reached'));
      return;
    }

    _reconnectAttempts++;
    debugPrint('Reconnection attempt $_reconnectAttempts/${_connectionConfig.maxReconnectAttempts}');
    
    await disconnect();
    await Future.delayed(Duration(seconds: _connectionConfig.reconnectDelay.toInt()));
    await connect();
  }

  /// Update connection configuration
  void updateConnectionConfig(ConnectionConfig config) {
    _connectionConfig = config;
    notifyListeners();
  }

  /// Update EEG configuration
  void updateEEGConfig(EEGConfig config) {
    _eegConfig = config;
    notifyListeners();
  }

  /// Enable or disable spectrum data collection
  void setSpectrumEnabled(bool enabled) {
    _connectionConfig = _connectionConfig.copyWith(enableSpectrum: enabled);
    notifyListeners();
  }

  /// Test connection with ping
  Future<bool> testConnection() async {
    try {
      // This is a simplified test - in a real implementation,
      // you might send a test packet or check network connectivity
      return _currentState.isConnected;
    } catch (error) {
      debugPrint('Connection test failed: $error');
      return false;
    }
  }

  void _onConnectionStateChanged(ConnectionState state) {
    _updateConnectionState(state);
    
    // Handle automatic reconnection
    if (state.hasError && _reconnectAttempts < _connectionConfig.maxReconnectAttempts) {
      Timer(Duration(seconds: _connectionConfig.reconnectDelay.toInt()), () {
        if (!_currentState.isConnected) {
          reconnect();
        }
      });
    }
  }

  void _onConnectionError(error) {
    debugPrint('Connection stream error: $error');
    _updateConnectionState(ConnectionState.error(error.toString()));
  }

  void _onEEGDataReceived(EEGSample sample) {
    _binaryPacketsReceived++;
    
    // Forward EEG data to the data provider
    _eegDataProvider.processSample(sample);
  }

  void _onJsonEEGDataReceived(EEGJsonSample sample) {
    _jsonPacketsReceived++;
    
    // Forward JSON EEG data to the data provider
    _eegDataProvider.processJsonSample(sample);
    
    // Check if spectrum data is available
    if (sample.hasSpectrumData) {
      _spectrumPacketsReceived++;
      _spectrumDataAvailable = true;
      _lastSpectrumUpdate = DateTime.now();
    }
  }

  void _onDataError(error) {
    debugPrint('EEG data error: $error');
  }

  void _updateConnectionState(ConnectionState state) {
    _currentState = state;
    notifyListeners();
  }

  /// Get connection summary for UI display
  String getConnectionSummary() {
    final buffer = StringBuffer();
    
    buffer.writeln('Status: ${_currentState.statusMessage}');
    buffer.writeln('Device: ${_connectionConfig.deviceAddress}:${_connectionConfig.devicePort}');
    
    if (_currentState.isConnected) {
      buffer.writeln('Connected: ${_currentState.connectionDuration?.inSeconds}s');
      buffer.writeln('Packets: ${_currentState.packetsReceived}');
      buffer.writeln('Rate: ${_currentState.dataRate.toStringAsFixed(1)} pps');
      
      buffer.writeln('JSON: $_jsonPacketsReceived');
      buffer.writeln('Spectrum: ${_spectrumDataAvailable ? 'Available' : 'N/A'}');
    }
    
    if (_currentState.hasError) {
      buffer.writeln('Error: ${_currentState.errorMessage}');
    }
    
    return buffer.toString();
  }

  /// Get detailed network statistics
  Map<String, dynamic> getDetailedStats() {
    final stats = networkStats;
    return {
      'totalPacketsReceived': stats.totalPacketsReceived,
      'totalPacketsLost': stats.totalPacketsLost,
      'packetLossPercentage': stats.packetLossPercentage,
      'averageDataRate': stats.averageDataRate,
      'currentDataRate': stats.currentDataRate,
      'connectionDuration': stats.connectionDuration.inSeconds,
      'hasSignificantLoss': stats.hasSignificantLoss,
      'jsonPacketsReceived': _jsonPacketsReceived,
      'binaryPacketsReceived': _binaryPacketsReceived,
      'spectrumPacketsReceived': _spectrumPacketsReceived,
      'spectrumDataAvailable': _spectrumDataAvailable,
      'lastSpectrumUpdate': _lastSpectrumUpdate?.toIso8601String(),
    };
  }

  /// Check if connection is healthy
  bool get isConnectionHealthy {
    if (!_currentState.isConnected) return false;
    
    final stats = networkStats;
    final timeSinceLastData = _currentState.timeSinceLastData;
    
    // Connection is healthy if:
    // - Currently connected
    // - Low packet loss (< 5%)
    // - Recent data (< 5 seconds)
    return stats.packetLossPercentage < 5.0 &&
           (timeSinceLastData?.inSeconds ?? 0) < 5;
  }

  /// Check if spectrum data is being actively received
  bool get isSpectrumDataHealthy {
    if (!_spectrumDataAvailable || _lastSpectrumUpdate == null) return false;
    
    final timeSinceLastSpectrum = DateTime.now().difference(_lastSpectrumUpdate!);
    return timeSinceLastSpectrum.inSeconds < 10; // Spectrum data within 10 seconds
  }

  /// Get health status message
  String get healthStatusMessage {
    if (!_currentState.isConnected) return 'Disconnected';
    if (!isConnectionHealthy) return 'Poor connection quality';
    if (_connectionConfig.enableSpectrum && !isSpectrumDataHealthy) {
      return 'EEG data healthy, spectrum data missing';
    }
    return 'Connection healthy';
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _dataSubscription?.cancel();
    _jsonDataSubscription?.cancel();
    _udpReceiver.dispose();
    super.dispose();
  }
} 