import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../models/validation_models.dart';
import '../providers/electrode_validation_provider.dart';
import '../providers/eeg_data_provider.dart';
import '../widgets/eeg_chart.dart';

/// Screen for performing one-time electrode validation
class ElectrodeValidationScreen extends StatefulWidget {
  const ElectrodeValidationScreen({super.key});

  @override
  State<ElectrodeValidationScreen> createState() => _ElectrodeValidationScreenState();
}

class _ElectrodeValidationScreenState extends State<ElectrodeValidationScreen>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _shakeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer2<ElectrodeValidationProvider, EEGDataProvider>(
        builder: (context, validationProvider, eegProvider, child) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Status indicator at top
                  _buildStatusIndicator(validationProvider),
                  
                  const SizedBox(height: 40),
                  
                  // Main content area
                  Expanded(
                    child: _buildMainContent(validationProvider, eegProvider),
                  ),
                  
                  // Debug panel (only in debug mode)
                  if (kDebugMode) ...[
                    const Divider(color: Colors.grey),
                    _buildDebugPanel(validationProvider),
                  ],
                ],
              ),
            ),
          );
        },
      ),
      // Navigation back button
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).pop(),
        backgroundColor: Colors.grey[700],
        child: const Icon(Icons.arrow_back, color: Colors.white),
      ),
    );
  }

  /// Build the status indicator at the top of the screen
  Widget _buildStatusIndicator(ElectrodeValidationProvider provider) {
    final state = provider.currentState;
    
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: state.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            state.displayText,
            style: TextStyle(
              color: state.color,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Build the main content area based on validation state
  Widget _buildMainContent(ElectrodeValidationProvider validationProvider, EEGDataProvider eegProvider) {
    final state = validationProvider.currentState;
    
    // If validation passed, show EEG chart
    if (state == ValidationState.validationPassed) {
      return _buildSuccessContent(eegProvider);
    }
    
    // If validation failed, show error message
    if (state.isError) {
      return _buildErrorContent(validationProvider);
    }
    
    // Default: show validation button and status
    return _buildValidationContent(validationProvider);
  }

  /// Build the validation button and status content
  Widget _buildValidationContent(ElectrodeValidationProvider provider) {
    final canValidate = provider.canStartValidation;
    final isValidating = provider.isValidating;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Validation icon
        Icon(
          Icons.sensors,
          size: 96,
          color: canValidate ? Colors.blue : Colors.grey,
        ),
        
        const SizedBox(height: 40),
        
        // Validation button
        AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(
                isValidating ? 0 : _shakeAnimation.value * 10 * (provider.currentState.isError ? 1 : 0),
                0,
              ),
              child: ElevatedButton(
                onPressed: canValidate && !isValidating ? () => _startValidation(provider) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canValidate ? const Color(0xFF0A84FF) : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: isValidating
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Проверка...', style: TextStyle(fontSize: 16)),
                        ],
                      )
                    : const Text(
                        'Проверить электроды',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            );
          },
        ),
        
        const SizedBox(height: 20),
        
        // Status text
        if (!canValidate && provider.currentState == ValidationState.collectingData) ...[
          const Text(
            'Подождите, идёт сбор данных...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  /// Build success content with EEG chart
  Widget _buildSuccessContent(EEGDataProvider eegProvider) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Column(
            children: [
              // Success icon
              const Icon(
                Icons.check_circle,
                size: 96,
                color: Color(0xFF32D74B),
              ),
              
              const SizedBox(height: 20),
              
              const Text(
                'Электроды подключены правильно!',
                style: TextStyle(
                  color: Color(0xFF32D74B),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              // EEG Chart
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: EEGChart(
                    showGridLines: true,
                    showAxes: true,
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Continue button
              ElevatedButton(
                onPressed: () => _continueToMainScreen(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A84FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Продолжить',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build error content with troubleshooting message
  Widget _buildErrorContent(ElectrodeValidationProvider provider) {
    final result = provider.lastValidationResult;
    if (result == null) return const SizedBox.shrink();
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Error icon
        const Icon(
          Icons.error,
          size: 96,
          color: Color(0xFFFF3B30),
        ),
        
        const SizedBox(height: 40),
        
        // Error message
        Text(
          result.message,
          style: const TextStyle(
            color: Color(0xFFFF3B30),
            fontSize: 16,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 40),
        
        // Try again button
        ElevatedButton(
          onPressed: () => _startValidation(provider),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0A84FF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Попробовать снова',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Build debug information panel
  Widget _buildDebugPanel(ElectrodeValidationProvider provider) {
    final debugInfo = provider.getDebugInfo();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Debug Information',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // Debug info items
          ...debugInfo.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${entry.key}: ${entry.value}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Start the validation process
  void _startValidation(ElectrodeValidationProvider provider) {
    provider.startValidation().then((_) {
      // Trigger animations based on result
      if (provider.currentState == ValidationState.validationPassed) {
        _scaleController.forward();
      } else if (provider.currentState.isError) {
        _shakeController.forward().then((_) {
          _shakeController.reset();
        });
      }
    });
  }

  /// Continue to the main screen after successful validation
  void _continueToMainScreen() {
    Navigator.of(context).pop();
  }
} 