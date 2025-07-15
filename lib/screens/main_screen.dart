import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/eeg_data_provider.dart';
import '../providers/connection_provider.dart';
import '../widgets/eeg_chart.dart';
import '../widgets/power_spectrum_chart.dart';
import '../widgets/connection_status.dart';

/// Chart layout modes
enum ChartLayoutMode {
  eegOnly,
  spectrumOnly,
  dual,
  adaptive,
}

/// Main screen of the EEG Flutter app with dual chart layout
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  final ChartLayoutMode _layoutMode = ChartLayoutMode.adaptive; // Always auto
  double _chartRatio = 0.6; // EEG chart takes 60% of space by default
  bool _isFullscreen = false;
  
  late AnimationController _spectrumAnimationController;
  late Animation<double> _spectrumAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller for spectrum chart transitions
    _spectrumAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _spectrumAnimation = CurvedAnimation(
      parent: _spectrumAnimationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _spectrumAnimationController.dispose();
    super.dispose();
  }

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
          
          // Dual Chart Layout
          Expanded(
            child: _buildDualChartLayout(),
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
        
        // Spectrum Data Indicator
        Consumer<EEGDataProvider>(
          builder: (context, eegProvider, child) {
            return Container(
              margin: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bar_chart,
                    size: 16,
                    color: eegProvider.spectrumDataStatusColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    eegProvider.hasSpectrumData ? 'SPEC' : 'NO SPEC',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            );
          },
        ),
        
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

  Widget _buildDualChartLayout() {
    return Consumer2<EEGDataProvider, ConnectionProvider>(
      builder: (context, eegProvider, connectionProvider, child) {
        final hasEegData = eegProvider.isReceivingJsonData;
        final hasSpectrumData = eegProvider.hasSpectrumData && eegProvider.isSpectrumDataFresh;
        
        // Determine layout based on mode and data availability
        final shouldShowSpectrum = _shouldShowSpectrum(hasEegData, hasSpectrumData);
        
        if (shouldShowSpectrum && _layoutMode != ChartLayoutMode.eegOnly) {
          return _buildDualChartView(eegProvider, hasEegData, hasSpectrumData);
        } else {
          return _buildSingleChartView(eegProvider, hasEegData);
        }
      },
    );
  }

  Widget _buildSingleChartView(EEGDataProvider eegProvider, bool hasEegData) {
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
  }

  Widget _buildDualChartView(EEGDataProvider eegProvider, bool hasEegData, bool hasSpectrumData) {
    return Column(
      children: [
        // EEG Chart (Primary)
        Expanded(
          flex: (_chartRatio * 100).round(),
          child: Card(
            margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Column(
              children: [
                _buildChartHeader('EEG Time Series', hasEegData),
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
          ),
        ),
        
        // Draggable Divider
        _buildDraggableDivider(),
        
        // Spectrum Chart (Secondary)
        AnimatedBuilder(
          animation: _spectrumAnimation,
          builder: (context, child) {
            return SizeTransition(
              sizeFactor: _spectrumAnimation,
              child: Expanded(
                flex: ((1 - _chartRatio) * 100).round(),
                child: Card(
                  margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  child: Column(
                    children: [
                      _buildChartHeader('Power Spectrum', hasSpectrumData),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                                                     child: PowerSpectrumChart(
                             showGrid: true,
                             showAxisLabels: !_isFullscreen,
                             showInteractiveFeatures: true,
                           ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
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

  Widget _buildDraggableDivider() {
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          final RenderBox box = context.findRenderObject() as RenderBox;
          final localPosition = box.globalToLocal(details.globalPosition);
          final height = box.size.height - 200; // Account for other widgets
          
          double newRatio = localPosition.dy / height;
          newRatio = newRatio.clamp(0.3, 0.8); // Limit ratio between 30% and 80%
          
          _chartRatio = newRatio;
        });
      },
      child: Container(
        height: 20,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
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

  bool _shouldShowSpectrum(bool hasEegData, bool hasSpectrumData) {
    switch (_layoutMode) {
      case ChartLayoutMode.eegOnly:
        return false;
      case ChartLayoutMode.spectrumOnly:
        return hasSpectrumData;
      case ChartLayoutMode.dual:
        return true;
      case ChartLayoutMode.adaptive:
        return hasSpectrumData && hasEegData;
    }
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