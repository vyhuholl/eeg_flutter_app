/// Connection state management for UDP communication
enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
  reconnecting,
}

/// Represents the current connection state
class ConnectionState {
  final ConnectionStatus status;
  final String? errorMessage;
  final DateTime? connectedAt;
  final DateTime? lastDataReceived;
  final int packetsReceived;
  final int packetsLost;
  final double dataRate; // packets per second

  const ConnectionState({
    required this.status,
    this.errorMessage,
    this.connectedAt,
    this.lastDataReceived,
    this.packetsReceived = 0,
    this.packetsLost = 0,
    this.dataRate = 0.0,
  });

  factory ConnectionState.disconnected() {
    return const ConnectionState(status: ConnectionStatus.disconnected);
  }

  factory ConnectionState.connecting() {
    return const ConnectionState(status: ConnectionStatus.connecting);
  }

  factory ConnectionState.connected() {
    return ConnectionState(
      status: ConnectionStatus.connected,
      connectedAt: DateTime.now(),
    );
  }

  factory ConnectionState.error(String message) {
    return ConnectionState(
      status: ConnectionStatus.error,
      errorMessage: message,
    );
  }

  factory ConnectionState.reconnecting() {
    return const ConnectionState(status: ConnectionStatus.reconnecting);
  }

  ConnectionState copyWith({
    ConnectionStatus? status,
    String? errorMessage,
    DateTime? connectedAt,
    DateTime? lastDataReceived,
    int? packetsReceived,
    int? packetsLost,
    double? dataRate,
  }) {
    return ConnectionState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      connectedAt: connectedAt ?? this.connectedAt,
      lastDataReceived: lastDataReceived ?? this.lastDataReceived,
      packetsReceived: packetsReceived ?? this.packetsReceived,
      packetsLost: packetsLost ?? this.packetsLost,
      dataRate: dataRate ?? this.dataRate,
    );
  }

  bool get isConnected => status == ConnectionStatus.connected;
  bool get isDisconnected => status == ConnectionStatus.disconnected;
  bool get isConnecting => status == ConnectionStatus.connecting;
  bool get hasError => status == ConnectionStatus.error;
  bool get isReconnecting => status == ConnectionStatus.reconnecting;

  Duration? get connectionDuration {
    if (connectedAt == null) return null;
    return DateTime.now().difference(connectedAt!);
  }

  Duration? get timeSinceLastData {
    if (lastDataReceived == null) return null;
    return DateTime.now().difference(lastDataReceived!);
  }

  String get statusMessage {
    switch (status) {
      case ConnectionStatus.disconnected:
        return 'Disconnected';
      case ConnectionStatus.connecting:
        return 'Connecting...';
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.error:
        return 'Error: ${errorMessage ?? 'Unknown error'}';
      case ConnectionStatus.reconnecting:
        return 'Reconnecting...';
    }
  }

  @override
  String toString() {
    return 'ConnectionState(status: $status, packets: $packetsReceived, rate: ${dataRate.toStringAsFixed(1)} pps)';
  }
}

/// Network statistics for monitoring connection quality
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
    if (total == 0) return 0.0;
    return totalPacketsLost / total;
  }

  double get packetLossPercentage => packetLossRate * 100;

  bool get hasSignificantLoss => packetLossPercentage > 1.0;

  String get summary {
    return 'Received: $totalPacketsReceived, Lost: $totalPacketsLost, Loss: ${packetLossPercentage.toStringAsFixed(1)}%';
  }
} 