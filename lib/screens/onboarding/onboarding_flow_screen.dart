import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme.dart';
import '../../api/pump_repository.dart';
import '../../models/pump_model.dart';
import '../../models/fuel_type_model.dart';
import '../../api/fuel_tank_repository.dart';
import '../../models/fuel_tank_model.dart';
import '../../api/fuel_dispenser_repository.dart';
import '../../models/fuel_dispenser_model.dart';
import '../../api/nozzle_repository.dart';
import '../../models/nozzle_model.dart';
import '../../api/pricing_repository.dart';
import '../../models/price_model.dart';
import '../home/home_screen.dart';
import '../../widgets/custom_snackbar.dart';

class OnboardingFlowScreen extends StatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  int _currentIndex = 0;
  bool _loading = true;
  static const String _kOnbCompletedKey = 'onboarding_completed';
  static const String _kOnbStepKey = 'onboarding_step';
  final int _totalSteps = 7;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
    _loadProgress();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool(_kOnbCompletedKey) ?? false;
    final step = prefs.getInt(_kOnbStepKey) ?? 0;

    if (completed) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }

    setState(() {
      _currentIndex = step.clamp(0, _totalSteps - 1);
      _loading = false;
    });

    _updateProgressAnimation();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentIndex);
      }
    });
  }

  void _updateProgressAnimation() {
    final progress = (_currentIndex + 1) / _totalSteps;
    _progressController.animateTo(progress);
  }

  Future<void> _saveProgress(int index, {bool completed = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kOnbStepKey, index);
    if (completed) {
      await prefs.setBool(_kOnbCompletedKey, true);
    }
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, _) => const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
          (route) => false,
    );
  }

  void _goNext() async {
    FocusScope.of(context).unfocus();
    if (_currentIndex < _totalSteps - 1) {
      final next = _currentIndex + 1;
      await _saveProgress(next);
      setState(() => _currentIndex = next);
      _updateProgressAnimation();

      await _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      await _saveProgress(_currentIndex, completed: true);
      _goHome();
    }
  }

  void _goBack() async {
    if (_currentIndex > 0) {
      final prev = _currentIndex - 1;
      await _saveProgress(prev);
      setState(() => _currentIndex = prev);
      _updateProgressAnimation();

      await _pageController.animateToPage(
        prev,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _confirmExit() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.pause_circle_outline, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            const Text('Finish Setup Later?'),
          ],
        ),
        content: const Text('You can complete the setup anytime from your dashboard. Your progress will be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue Setup'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Finish Later'),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
      await _saveProgress(_currentIndex);
      _goHome();
    }
  }

  Widget _buildTopBar() {
    final stepText = 'Step ${_currentIndex + 1} of $_totalSteps';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryOrange.withValues(alpha: 0.15),
                          AppTheme.primaryOrange.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.primaryOrange.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.local_gas_station,
                      color: AppTheme.primaryOrange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pump Setup',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),

                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      stepText,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: _confirmExit,
                    icon: const Icon(Icons.pause, size: 18),
                    label: const Text('Later'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _progressAnimation.value,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primaryBlue, AppTheme.primaryOrange],
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    final bool isLast = _currentIndex == _totalSteps - 1;
    final bool isFirst = _currentIndex == 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              if (!isFirst) ...[
                OutlinedButton.icon(
                  onPressed: _goBack,
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _goNext,
                  icon: Icon(
                    isLast ? Icons.check_circle : Icons.arrow_forward,
                    size: 20,
                  ),
                  label: Text(
                    isLast ? 'Complete Setup' : 'Continue',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    shadowColor: AppTheme.primaryBlue.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _pages() => [
    const _WelcomeStep(),
    FuelTypesStep(onCompleted: _goNext),
    TanksStep(onCompleted: _goNext),
    DispensersStep(onCompleted: _goNext),
    NozzlesStep(onCompleted: _goNext),
    FuelPricingStep(onCompleted: _goNext),
    const _FinishStep(),
  ];

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading setup...',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: _pages(),
                  ),
                ),
              ),
            ),
            _buildControls(),
          ],
        ),
      ),
    );
  }
}

