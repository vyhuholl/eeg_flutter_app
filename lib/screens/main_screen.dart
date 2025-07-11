import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/eeg_data_provider.dart';
import '../widgets/eeg_chart.dart';
import '../widgets/connection_status.dart';
import '../services/data_processor.dart';

/// Main screen of the EEG Flutter app
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EEG Monitor'),
        elevation: 2,
        actions: [
          Consumer<EEGDataProvider>(
            builder: (context, eegProvider, child) {
              return Container(
                margin: const EdgeInsets.only(right: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: eegProvider.isReceivingData ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      eegProvider.isReceivingData ? 'Live' : 'No Data',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection Status Panel
          const ConnectionStatus(),
          
          // Control Panel
          _buildControlPanel(),
          
          // EEG Chart
          Expanded(
            child: Consumer<EEGDataProvider>(
              builder: (context, eegProvider, child) {
                return const EEGChart(
                  showLegend: true,
                  showGridLines: true,
                  showAxes: true,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Consumer<EEGDataProvider>(
      builder: (context, eegProvider, child) {
        return Card(
          margin: const EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Display Settings',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                
                // Channel selection
                Row(
                  children: [
                    const Text('Show Channels:'),
                    const SizedBox(width: 12),
                    Switch(
                      value: eegProvider.showAllChannels,
                      onChanged: (value) {
                        eegProvider.setShowAllChannels(value);
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(eegProvider.showAllChannels ? 'All' : 'Single'),
                  ],
                ),
                
                // Single channel selection (when not showing all)
                if (!eegProvider.showAllChannels) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Channel:'),
                      const SizedBox(width: 12),
                      DropdownButton<int>(
                        value: eegProvider.selectedChannel,
                        items: List.generate(
                          eegProvider.config.channelCount,
                          (index) => DropdownMenuItem(
                            value: index,
                            child: Text(eegProvider.config.channelNames[index]),
                          ),
                        ),
                        onChanged: (value) {
                          if (value != null) {
                            eegProvider.setSelectedChannel(value);
                          }
                        },
                      ),
                    ],
                  ),
                ],
                
                const SizedBox(height: 12),
                
                // Time window and amplitude controls
                Row(
                  children: [
                    // Time window
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Time Window: ${eegProvider.timeWindow.toStringAsFixed(1)}s'),
                          Slider(
                            value: eegProvider.timeWindow,
                            min: 1.0,
                            max: 30.0,
                            divisions: 29,
                            onChanged: (value) {
                              eegProvider.setTimeWindow(value);
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 24),
                    
                    // Amplitude scale
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Amplitude: ${eegProvider.amplitudeScale.toStringAsFixed(1)}x'),
                          Slider(
                            value: eegProvider.amplitudeScale,
                            min: 0.1,
                            max: 5.0,
                            divisions: 49,
                            onChanged: (value) {
                              eegProvider.setAmplitudeScale(value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Action buttons
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        eegProvider.clearData();
                      },
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('Clear Data'),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    OutlinedButton.icon(
                      onPressed: () {
                        _showSignalQualityDialog(context, eegProvider);
                      },
                      icon: const Icon(Icons.assessment, size: 16),
                      label: const Text('Signal Quality'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSignalQualityDialog(BuildContext context, EEGDataProvider eegProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Signal Quality'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              eegProvider.config.channelCount,
              (index) => _buildSignalQualityItem(eegProvider, index),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalQualityItem(EEGDataProvider eegProvider, int channel) {
    final quality = eegProvider.signalQuality[channel];
    final stats = eegProvider.signalStats[channel];
    
    if (quality == null || stats == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  eegProvider.config.channelNames[channel],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getQualityColor(quality.level).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    quality.qualityText,
                    style: TextStyle(
                      color: _getQualityColor(quality.level),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text('Mean: ${stats.mean.toStringAsFixed(1)}μV'),
                ),
                Expanded(
                  child: Text('Std: ${stats.standardDeviation.toStringAsFixed(1)}μV'),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text('Min: ${stats.minimum.toStringAsFixed(1)}μV'),
                ),
                Expanded(
                  child: Text('Max: ${stats.maximum.toStringAsFixed(1)}μV'),
                ),
              ],
            ),
            if (quality.hasArtifacts) ...[
              const SizedBox(height: 4),
              Text(
                'Artifacts: ${quality.artifacts.join(', ')}',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getQualityColor(SignalQualityLevel level) {
    switch (level) {
      case SignalQualityLevel.good:
        return Colors.green;
      case SignalQualityLevel.fair:
        return Colors.orange;
      case SignalQualityLevel.poor:
        return Colors.red;
    }
  }
} 