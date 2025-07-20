import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/eeg_data_provider.dart';
import '../widgets/eeg_chart.dart';
import '../widgets/connection_status.dart';

/// Main screen of the EEG Flutter app with single EEG chart
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _isFullscreen = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isFullscreen ? null : _buildAppBar(),
      body: Column(
        children: [
          if (!_isFullscreen) ...[
            // Connection Status Panel
            const ConnectionStatus(),
          ],
          
          // EEG Chart
          Expanded(
            child: _buildEEGChart(),
          ),
          
          // Bottom Controls (minimized in fullscreen)
          if (!_isFullscreen) _buildBottomControls(),
        ],
      ),
      floatingActionButton: _isFullscreen ? _buildFullscreenFAB() : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('EEG Monitor'),
      elevation: 2,
      actions: [
        // Live Data Indicator
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
                      color: _getDataStatusColor(eegProvider),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getDataStatusText(eegProvider),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            );
          },
        ),
        
        // Settings Menu
        PopupMenuButton<String>(
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'fullscreen',
              child: Row(
                children: [
                  Icon(Icons.fullscreen),
                  SizedBox(width: 8),
                  Text('Fullscreen'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings),
                  SizedBox(width: 8),
                  Text('Settings'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEEGChart() {
    return Consumer<EEGDataProvider>(
      builder: (context, eegProvider, child) {
        final hasEegData = eegProvider.isReceivingJsonData;
        
        return Card(
          margin: const EdgeInsets.all(8),
          child: Column(
            children: [
              // Chart Header
              _buildChartHeader('EEG Time Series', hasEegData),
              
              // EEG Chart
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: EEGChart(
                    showGridLines: true,
                    showAxes: true,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChartHeader(String title, bool hasData) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const Spacer(),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: hasData ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            hasData ? 'Active' : 'No Data',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildQuickActionButton(
            icon: Icons.refresh,
            label: 'Refresh',
            onPressed: () {
              context.read<EEGDataProvider>().clearData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullscreenFAB() {
    return FloatingActionButton(
      onPressed: () {
        setState(() {
          _isFullscreen = false;
        });
      },
      child: const Icon(Icons.fullscreen_exit),
    );
  }

  Color _getDataStatusColor(EEGDataProvider eegProvider) {
    return eegProvider.isReceivingJsonData ? Colors.green : Colors.red;
  }

  String _getDataStatusText(EEGDataProvider eegProvider) {
    return eegProvider.isReceivingJsonData ? 'Live' : 'No Data';
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'fullscreen':
        setState(() {
          _isFullscreen = !_isFullscreen;
        });
        break;
      case 'settings':
        _showSettingsDialog(context);
        break;
    }
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: const Text('Advanced settings coming soon...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}