// Enhanced Welcome Step
class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            'Welcome to Your Pump Setup! 👋',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Let\'s configure your pump step by step. This will only take a few minutes and you can always modify these settings later.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          const _InfoCard(
            icon: Icons.local_gas_station,
            title: 'Fuel Types',
            desc: 'Select the types of fuel you sell',
            color: Colors.blue,
          ),
          const SizedBox(height: 16),
          const _InfoCard(
            icon: Icons.storage,
            title: 'Fuel Tanks',
            desc: 'Set up tanks and map them to fuel types',
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          const _InfoCard(
            icon: Icons.ev_station,
            title: 'Dispensers',
            desc: 'Configure your dispensing units',
            color: Colors.orange,
          ),
          const SizedBox(height: 16),
          const _InfoCard(
            icon: Icons.api,
            title: 'Nozzles',
            desc: 'Link nozzles to dispensers and tanks',
            color: Colors.purple,
          ),
          const SizedBox(height: 16),
          const _InfoCard(
            icon: Icons.currency_rupee_rounded,
            title: 'Fuel Prices',
            desc: 'Set selling prices for each fuel type',
            color: Colors.green,
          ),
        ],
      ),
    );
  }
}

// Enhanced Info Card
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Enhanced Fuel Types Step
class FuelTypesStep extends StatefulWidget {
  final VoidCallback onCompleted;
  const FuelTypesStep({super.key, required this.onCompleted});

  @override
  State<FuelTypesStep> createState() => _FuelTypesStepState();
}

class _FuelTypesStepState extends State<FuelTypesStep> {
  final PumpRepository _pumpRepository = PumpRepository();
  bool _loading = true;
  String _error = '';
  List<FuelType> _available = [];
  Set<String> _selectedIds = {};
  PumpProfile? _profile;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final profileResp = await _pumpRepository.getPumpProfile();
      final typesResp = await _pumpRepository.getFuelTypes();
      if (!mounted) return;

      if (!profileResp.success || profileResp.data == null) {
        setState(() {
          _error = profileResp.errorMessage ?? 'Failed to load profile';
          _loading = false;
        });
        return;
      }

      _profile = profileResp.data;
      final existingCsv = _profile!.fuelTypesAvailable;
      if (existingCsv.isNotEmpty) {
        _selectedIds = existingCsv.split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet();
      }

      if (typesResp.success && typesResp.data != null) {
        _available = typesResp.data!;
      } else {
        _error = typesResp.errorMessage ?? 'Failed to load fuel types';
      }

