import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../models/validation_models.dart';
import '../providers/electrode_validation_provider.dart';
import '../providers/eeg_data_provider.dart';

import '../screens/meditation_selection_screen.dart';
import '../services/logger_service.dart';

/// Screen for validating electrode connection quality
class ElectrodeValidationScreen extends StatefulWidget {
  const ElectrodeValidationScreen({super.key});

  @override
  State<ElectrodeValidationScreen> createState() => _ElectrodeValidationScreenState();
}

class _ElectrodeValidationScreenState extends State<ElectrodeValidationScreen>
    with TickerProviderStateMixin {
  
  // Animation controllers
  late AnimationController _shakeController;
  late AnimationController _scaleController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    // Setup animations
    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    // Start validation when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startValidation();
    });
  }
  
  @override
  void dispose() {
    _shakeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }
  
  /// Start the validation process
  void _startValidation() {
    final eegProvider = Provider.of<EEGDataProvider>(context, listen: false);
    final validationProvider = Provider.of<ElectrodeValidationProvider>(context, listen: false);
    
    validationProvider.startValidation(eegProvider);
    LoggerService.info('ElectrodeValidationScreen: Validation started');
  }
  
  /// Handle continue button press
  void _onContinuePressed() {
    final validationProvider = Provider.of<ElectrodeValidationProvider>(context, listen: false);
    
    if (validationProvider.state.canProceed) {
      LoggerService.info('ElectrodeValidationScreen: Proceeding to meditation selection');
      
      // Navigate to meditation selection screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const MeditationSelectionScreen(),
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<ElectrodeValidationProvider>(
        builder: (context, validationProvider, child) {
          // Trigger animations based on state changes
          _handleStateAnimation(validationProvider.state);
          
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Status indicator
                  _buildStatusIndicator(validationProvider.state),
                  const SizedBox(height: 32),
                  
                  // Status message
                  _buildStatusMessage(validationProvider.state),
                  const SizedBox(height: 48),
                  
                  // Continue button
                  _buildContinueButton(validationProvider.state),
                  
                  // Debug information (only in debug mode)
                  if (kDebugMode) ...[
                    const SizedBox(height: 32),
                    _buildDebugInfo(validationProvider),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  /// Build status indicator with animations
  Widget _buildStatusIndicator(ElectrodeValidationState state) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _buildIconForState(state),
    );
  }
  
  /// Build appropriate icon for current state
  Widget _buildIconForState(ElectrodeValidationState state) {
    switch (state) {
      case ElectrodeValidationState.initializing:
      case ElectrodeValidationState.collectingData:
      case ElectrodeValidationState.validating:
        return const SizedBox(
          width: 96,
          height: 96,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0A84FF)),
            strokeWidth: 6.0,
          ),
        );
        
      case ElectrodeValidationState.valid:
        return ScaleTransition(
          scale: _scaleAnimation,
          child: const Icon(
            Icons.check_circle,
            size: 96,
            color: Color(0xFF34C759),
          ),
        );
        
      case ElectrodeValidationState.invalid:
      case ElectrodeValidationState.connectionLost:
        return AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            final offset = math.sin(_shakeAnimation.value * math.pi * 6) * 5;
            return Transform.translate(
              offset: Offset(offset, 0),
              child: const Icon(
                Icons.cancel,
                size: 96,
                color: Color(0xFFFF3B30),
              ),
            );
          },
        );
        
      case ElectrodeValidationState.insufficientData:
        return const Icon(
          Icons.warning,
          size: 96,
          color: Color(0xFFFF9500),
        );
    }
  }
  
  /// Build status message text
  Widget _buildStatusMessage(ElectrodeValidationState state) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Text(
        state.displayText,
        key: ValueKey(state),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
  
  /// Build continue button with conditional styling
  Widget _buildContinueButton(ElectrodeValidationState state) {
    final canProceed = state.canProceed;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: ElevatedButton(
        onPressed: canProceed ? _onContinuePressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canProceed 
              ? const Color(0xFF0A84FF) 
              : const Color(0xFF8E8E93),
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
    );
  }
  
  /// Build debug information panel
  Widget _buildDebugInfo(ElectrodeValidationProvider validationProvider) {
    final debugInfo = validationProvider.getDebugInfo();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF48484A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Debug Info:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...debugInfo.entries.map((entry) => Text(
            '${entry.key}: ${entry.value}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          )),
        ],
      ),
    );
  }
  
  /// Handle state-based animations
  void _handleStateAnimation(ElectrodeValidationState state) {
    switch (state) {
      case ElectrodeValidationState.valid:
        _scaleController.forward();
        break;
        
      case ElectrodeValidationState.invalid:
      case ElectrodeValidationState.connectionLost:
        _shakeController.forward().then((_) {
          _shakeController.reset();
        });
        break;
        
      default:
        // Reset animations for other states
        _scaleController.reset();
        _shakeController.reset();
        break;
    }
  }
} 