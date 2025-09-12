import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../api/api_constants.dart';
import '../../api/auth_repository.dart';
import '../../theme.dart';
import '../login/login_screen.dart';
import '../onboarding/onboarding_flow_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/jwt_decoder.dart';
import '../../widgets/custom_snackbar.dart';

class RegisterPumpScreen extends StatefulWidget {
  const RegisterPumpScreen({super.key});

  @override
  State<RegisterPumpScreen> createState() => _RegisterPumpScreenState();
}

class _RegisterPumpScreenState extends State<RegisterPumpScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _pumpNameController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _sapNoController = TextEditingController();
  final List<String> _companyOptions = const [
    'Indian Oil',
    'HP',
    'Bharat Petroleum',
    'Reliance',
    'Shell',
    'Nayara Energy (Essar)',
    'Adani',
    'GAIL',
    'Indraprastha Gas (IGL)',
    'Mahanagar Gas (MGL)',
    'Tata Power',
    'Other'
  ];

  String? _selectedCompany;
  
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String _errorMessage = '';
  
  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    
    // Start animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _pumpNameController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _licenseNumberController.dispose();
    _companyNameController.dispose();
    _sapNoController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _registerPump() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    final authRepository = AuthRepository();
    
    try {
      final String? selectedCompanyName = _selectedCompany == null
          ? null
          : (_selectedCompany == 'Other' ? (_companyNameController.text.isNotEmpty ? _companyNameController.text : null) : _selectedCompany);
      final response = await authRepository.registerPump(
        name: _pumpNameController.text,
        contactNumber: _contactNumberController.text,
        email: _emailController.text,
        password: _passwordController.text,
        licenseNumber: _licenseNumberController.text,
        companyName: selectedCompanyName,
        sapNo: _sapNoController.text,
      );

      setState(() {
        _isLoading = false;
      });

      if (response.success) {
        // Registration successful
        showAnimatedSnackBar(
          context: context,
          message: 'Pump registered successfully',
          isError: false,
        );
        // Attempt auto-login to obtain auth token
        try {
          final loginResp = await authRepository.login(
            _emailController.text,
            _passwordController.text,
            _sapNoController.text,
          );
          if (loginResp.success && loginResp.data != null) {
            final token = loginResp.data!['token'];
            if (token != null && token is String) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(ApiConstants.authTokenKey, token);
              // Persist common claims for later use
              try {
                final claims = JwtDecoder.decode(token);
                final userId = JwtDecoder.getClaim<String>(token, 'userId') ?? JwtDecoder.getClaim<String>(token, 'sub');
                final role = JwtDecoder.getClaim<String>(token, 'role') ?? JwtDecoder.getClaim<String>(token, 'userRole');
                final petrolPumpId = JwtDecoder.getClaim<String>(token, 'petrolPumpId');
                if (userId != null) await prefs.setString('userId', userId);
                if (role != null) await prefs.setString('userRole', role);
                if (petrolPumpId != null) await prefs.setString('petrolPumpId', petrolPumpId);
              } catch (_) {}
              // Initialize onboarding flags
              await prefs.setBool('onboarding_completed', false);
              await prefs.setInt('onboarding_step', 0);
              // Navigate to onboarding flow
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const OnboardingFlowScreen()),
              );
              return;
            }
          }
          // If auto-login failed, fall back to login screen
          showAnimatedSnackBar(
            context: context,
            message: 'Please sign in to continue setup',
            isError: true,
          );
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        } catch (_) {
          // On exception, route to login
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      } else {
        // Show error message
        setState(() {
          _errorMessage = response.errorMessage ?? ApiConstants.someThingWentWrong;
        });
        
        showAnimatedSnackBar(
          context: context,
          message: _errorMessage,
          isError: true,
        );
      }
    } catch (error) {
      // Handle any errors
      setState(() {
        _isLoading = false;
        _errorMessage = ApiConstants.internetConnectionMsg;
      });
      
      showAnimatedSnackBar(
        context: context,
        message: _errorMessage,
        isError: true,
      );
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _registerPump();
    }
  }

  String? validateEmail(String value) {
    String pattern =
        r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$';
    RegExp regExp = RegExp(pattern);
    if (value.isEmpty) {
      return "Email is Required";
    } else if (!regExp.hasMatch(value)) {
      return "Invalid Email";
    } else {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primaryOrange,
                AppTheme.primaryOrange.withValues(alpha:0.8),
                Colors.white,
              ],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo and Branding
                        Align(
                          alignment: Alignment.center,
                          child: Hero(
                            tag: 'logo',
                            child: Container(
                              height: 100,
                              width: 100,
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha:0.1),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/logo.jpg',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Title
                        Text(
                          'Register Petrol Pump',
                          style: AppTheme.headingStyle.copyWith(
                            fontSize: 28,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                blurRadius: 10.0,
                                color: Colors.black.withValues(alpha:0.2),
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your account to get started',
                          style: AppTheme.subheadingStyle.copyWith(
                            color: Colors.white.withValues(alpha:0.9),
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),
                        
                        // Registration Card
                        Card(
                          elevation: 10,
                          shadowColor: Colors.black26,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Form Title
                                  Text(
                                    'Pump Information',
                                    style: AppTheme.subheadingStyle.copyWith(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  // Pump Name Field
                                  TextFormField(
                                    controller: _pumpNameController,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter pump name';
                                      }
                                      return null;
                                    },
                                    decoration: InputDecoration(
                                      labelText: 'Name',
                                      prefixIcon: Icon(
                                        Icons.local_gas_station,
                                        color: AppTheme.primaryOrange,
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: AppTheme.primaryOrange,
                                          width: 1.5,
                                        ),
                                      ),
                                      labelStyle: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                        horizontal: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Company Name (Dropdown + Optional custom)
                                  DropdownButtonFormField<String>(
                                    value: _selectedCompany,
                                    items: _companyOptions
                                        .map((c) => DropdownMenuItem<String>(value: c, child: Text(c)))
                                        .toList(),
                                    decoration: InputDecoration(
                                      labelText: 'Company',
                                      prefixIcon: Icon(
                                        Icons.business_outlined,
                                        color: AppTheme.primaryOrange,
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: AppTheme.primaryOrange,
                                          width: 1.5,
                                        ),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                        horizontal: 12,
                                      ),
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedCompany = val;
                                      });
                                    },
                                    validator: (v) => (v == null || v.isEmpty) ? 'Please select company' : null,
                                  ),
                                  if (_selectedCompany == 'Other') ...[
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _companyNameController,
                                      validator: (v) {
                                        if (_selectedCompany == 'Other') {
                                          if (v == null || v.trim().isEmpty) {
                                            return 'Please enter company name';
                                          }
                                        }
                                        return null;
                                      },
                                      decoration: InputDecoration(
                                        labelText: 'Enter Company Name',
                                        prefixIcon: Icon(
                                          Icons.edit_outlined,
                                          color: AppTheme.primaryOrange,
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade200,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: AppTheme.primaryOrange,
                                            width: 1.5,
                                          ),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                          horizontal: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  // Contact Number Field
                                  TextFormField(
                                    controller: _contactNumberController,
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter contact number';
                                      }
                                      if (value.length < 10) {
                                        return 'Please enter a valid phone number';
                                      }
                                      return null;
                                    },
                                    decoration: InputDecoration(
                                      labelText: 'Phone Number',
                                      prefixIcon: Icon(
                                        Icons.phone_outlined,
                                        color: AppTheme.primaryOrange,
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: AppTheme.primaryOrange,
                                          width: 1.5,
                                        ),
                                      ),
                                      labelStyle: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                        horizontal: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Email Field
                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (value) => validateEmail(value!),
                                    decoration: InputDecoration(
                                      labelText: 'Email',
                                      prefixIcon: Icon(
                                        Icons.email_outlined,
                                        color: AppTheme.primaryOrange,
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: AppTheme.primaryOrange,
                                          width: 1.5,
                                        ),
                                      ),
                                      labelStyle: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                        horizontal: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Password Field
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: !_isPasswordVisible,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your password';
                                      }
                                      if (value.length < 6) {
                                        return 'Password must be at least 6 characters';
                                      }
                                      return null;
                                    },
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      prefixIcon: Icon(
                                        Icons.lock_outline,
                                        color: AppTheme.primaryOrange,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _isPasswordVisible
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          color: Colors.grey.shade600,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _isPasswordVisible = !_isPasswordVisible;
                                          });
                                        },
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: AppTheme.primaryOrange,
                                          width: 1.5,
                                        ),
                                      ),
                                      labelStyle: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                        horizontal: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // SAP Number Field
                                  TextFormField(
                                    controller: _sapNoController,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter SAP number';
                                      }
                                      return null;
                                    },
                                    decoration: InputDecoration(
                                      labelText: 'SAP Number',
                                      prefixIcon: Icon(
                                        Icons.numbers,
                                        color: AppTheme.primaryOrange,
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: AppTheme.primaryOrange,
                                          width: 1.5,
                                        ),
                                      ),
                                      labelStyle: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                        horizontal: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // License Number Field
                                  TextFormField(
                                    controller: _licenseNumberController,
                                    decoration: InputDecoration(
                                      labelText: 'License Number (Optional)',
                                      prefixIcon: Icon(
                                        Icons.badge_outlined,
                                        color: AppTheme.primaryOrange,
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: AppTheme.primaryOrange,
                                          width: 1.5,
                                        ),
                                      ),
                                      labelStyle: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                        horizontal: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  

                                  
                                  // Error Message
                                  if (_errorMessage.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 16.0),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: Colors.red.shade200,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.error_outline,
                                              color: Colors.red.shade700,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _errorMessage,
                                                style: TextStyle(
                                                  color: Colors.red.shade700,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  
                                  const SizedBox(height: 24),
                                  
                                  // Register Button
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _submitForm,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryOrange,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 3,
                                        shadowColor: AppTheme.primaryOrange.withValues(alpha:0.5),
                                        disabledBackgroundColor: AppTheme.primaryOrange.withValues(alpha:0.6),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text(
                                              'Register Pump',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Return to Login
                                  Center(
                                    child: TextButton.icon(
                                      onPressed: () {
                                        Navigator.of(context).pushReplacement(
                                          MaterialPageRoute(
                                            builder: (context) => const LoginScreen(),
                                          ),
                                        );
                                      },
                                      icon: Icon(
                                        Icons.arrow_back,
                                        size: 18,
                                        color: AppTheme.primaryBlue,
                                      ),
                                      label: Text(
                                        'Back to Login',
                                        style: TextStyle(
                                          color: AppTheme.primaryBlue,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 