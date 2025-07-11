import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/connection_state.dart';
import '../models/eeg_data.dart';
import '../services/udp_receiver.dart';
import 'eeg_data_provider.dart';

/// Provider for managing UDP connection state
class ConnectionProvider extends ChangeNotifier {
  final UDPReceiver _udpReceiver;
  final EEGDataProvider _eegDataProvider;
  
  StreamSubscription<ConnectionState>? _connectionSubscription;
  StreamSubscription<EEGSample>? _dataSubscription;
  
  ConnectionState _currentState = ConnectionState.disconnected();
  EEGConfig _config = EEGConfig.defaultConfig();
  
  // Connection attempt tracking
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  
  ConnectionProvider({required EEGDataProvider eegDataProvider})
      : _eegDataProvider = eegDataProvider,
        _udpReceiver = UDPReceiver() {
    _initializeSubscriptions();
  }

  /// Current connection state
  ConnectionState get currentState => _currentState;
  
  /// Current EEG configuration
  EEGConfig get config => _config;
  
  /// UDP receiver instance
  UDPReceiver get udpReceiver => _udpReceiver;
  
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
  }

  /// Connect to EEG device
  Future<void> connect({
    String? address,
    int? port,
    EEGConfig? config,
  }) async {
    if (_currentState.isConnecting || _currentState.isConnected) {
      return; // Already connecting or connected
    }

    try {
      // Update configuration if provided
      if (config != null) {
        _config = config;
      }

      final deviceAddress = address ?? _config.deviceAddress;
      final devicePort = port ?? _config.devicePort;

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
    
    _reconnectAttempts = 0;
  }

  /// Reconnect to EEG device
  Future<void> reconnect() async {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _updateConnectionState(ConnectionState.error('Maximum reconnection attempts reached'));
      return;
    }

    _reconnectAttempts++;
    debugPrint('Reconnection attempt $_reconnectAttempts/$_maxReconnectAttempts');
    
    await disconnect();
    await Future.delayed(const Duration(seconds: 2));
    await connect();
  }

  /// Update EEG configuration
  void updateConfig(EEGConfig config) {
    _config = config;
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
    if (state.hasError && _reconnectAttempts < _maxReconnectAttempts) {
      Timer(const Duration(seconds: 5), () {
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
    // Forward EEG data to the data provider
    _eegDataProvider.processSample(sample);
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
    buffer.writeln('Device: ${_config.deviceAddress}:${_config.devicePort}');
    
    if (_currentState.isConnected) {
      buffer.writeln('Connected: ${_currentState.connectionDuration?.inSeconds}s');
      buffer.writeln('Packets: ${_currentState.packetsReceived}');
      buffer.writeln('Rate: ${_currentState.dataRate.toStringAsFixed(1)} pps');
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

  /// Get health status message
  String get healthStatusMessage {
    if (!_currentState.isConnected) return 'Disconnected';
    if (!isConnectionHealthy) return 'Poor connection quality';
    return 'Connection healthy';
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _dataSubscription?.cancel();
    _udpReceiver.dispose();
    super.dispose();
  }
} 