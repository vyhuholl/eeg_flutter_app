import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../models/connection_state.dart' as connection_state;
import '../models/eeg_data.dart';

/// Widget to display connection status and controls
class ConnectionStatus extends StatelessWidget {
  final bool showControls;
  final bool showDetails;

  const ConnectionStatus({
    super.key,
    this.showControls = true,
    this.showDetails = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionProvider>(
      builder: (context, connectionProvider, child) {
        return Card(
          margin: const EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusHeader(context, connectionProvider),
                if (showDetails) ...[
                  const SizedBox(height: 12),
                  _buildStatusDetails(context, connectionProvider),
                ],
                if (showControls) ...[
                  const SizedBox(height: 16),
                  _buildControlButtons(context, connectionProvider),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusHeader(BuildContext context, ConnectionProvider connectionProvider) {
    final status = connectionProvider.currentState.status;
    final color = _getStatusColor(status);
    final icon = _getStatusIcon(status);

    return Row(
      children: [
        Icon(
          icon,
          color: color,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          connectionProvider.statusMessage,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        _buildStatusIndicator(color),
      ],
    );
  }

  Widget _buildStatusIndicator(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDetails(BuildContext context, ConnectionProvider connectionProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('Device', '${connectionProvider.config.deviceAddress}:${connectionProvider.config.devicePort}'),
        
        if (connectionProvider.isConnected) ...[
          _buildDetailRow('Connection Time', _formatDuration(connectionProvider.currentState.connectionDuration)),
          _buildDetailRow('Packets Received', connectionProvider.currentState.packetsReceived.toString()),
          _buildDetailRow('Data Rate', '${connectionProvider.currentState.dataRate.toStringAsFixed(1)} pps'),
          _buildDetailRow('Health', connectionProvider.healthStatusMessage),
        ],
        
        if (connectionProvider.hasError) ...[
          _buildDetailRow('Error', connectionProvider.currentState.errorMessage ?? 'Unknown error'),
        ],
        
        _buildNetworkStats(context, connectionProvider),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkStats(BuildContext context, ConnectionProvider connectionProvider) {
    final stats = connectionProvider.getDetailedStats();
    
    if (stats['totalPacketsReceived'] == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Network Statistics',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        _buildDetailRow('Total Packets', stats['totalPacketsReceived'].toString()),
        _buildDetailRow('Packets Lost', stats['totalPacketsLost'].toString()),
        _buildDetailRow('Packet Loss', '${stats['packetLossPercentage'].toStringAsFixed(2)}%'),
        _buildDetailRow('Avg Rate', '${stats['averageDataRate'].toStringAsFixed(1)} pps'),
        
        // Visual packet loss indicator
        if (stats['hasSignificantLoss'] == true) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.orange),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning,
                  color: Colors.orange,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  'Significant packet loss detected',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildControlButtons(BuildContext context, ConnectionProvider connectionProvider) {
    return Row(
      children: [
        if (!connectionProvider.isConnected) ...[
          ElevatedButton.icon(
            onPressed: connectionProvider.isConnecting ? null : () => connectionProvider.connect(),
            icon: connectionProvider.isConnecting 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.wifi, size: 16),
            label: Text(connectionProvider.isConnecting ? 'Connecting...' : 'Connect'),
          ),
        ] else ...[
          ElevatedButton.icon(
            onPressed: () => connectionProvider.disconnect(),
            icon: const Icon(Icons.wifi_off, size: 16),
            label: const Text('Disconnect'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
        
        const SizedBox(width: 8),
        
        OutlinedButton.icon(
          onPressed: () => connectionProvider.reconnect(),
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Reconnect'),
        ),
        
        const SizedBox(width: 8),
        
        OutlinedButton.icon(
          onPressed: () => _showConfigDialog(context, connectionProvider),
          icon: const Icon(Icons.settings, size: 16),
          label: const Text('Settings'),
        ),
      ],
    );
  }

  Color _getStatusColor(connection_state.ConnectionStatus status) {
    switch (status) {
      case connection_state.ConnectionStatus.connected:
        return Colors.green;
      case connection_state.ConnectionStatus.connecting:
      case connection_state.ConnectionStatus.reconnecting:
        return Colors.orange;
      case connection_state.ConnectionStatus.error:
        return Colors.red;
      case connection_state.ConnectionStatus.disconnected:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(connection_state.ConnectionStatus status) {
    switch (status) {
      case connection_state.ConnectionStatus.connected:
        return Icons.wifi;
      case connection_state.ConnectionStatus.connecting:
      case connection_state.ConnectionStatus.reconnecting:
        return Icons.wifi_find;
      case connection_state.ConnectionStatus.error:
        return Icons.wifi_off;
      case connection_state.ConnectionStatus.disconnected:
        return Icons.wifi_off;
    }
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return 'N/A';
    
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  void _showConfigDialog(BuildContext context, ConnectionProvider connectionProvider) {
    showDialog(
      context: context,
      builder: (context) => ConnectionConfigDialog(
        connectionProvider: connectionProvider,
      ),
    );
  }
}

/// Dialog for configuring connection settings
class ConnectionConfigDialog extends StatefulWidget {
  final ConnectionProvider connectionProvider;

  const ConnectionConfigDialog({
    super.key,
    required this.connectionProvider,
  });

  @override
  State<ConnectionConfigDialog> createState() => _ConnectionConfigDialogState();
}

class _ConnectionConfigDialogState extends State<ConnectionConfigDialog> {
  late TextEditingController _addressController;
  late TextEditingController _portController;
  late TextEditingController _sampleRateController;
  late TextEditingController _channelCountController;

  @override
  void initState() {
    super.initState();
    
    final config = widget.connectionProvider.config;
    _addressController = TextEditingController(text: config.deviceAddress);
    _portController = TextEditingController(text: config.devicePort.toString());
    _sampleRateController = TextEditingController(text: config.sampleRate.toString());
    _channelCountController = TextEditingController(text: config.channelCount.toString());
  }

  @override
  void dispose() {
    _addressController.dispose();
    _portController.dispose();
    _sampleRateController.dispose();
    _channelCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Connection Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Device Address',
                hintText: '192.168.1.100',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: 'Device Port',
                hintText: '12345',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _sampleRateController,
              decoration: const InputDecoration(
                labelText: 'Sample Rate (Hz)',
                hintText: '250',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _channelCountController,
              decoration: const InputDecoration(
                labelText: 'Channel Count',
                hintText: '8',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveConfig,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _saveConfig() {
    try {
      final address = _addressController.text.trim();
      final port = int.parse(_portController.text.trim());
      final sampleRate = int.parse(_sampleRateController.text.trim());
      final channelCount = int.parse(_channelCountController.text.trim());

      if (address.isEmpty || port <= 0 || sampleRate <= 0 || channelCount <= 0) {
        _showErrorDialog('Please enter valid values for all fields');
        return;
      }

      final config = widget.connectionProvider.config.copyWith(
        deviceAddress: address,
        devicePort: port,
        sampleRate: sampleRate,
        channelCount: channelCount,
      );

      widget.connectionProvider.updateConfig(config);
      Navigator.of(context).pop();
    } catch (e) {
      _showErrorDialog('Invalid input: ${e.toString()}');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// Extension to add copyWith method to EEGConfig
extension EEGConfigExtension on EEGConfig {
  EEGConfig copyWith({
    int? sampleRate,
    int? channelCount,
    List<String>? channelNames,
    String? deviceAddress,
    int? devicePort,
    int? bufferSize,
  }) {
    return EEGConfig(
      sampleRate: sampleRate ?? this.sampleRate,
      channelCount: channelCount ?? this.channelCount,
      channelNames: channelNames ?? this.channelNames,
      deviceAddress: deviceAddress ?? this.deviceAddress,
      devicePort: devicePort ?? this.devicePort,
      bufferSize: bufferSize ?? this.bufferSize,
    );
  }
} 