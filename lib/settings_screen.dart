import 'package:flutter/material.dart';
import 'auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AuthService _authService;
  bool isSubscribed = false;
  bool isLoading = false;
  Map<String, dynamic>? userProfile;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() => isLoading = true);
    
    final profile = await _authService.getUserProfile();
    
    setState(() {
      userProfile = profile;
      isSubscribed = profile?['isSubscribed'] ?? false;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Settings")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final user = _authService.currentUser;
    final email = userProfile?['email'] ?? user?.email ?? "Not signed in";
    final displayName = userProfile?['displayName'] ?? "FuelLink User";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings & Preferences"),
        elevation: 0,
      ),
      body: ListView(
        children: [
          // User Profile Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: userProfile?['photoUrl'] != null
                          ? NetworkImage(userProfile!['photoUrl'])
                          : null,
                      child: userProfile?['photoUrl'] == null
                          ? const Icon(Icons.person, size: 40)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Email Subscription Section (REVENUE CRITICAL!)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "📧 Daily Ontario Gas Report",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Get today's lowest gas prices in your inbox every morning at 7:00 AM EST.",
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    "Receive Daily Reports",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green[700],
                    ),
                  ),
                  subtitle: isSubscribed
                      ? const Text("You're subscribed! Next email in: ~8 hours")
                      : const Text("Tap to subscribe and save daily"),
                  value: isSubscribed,
                  onChanged: (value) async {
                    setState(() => isLoading = true);
                    
                    await _authService.updateSubscriptionStatus(value);
                    
                    setState(() {
                      isSubscribed = value;
                      isLoading = false;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          value 
                              ? "✅ You're subscribed to daily gas reports!"
                              : "❌ You've unsubscribed from emails",
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                // Revenue hook: Mention YouTube integration
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.youtube_searched_for, size: 16, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Plus: Link to latest FuelLink YouTube Shorts in every email!",
                          style: TextStyle(fontSize: 11, color: Colors.amber[800]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Preferences Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "PREFERENCES",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Vehicle Size Preference
          ListTile(
            leading: const Icon(Icons.directions_car, color: Colors.blue),
            title: const Text("Preferred Vehicle Size"),
            subtitle: Text(
              userProfile?['preferredVehicleSize'] == 40
                  ? "🚗 Compact (Honda Civic - 40L)"
                  : userProfile?['preferredVehicleSize'] == 65
                      ? "🚙 SUV (Toyota RAV4 - 65L)"
                      : userProfile?['preferredVehicleSize'] == 95
                          ? "🛻 Truck (Ford F-150 - 95L)"
                          : "Custom (${userProfile?['preferredVehicleSize']?.toStringAsFixed(0)}L)",
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              _showVehiclePreferenceDialog(context);
            },
          ),

          // Province/Location
          ListTile(
            leading: const Icon(Icons.location_on, color: Colors.orange),
            title: const Text("Primary Location"),
            subtitle: Text(userProfile?['province'] ?? 'ON'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Future: Add multi-province support
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Multi-province support coming soon!")),
              );
            },
          ),

          const SizedBox(height: 20),

          // Account Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "ACCOUNT",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Privacy & Legal
          ListTile(
            leading: const Icon(Icons.privacy_tip, color: Colors.grey),
            title: const Text("Privacy Policy"),
            subtitle: const Text("View our data handling practices"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // TODO: Open privacy policy URL
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Opening privacy policy..."),
                ),
              );
            },
          ),

          // Sign Out
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Sign Out"),
            subtitle: const Text("End your current session"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              _showSignOutDialog(context);
            },
          ),

          // Delete Account (Dangerous)
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text("Delete Account"),
            subtitle: const Text("Permanently remove your data"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              _showDeleteAccountDialog(context);
            },
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  void _showVehiclePreferenceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Select Vehicle Type"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildVehicleOption("🚗 Compact (40L)", 40),
              _buildVehicleOption("🚙 SUV (65L)", 65),
              _buildVehicleOption("🛻 Truck (95L)", 95),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVehicleOption(String label, double tankSize) {
    return GestureDetector(
      onTap: () async {
        await _authService.updateUserPreferences(preferredVehicleSize: tankSize);
        setState(() {
          userProfile?['preferredVehicleSize'] = tankSize;
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Preference saved: $label")),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Icon(Icons.check_circle_outline, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Sign Out?"),
          content: const Text("Are you sure you want to sign out of FuelLink?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await _authService.signOut();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/');
                }
              },
              child: const Text("Sign Out", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Account?"),
          content: const Text(
            "This action cannot be undone. All your data will be permanently deleted.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await _authService.deleteAccount();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/');
                }
              },
              child: const Text(
                "Delete",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
