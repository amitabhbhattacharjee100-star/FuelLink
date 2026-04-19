import 'package:flutter/material.dart';
import 'auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late AuthService _authService;
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => isLoading = true);

    try {
      final email = await _authService.signInWithGoogle();
      
      if (email != null && mounted) {
        // Sign-in successful, navigate to main app
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        setState(() {
          errorMessage = "Sign-in cancelled";
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Sign-in failed: $e";
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green[400]!, Colors.green[700]!],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top spacer
              const SizedBox(height: 40),

              // Logo & Headline
              Column(
                children: [
                  // App Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        "⛽",
                        style: TextStyle(fontSize: 48),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "FuelLink",
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Ontario's Gas Price Comparison",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),

              // Value Proposition
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Why join FuelLink?",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildBenefitRow(
                      "ðŸ’° Save \$3-7/tank",
                      "Find the cheapest gas nearby",
                    ),
                    const SizedBox(height: 12),
                    _buildBenefitRow(
                      "📧 Daily Reports",
                      "Top savings delivered every morning",
                    ),
                    const SizedBox(height: 12),
                    _buildBenefitRow(
                      "⏰ Smart Timing",
                      "Get alerts when prices are lowest",
                    ),
                  ],
                ),
              ),

              // Sign-in Section
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Error message
                    if (errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[300]!, width: 1),
                        ),
                        child: Text(
                          errorMessage!,
                          style: TextStyle(color: Colors.red[700], fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Google Sign-In Button
                    ElevatedButton(
                      onPressed: isLoading ? null : _signInWithGoogle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.grey[800],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 4,
                        disabledBackgroundColor: Colors.grey[300],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isLoading)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          else
                            const Text("🔐 ", style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 12),
                          Text(
                            isLoading ? "Signing in..." : "Sign in with Google",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Privacy Note
                    Text(
                      "By signing in, you agree to our Privacy Policy.\nYour data is never shared.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitRow(String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }
}