      setState(() { _loading = false; });
    } catch (e) {
      setState(() { _error = 'Error: $e'; _loading = false; });
    }
  }

  Future<void> _save() async {
    if (_profile == null) return;
    if (_selectedIds.isEmpty) {
      showAnimatedSnackBar(
        context: context,
        message: 'Please select at least one fuel type',
        isError: true,
      );
      return;
    }

    setState(() { _saving = true; });
    try {
      final updated = PumpProfile(
        petrolPumpId: _profile!.petrolPumpId,
        name: _profile!.name,
        addressId: _profile!.addressId,
        licenseNumber: _profile!.licenseNumber,
        taxId: _profile!.taxId,
        openingTime: _profile!.openingTime,
        closingTime: _profile!.closingTime,
        isActive: _profile!.isActive,
        createdAt: _profile!.createdAt,
        updatedAt: DateTime.now(),
        companyName: _profile!.companyName,
        numberOfDispensers: _profile!.numberOfDispensers,
        fuelTypesAvailable: _selectedIds.join(','),
        contactNumber: _profile!.contactNumber,
        email: _profile!.email,
        website: _profile!.website,
        gstNumber: _profile!.gstNumber,
        licenseExpiryDate: _profile!.licenseExpiryDate,
        sapNo: _profile!.sapNo,
      );

      final resp = await _pumpRepository.updatePumpProfile(updated);
      if (!mounted) return;

      if (resp.success) {
        showAnimatedSnackBar(
          context: context,
          message: 'Fuel types saved successfully!',
          isError: false,
        );
        widget.onCompleted();
      } else {
        setState(() {
          _error = resp.errorMessage ?? 'Failed to save fuel types';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Error: $e'; });
    } finally {
      if (mounted) setState(() { _saving = false; });
    }
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error,
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading fuel types...'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Select Fuel Types',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose the types of fuel your station will offer. You can modify this selection anytime from your profile settings.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          if (_error.isNotEmpty) _buildErrorCard(),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _available.map((f) {
              final bool selected = _selectedIds.contains(f.fuelTypeId);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _selectedIds.remove(f.fuelTypeId);
                    } else {
                      _selectedIds.add(f.fuelTypeId);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? AppTheme.primaryBlue
                          : Colors.grey.shade200,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selected)
                        Icon(
                          Icons.check_circle,
                          color: AppTheme.primaryBlue,
                          size: 20,
                        ),
                      if (selected) const SizedBox(width: 8),
                      Text(
                        f.name,
                        style: TextStyle(
                          color: selected
                              ? AppTheme.primaryBlue
                              : Colors.grey.shade700,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.check),
              label: Text(_saving ? 'Saving...' : 'Save Selection'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Enhanced Tanks Step with improved UI
class TanksStep extends StatefulWidget {
  final VoidCallback onCompleted;
  const TanksStep({super.key, required this.onCompleted});

  @override
  State<TanksStep> createState() => _TanksStepState();
}

class _TanksStepState extends State<TanksStep> {
  final FuelTankRepository _tankRepo = FuelTankRepository();
  final PumpRepository _pumpRepo = PumpRepository();
  bool _loading = true;
  String _error = '';
  List<FuelType> _pumpFuelTypes = [];
  final List<_TankDraft> _drafts = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final profileResp = await _pumpRepo.getPumpProfile();
      if (!profileResp.success || profileResp.data == null || profileResp.data!.petrolPumpId == null) {
        setState(() {
          _error = profileResp.errorMessage ?? 'Failed to load profile';
          _loading = false;
        });
        return;
      }

      final pumpId = profileResp.data!.petrolPumpId!;
      final fuelTypesResp = await _pumpRepo.getPumpFuelTypes(pumpId);

      if (fuelTypesResp.success && fuelTypesResp.data != null) {
        _pumpFuelTypes = fuelTypesResp.data!;
      } else {
        _error = fuelTypesResp.errorMessage ?? 'Failed to load pump fuel types';
      }

      if (_pumpFuelTypes.isNotEmpty) {
        _drafts.add(_TankDraft(
          fuelTypeId: _pumpFuelTypes.first.fuelTypeId,
          fuelTypeName: _pumpFuelTypes.first.name,
        ));
      }

      setState(() { _loading = false; });
    } catch (e) {
      setState(() { _error = 'Error: $e'; _loading = false; });
    }
  }

  Future<void> _submitAll() async {
    if (_drafts.isEmpty) return;

    // Validate
    for (int i = 0; i < _drafts.length; i++) {
      final d = _drafts[i];
      if (d.capacity <= 0 || d.fuelTypeId == null) {
        showAnimatedSnackBar(
          context: context,
          message: 'Please fill all tank details correctly',
          isError: true,
        );
        return;
      }
      if (d.fuelTankName == null || d.fuelTankName!.trim().isEmpty) {
        showAnimatedSnackBar(
          context: context,
          message: 'Tank name is required for Tank ${i + 1}',
          isError: true,
        );
        return;
      }
      if (d.initialStock < 0) {
        showAnimatedSnackBar(
          context: context,
          message: 'Initial stock must be 0 or greater for Tank ${i + 1}',
          isError: true,
        );
        return;
      }
      if (d.initialStock > d.capacity) {
        showAnimatedSnackBar(
          context: context,
          message: 'Initial stock cannot exceed tank capacity for Tank ${i + 1}',
          isError: true,
        );
        return;
      }
    }

    setState(() { _saving = true; });
    try {
      final pumpId = await _tankRepo.getPetrolPumpId();
      if (pumpId == null) {
        setState(() {
          _error = 'Petrol pump ID not found';
          _saving = false;
        });
        return;
      }

      for (final d in _drafts) {
        final tank = FuelTank(
          petrolPumpId: pumpId,
          fuelType: d.fuelTypeName ?? 'Unknown',
          capacityInLiters: d.capacity,
          currentStock: d.initialStock.clamp(0, d.capacity),
          status: d.active ? 'Active' : 'Inactive',
          fuelTypeId: d.fuelTypeId,
          fuelTankName: (d.fuelTankName != null && d.fuelTankName!.isNotEmpty)
              ? d.fuelTankName
              : null,
        );

        final resp = await _tankRepo.addFuelTank(tank);
        if (!resp.success) {
          setState(() {
            _error = resp.errorMessage ?? 'Failed to add a fuel tank';
            _saving = false;
          });
          return;
        }
      }

      if (!mounted) return;
      showAnimatedSnackBar(
        context: context,
        message: 'Tanks added successfully!',
        isError: false,
      );
      widget.onCompleted();
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Error: $e'; });
    } finally {
      if (mounted) setState(() { _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading tank configuration...'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Configure Fuel Tanks',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Set up your storage tanks and link them to fuel types. Each tank will store and track inventory for specific fuel types.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          if (_error.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _error,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _drafts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final d = _drafts[index];
              return _EnhancedTankDraftCard(
                draft: d,
                fuelTypes: _pumpFuelTypes,
                tankNumber: index + 1,
                onRemove: _drafts.length == 1
                    ? null
                    : () {
                  setState(() {
                    _drafts.removeAt(index);
                  });
                },
                onChanged: () {
                  setState(() {});
                },
              );
            },
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      final ft = _pumpFuelTypes.isNotEmpty
                          ? _pumpFuelTypes.first
                          : null;
                      _drafts.add(_TankDraft(
                        fuelTypeId: ft?.fuelTypeId,
                        fuelTypeName: ft?.name,
                      ));
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Tank'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _submitAll,
              icon: _saving
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.save),
              label: Text(_saving ? 'Saving Tanks...' : 'Save & Continue'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TankDraft {
  String? fuelTypeId;
  String? fuelTypeName;
  String? fuelTankName;
  double capacity = 5000;
  double initialStock = 0;
  bool active = true;

  _TankDraft({this.fuelTypeId, this.fuelTypeName});
}

// Enhanced Tank Draft Card
class _EnhancedTankDraftCard extends StatelessWidget {
  final _TankDraft draft;
  final List<FuelType> fuelTypes;
  final int tankNumber;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  const _EnhancedTankDraftCard({
    required this.draft,
    required this.fuelTypes,
    required this.tankNumber,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Tank $tankNumber',
                  style: TextStyle(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                  tooltip: 'Remove tank',
                ),
            ],
          ),

          const SizedBox(height: 16),

          TextFormField(
            initialValue: draft.fuelTankName ?? '',
            decoration: InputDecoration(
              labelText: 'Tank Name',
              hintText: 'e.g., Main Petrol Tank',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
              ),
              prefixIcon: const Icon(Icons.label_outline),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            onChanged: (v) {
              draft.fuelTankName = v.trim();
              onChanged();
            },
          ),

          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: draft.fuelTypeId,
            decoration: InputDecoration(
              labelText: 'Fuel Type',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
              ),
              prefixIcon: const Icon(Icons.local_gas_station),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            items: fuelTypes.map((f) => DropdownMenuItem(
              value: f.fuelTypeId,
              child: Text(f.name),
            )).toList(),
            onChanged: (v) {
              draft.fuelTypeId = v;
              if (v != null) {
                draft.fuelTypeName = fuelTypes
                    .firstWhere((e) => e.fuelTypeId == v)
                    .name;
              }
              onChanged();
            },
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: draft.capacity.toStringAsFixed(0),
                  decoration: InputDecoration(
                    labelText: 'Capacity (Liters)',
                    hintText: '5000',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.straighten),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) {
                    draft.capacity = double.tryParse(v) ?? draft.capacity;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  initialValue: draft.initialStock.toStringAsFixed(0),
                  decoration: InputDecoration(
                    labelText: 'Initial Stock *',
                    hintText: 'Enter initial stock (0 or more)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.opacity),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) {
                    draft.initialStock = double.tryParse(v) ?? draft.initialStock;
                    onChanged();
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Switch(
                value: draft.active,
                onChanged: (v) {
                  draft.active = v;
                  onChanged();
                },
                activeColor: Colors.green,
              ),
              const SizedBox(width: 12),
              Text(
                draft.active ? 'Tank Active' : 'Tank Inactive',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: draft.active ? Colors.green : Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Similarly enhance the DispensersStep and NozzlesStep classes with improved UI...
// [Continue with enhanced versions of DispensersStep and NozzlesStep following the same pattern]

class DispensersStep extends StatefulWidget {
  final VoidCallback onCompleted;
  const DispensersStep({super.key, required this.onCompleted});

  @override
  State<DispensersStep> createState() => _DispensersStepState();
}

class _DispensersStepState extends State<DispensersStep> {
  final FuelDispenserRepository _repo = FuelDispenserRepository();
  final List<_DispenserDraft> _drafts = [
    _DispenserDraft(number: 1, nozzles: 2, status: 'Active')
  ];
  bool _saving = false;
  String _error = '';

  Future<void> _submitAll() async {
    setState(() { _saving = true; _error = ''; });
    try {
      final pumpId = await _repo.getPetrolPumpId();
      if (pumpId == null) {
        setState(() {
          _error = 'Petrol pump ID not found';
          _saving = false;
        });
        return;
      }

      for (int i = 0; i < _drafts.length; i++) {
        final d = _drafts[i];
        if (d.number <= 0 || d.nozzles < 1 || d.nozzles > 6) {
          if (mounted) {
            showAnimatedSnackBar(
              context: context,
              message: 'Please review dispenser fields (number>0, nozzles 1..6)',
              isError: true,
            );
          }
          setState(() {
            _saving = false;
          });
          return;
        }
        if (d.dispenserName == null || d.dispenserName!.trim().isEmpty) {
          if (mounted) {
            showAnimatedSnackBar(
              context: context,
              message: 'Dispenser name is required for Dispenser ${i + 1}',
              isError: true,
            );
          }
          setState(() {
            _saving = false;
          });
          return;
        }
      }

      for (final d in _drafts) {
        final disp = FuelDispenser(
          id: '',
          dispenserNumber: d.number,
          petrolPumpId: pumpId,
          status: d.status,
          numberOfNozzles: d.nozzles,
          fuelType: null,
          dispenserName: (d.dispenserName != null && d.dispenserName!.isNotEmpty)
              ? d.dispenserName
              : null,
        );

        final resp = await _repo.addFuelDispenser(disp);
        if (!resp.success) {
          setState(() {
            _error = resp.errorMessage ?? 'Failed to add a dispenser';
            _saving = false;
          });
          return;
        }
      }

      if (!mounted) return;
      showAnimatedSnackBar(
        context: context,
        message: 'Dispensers added successfully!',
        isError: false,
      );
      widget.onCompleted();
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Error: $e'; });
    } finally {
      if (mounted) setState(() { _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Configure Dispensers',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Set up your fuel dispensing units. Each dispenser can have multiple nozzles which you\'ll configure in the next step.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 5),

          if (_error.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _error,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _drafts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final d = _drafts[index];
              return _EnhancedDispenserDraftCard(
                draft: d,
                dispenserNumber: index + 1,
                onRemove: _drafts.length == 1
                    ? null
                    : () {
                  setState(() {
                    _drafts.removeAt(index);
                  });
                },
                onChanged: () {
                  setState(() {});
                },
              );
            },
          ),

          const SizedBox(height: 5),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _drafts.add(_DispenserDraft(
                        number: (_drafts.last.number + 1),
                        nozzles: 2,
                        status: 'Active',
                      ));
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Dispenser'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _submitAll,
              icon: _saving
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.save),
              label: Text(_saving ? 'Saving...' : 'Save & Continue'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DispenserDraft {
  int number;
  int nozzles;
  String status;
  String? dispenserName;

  _DispenserDraft({
    required this.number,
    required this.nozzles,
    required this.status,
    this.dispenserName,
  });
}

class _EnhancedDispenserDraftCard extends StatelessWidget {
  final _DispenserDraft draft;
  final int dispenserNumber;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  const _EnhancedDispenserDraftCard({
    required this.draft,
    required this.dispenserNumber,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Dispenser $dispenserNumber',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                  tooltip: 'Remove dispenser',
                ),
            ],
          ),

          const SizedBox(height: 16),

          TextFormField(
            initialValue: draft.dispenserName ?? '',
            decoration: InputDecoration(
              labelText: 'Dispenser Name',
              hintText: 'Enter dispenser name (required)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
              ),
              prefixIcon: const Icon(Icons.label_outline),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            onChanged: (v) {
              draft.dispenserName = v.trim();
              onChanged();
            },
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: draft.number.toString(),
                  decoration: InputDecoration(
                    labelText: 'Dispenser Number',
                    hintText: '1',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.numbers),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    draft.number = int.tryParse(v) ?? draft.number;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 16),

            ],
          ),

          const SizedBox(height: 16),
          Row(
            children: [

              Expanded(
                flex: 3,
                child: DropdownButtonFormField<int>(
                  value: draft.nozzles,
                  decoration: InputDecoration(
                    labelText: 'Number of Nozzles',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.api),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  items: List.generate(6, (i) => i + 1).map((n) =>
                      DropdownMenuItem(
                        value: n,
                        child: Text('$n nozzle${n > 1 ? 's' : ''}'),
                      ),
                  ).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      draft.nozzles = v;
                      onChanged();
                    }
                  },
                ),
              ),

            ]

          ),

          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: draft.status,
            decoration: InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
              ),
              prefixIcon: Icon(
                draft.status == 'Active'
                    ? Icons.check_circle
                    : draft.status == 'Maintenance'
                    ? Icons.build
                    : Icons.cancel,
                color: draft.status == 'Active'
                    ? Colors.green
                    : draft.status == 'Maintenance'
                    ? Colors.orange
                    : Colors.red,
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            items: const [
              DropdownMenuItem(value: 'Active', child: Text('Active')),
              DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
              DropdownMenuItem(value: 'Maintenance', child: Text('Maintenance')),
            ],
            onChanged: (v) {
              if (v != null) {
                draft.status = v;
                onChanged();
              }
            },
          ),
        ],
      ),
    );
  }
}

// Enhanced Nozzles Step
class NozzlesStep extends StatefulWidget {
  final VoidCallback onCompleted;
  const NozzlesStep({super.key, required this.onCompleted});

  @override
  State<NozzlesStep> createState() => _NozzlesStepState();
}

class _NozzlesStepState extends State<NozzlesStep> {
  final FuelDispenserRepository _dispRepo = FuelDispenserRepository();
  final FuelTankRepository _tankRepo = FuelTankRepository();
  final NozzleRepository _nozzleRepo = NozzleRepository();

  bool _loading = true;
  String _error = '';
  List<FuelDispenser> _dispensers = [];
  List<FuelTank> _tanks = [];
  final Map<String, List<_NozzleDraft>> _draftsByDispenser = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final pumpId = await _dispRepo.getPetrolPumpId();
      if (pumpId == null) {
        setState(() {
          _error = 'Petrol pump ID not found';
          _loading = false;
        });
        return;
      }

      final dispResp = await _dispRepo.getFuelDispensersByPetrolPumpId(pumpId);
      final tanksResp = await _tankRepo.getAllFuelTanks();

      if (!mounted) return;

      if (dispResp.success && dispResp.data != null) {
        _dispensers = dispResp.data!;
      } else {
        _error = dispResp.errorMessage ?? 'Failed to load dispensers';
      }

      if (tanksResp.success && tanksResp.data != null) {
        _tanks = tanksResp.data!;
      } else {
        _error = tanksResp.errorMessage ?? 'Failed to load tanks';
      }

      for (final d in _dispensers) {
        _draftsByDispenser.putIfAbsent(d.id, () => [
          _NozzleDraft(nozzleNumber: 1)
        ]);
      }

      setState(() { _loading = false; });
    } catch (e) {
      setState(() { _error = 'Error: $e'; _loading = false; });
    }
  }

  Future<void> _submitAll() async {
    setState(() { _saving = true; _error = ''; });
    try {
      final pumpId = await _dispRepo.getPetrolPumpId();
      if (pumpId == null) {
        setState(() {
          _error = 'Petrol pump ID not found';
          _saving = false;
        });
        return;
      }

      for (final entry in _draftsByDispenser.entries) {
        final dispenserId = entry.key;
        for (final draft in entry.value) {
          if (draft.fuelTankId == null || draft.nozzleNumber < 1 || draft.nozzleNumber > 8) {
            if (mounted) {
              showAnimatedSnackBar(
                context: context,
                message: 'Please fill all nozzle details correctly',
                isError: true,
              );
            }
            setState(() {
              _saving = false;
            });
            return;
          }
        }
      }

      for (final entry in _draftsByDispenser.entries) {
        final dispenserId = entry.key;
        for (final draft in entry.value) {
          final nozzle = Nozzle(
            id: '',
            fuelDispenserUnitId: dispenserId,
            nozzleNumber: draft.nozzleNumber,
            status: draft.active ? 'Active' : 'Inactive',
            lastCalibrationDate: null,
            fuelTankId: draft.fuelTankId,
            petrolPumpId: pumpId,
            fuelType: null,
          );

          final resp = await _nozzleRepo.addNozzle(nozzle);
          if (!resp.success) {
            setState(() {
              _error = resp.errorMessage ?? 'Failed to add nozzle';
              _saving = false;
            });
            return;
          }
        }
      }

      if (!mounted) return;
      showAnimatedSnackBar(
        context: context,
        message: 'Nozzles configured successfully!',
        isError: false,
      );
      widget.onCompleted();
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Error: $e'; });
    } finally {
      if (mounted) setState(() { _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading nozzle configuration...'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Configure Nozzles',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Link nozzles to dispensers and connect them to your fuel tanks. Each nozzle will dispense fuel from a specific tank.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          if (_error.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _error,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _dispensers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 20),
            itemBuilder: (context, index) {
              final disp = _dispensers[index];
              final drafts = _draftsByDispenser[disp.id] ?? [];
              return _EnhancedDispenserNozzlesCard(
                dispenser: disp,
                tanks: _tanks,
                drafts: drafts,
                onAddNozzle: () {
                  setState(() {
                    drafts.add(_NozzleDraft(
                      nozzleNumber: (drafts.isNotEmpty
                          ? drafts.last.nozzleNumber + 1
                          : 1),
                    ));
                  });
                },
                onRemoveNozzle: (i) {
                  setState(() {
                    if (drafts.length > 1) drafts.removeAt(i);
                  });
                },
                onChanged: () {
                  setState(() {});
                },
              );
            },
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _submitAll,
              icon: _saving
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.save),
              label: Text(_saving ? 'Saving Nozzles...' : 'Save & Continue'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NozzleDraft {
  int nozzleNumber;
  String? fuelTankId;
  bool active = true;

  _NozzleDraft({required this.nozzleNumber, this.fuelTankId});
}

class _EnhancedDispenserNozzlesCard extends StatelessWidget {
  final FuelDispenser dispenser;
  final List<FuelTank> tanks;
  final List<_NozzleDraft> drafts;
  final VoidCallback onAddNozzle;
  final Function(int) onRemoveNozzle;
  final VoidCallback onChanged;

  const _EnhancedDispenserNozzlesCard({
    required this.dispenser,
    required this.tanks,
    required this.drafts,
    required this.onAddNozzle,
    required this.onRemoveNozzle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.purple.withValues(alpha: 0.8),
                      Colors.purple.withValues(alpha: 0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.ev_station,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Dispenser #${dispenser.dispenserNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${drafts.length} nozzle${drafts.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Column(
            children: List.generate(drafts.length, (i) {
              final d = drafts[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Nozzle ${i + 1}',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: d.active,
                          onChanged: (v) {
                            d.active = v;
                            onChanged();
                          },
                          activeColor: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: drafts.length > 1 ? () => onRemoveNozzle(i) : null,
                          icon: Icon(
                            Icons.delete_outline,
                            color: drafts.length > 1 ? Colors.red.shade400 : Colors.grey.shade300,
                          ),
                          tooltip: 'Remove nozzle',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ConstrainedBox(
                                  constraints: BoxConstraints(minWidth: 120, maxWidth: MediaQuery.of(context).size.width - 180),
                                  child: Expanded(
                                    flex: 3,
                                    child: DropdownButtonFormField<String>(
                                      value: d.fuelTankId,
                                      decoration: InputDecoration(
                                        labelText: 'Connected Tank',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      items: tanks.map((t) => DropdownMenuItem(
                                        value: t.fuelTankId,
                                        child: Text(
                                          '${t.fuelTankName} (${t.capacityInLiters.toStringAsFixed(0)}L)',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      )).toList(),
                                      onChanged: (v) {
                                        d.fuelTankId = v;
                                        onChanged();
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 55,
                                  child: TextFormField(
                                    initialValue: d.nozzleNumber.toString(),
                                    decoration: InputDecoration(
                                      labelText: 'No.',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    ),
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    onChanged: (v) {
                                      d.nozzleNumber = int.tryParse(v) ?? d.nozzleNumber;
                                      onChanged();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ),

          OutlinedButton.icon(
            onPressed: onAddNozzle,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Nozzle'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Enhanced Fuel Pricing Step
class FuelPricingStep extends StatefulWidget {
  final VoidCallback onCompleted;
  const FuelPricingStep({super.key, required this.onCompleted});

  @override
  State<FuelPricingStep> createState() => _FuelPricingStepState();
}

class _FuelPricingStepState extends State<FuelPricingStep> {
  final PricingRepository _pricingRepo = PricingRepository();
  final PumpRepository _pumpRepo = PumpRepository();
  
  bool _loading = true;
  String _error = '';
  List<FuelType> _pumpFuelTypes = [];
  final Map<String, _PriceDraft> _priceDrafts = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final profileResp = await _pumpRepo.getPumpProfile();
      if (!profileResp.success || profileResp.data == null || profileResp.data!.petrolPumpId == null) {
        setState(() {
          _error = profileResp.errorMessage ?? 'Failed to load profile';
          _loading = false;
        });
        return;
      }

      final pumpId = profileResp.data!.petrolPumpId!;
      final fuelTypesResp = await _pumpRepo.getPumpFuelTypes(pumpId);

      if (fuelTypesResp.success && fuelTypesResp.data != null) {
        _pumpFuelTypes = fuelTypesResp.data!;
        
        // Initialize price drafts for each fuel type
        for (final fuelType in _pumpFuelTypes) {
          _priceDrafts[fuelType.fuelTypeId] = _PriceDraft(
            fuelTypeId: fuelType.fuelTypeId,
            fuelTypeName: fuelType.name,
            pricePerLiter: 0.0,
            effectiveFrom: DateTime.now(),
          );
        }
      } else {
        _error = fuelTypesResp.errorMessage ?? 'Failed to load pump fuel types';
      }

      setState(() { _loading = false; });
    } catch (e) {
      setState(() { _error = 'Error: $e'; _loading = false; });
    }
  }

  Future<void> _submitAll() async {
    setState(() { _saving = true; _error = ''; });
    try {
      final pumpId = await _pricingRepo.getPumpId();
      if (pumpId == null) {
        setState(() {
          _error = 'Petrol pump ID not found';
          _saving = false;
        });
        return;
      }

      // Validate all price drafts
      for (final entry in _priceDrafts.entries) {
        final draft = entry.value;
        if (draft.pricePerLiter <= 0) {
          showAnimatedSnackBar(
            context: context,
            message: 'Please enter a valid price for ${draft.fuelTypeName}',
            isError: true,
          );
          setState(() { _saving = false; });
          return;
        }
      }

      // Save all prices
      for (final entry in _priceDrafts.entries) {
        final draft = entry.value;
        final price = FuelPrice(
          effectiveFrom: draft.effectiveFrom,
          fuelType: draft.fuelTypeName,
          fuelTypeId: draft.fuelTypeId,
          pricePerLiter: draft.pricePerLiter,
          petrolPumpId: pumpId,
          lastUpdatedBy: await _pricingRepo.getEmployeeId(),
        );

        final resp = await _pricingRepo.setFuelPrice(price);
        if (!resp.success) {
          setState(() {
            _error = resp.errorMessage ?? 'Failed to save price for ${draft.fuelTypeName}';
            _saving = false;
          });
          return;
        }
      }

      if (!mounted) return;
      showAnimatedSnackBar(
        context: context,
        message: 'Fuel prices saved successfully!',
        isError: false,
      );
      widget.onCompleted();
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Error: $e'; });
    } finally {
      if (mounted) setState(() { _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading fuel pricing...'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Set Fuel Prices',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Set the selling prices for each fuel type. You can update these prices anytime from your dashboard.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          if (_error.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _error,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _priceDrafts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final entry = _priceDrafts.entries.elementAt(index);
              final draft = entry.value;
              return _EnhancedPriceDraftCard(
                draft: draft,
                onChanged: () {
                  setState(() {});
                },
              );
            },
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _submitAll,
              icon: _saving
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.save),
              label: Text(_saving ? 'Saving Prices...' : 'Save & Continue'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceDraft {
  final String fuelTypeId;
  final String fuelTypeName;
  double pricePerLiter;
  DateTime effectiveFrom;
  // Removed cost and markup fields per API update

  _PriceDraft({
    required this.fuelTypeId,
    required this.fuelTypeName,
    required this.pricePerLiter,
    required this.effectiveFrom,
  });
}

class _EnhancedPriceDraftCard extends StatelessWidget {
  final _PriceDraft draft;
  final VoidCallback onChanged;

  const _EnhancedPriceDraftCard({
    required this.draft,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.green.withValues(alpha: 0.8),
                      Colors.green.withValues(alpha: 0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_gas_station,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      draft.fuelTypeName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Price per liter (required)
          TextFormField(
            initialValue: draft.pricePerLiter > 0 ? draft.pricePerLiter.toStringAsFixed(2) : '',
            decoration: InputDecoration(
              labelText: 'Price per Liter (₹) *',
              hintText: 'Enter selling price',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
              ),
              prefixIcon: const Icon(Icons.attach_money),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) {
              draft.pricePerLiter = double.tryParse(v) ?? 0.0;
              onChanged();
            },
          ),

          const SizedBox(height: 12),

          // Effective From date selector
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: draft.effectiveFrom,
                firstDate: DateTime.now().subtract(const Duration(days: 3650)),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
              );
              if (picked != null) {
                // Preserve time component as 06:00 like examples, optional
                final adjusted = DateTime(picked.year, picked.month, picked.day, draft.effectiveFrom.hour, draft.effectiveFrom.minute);
                draft.effectiveFrom = adjusted;
                onChanged();
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Effective From',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
                ),
                prefixIcon: const Icon(Icons.calendar_today),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${draft.effectiveFrom.year.toString().padLeft(4, '0')}-${draft.effectiveFrom.month.toString().padLeft(2, '0')}-${draft.effectiveFrom.day.toString().padLeft(2, '0')}',
                    style: TextStyle(color: Colors.grey.shade800),
                  ),
                  const Icon(Icons.edit_calendar, size: 18, color: AppTheme.primaryBlue),
                ],
              ),
            ),
          ),

          // Removed cost and markup fields per API update
        ],
      ),
    );
  }
}

// Enhanced Finish Step
class _FinishStep extends StatelessWidget {
  const _FinishStep();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green.withValues(alpha: 0.2),
                  Colors.green.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Setup Complete! 🎉',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Your pump is now configured and ready to start operating. You can always modify these settings later from your dashboard.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(height: 8),
                Text(
                  'Next Steps',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Set fuel prices, manage inventory, and start processing sales from your dashboard.',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
