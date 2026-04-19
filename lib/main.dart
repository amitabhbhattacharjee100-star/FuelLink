import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'gas_api.dart';
import 'auth_service.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

Future<void> main() async {
  // Ensure Flutter is ready for async calls and plugin initialization
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Load environment variables from .env
  await dotenv.load(fileName: ".env");
  
  // Start Ad engine for revenue
  MobileAds.instance.initialize();
  
  runApp(const FuelLinkApp());
}

class FuelLinkApp extends StatelessWidget {
  const FuelLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FuelLink Ontario',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
      routes: {
        '/home': (_) => const MapCompareScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}

/// Wrapper that determines which screen to show based on auth state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[400]!, Colors.green[700]!],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          );
        }

        // User is logged in
        if (snapshot.hasData && snapshot.data != null) {
          return const MapCompareScreen();
        }

        // User is not logged in
        return const LoginScreen();
      },
    );
  }
}

class MapCompareScreen extends StatefulWidget {
  const MapCompareScreen({super.key});

  @override
  State<MapCompareScreen> createState() => _MapCompareScreenState();
}

class _MapCompareScreenState extends State<MapCompareScreen> {
  late GasPriceService gasPriceService;
  double? stationAPrice;
  double? stationBPrice;
  String stationAName = "Station A";
  String stationBName = "Station B";
  bool isLoading = true;
  String? errorMessage;
  double tankSize = 50.0; // Default tank size in liters

  @override
  void initState() {
    super.initState();
    gasPriceService = GasPriceService();
    _fetchGasPrices();
  }

  Future<void> _fetchGasPrices() async {
    try {
      final ontarioData = await gasPriceService.fetchOntarioPrices();
      
      if (ontarioData.isEmpty) {
        setState(() {
          errorMessage = "No gas stations found in Ontario";
          isLoading = false;
        });
        return;
      }

      // Get cheapest station
      final cheapestStation = gasPriceService.getCheapestStation(ontarioData);
      
      // Find a more expensive station for comparison
      Map<String, dynamic>? expensiveStation;
      double? maxPrice;
      
      ontarioData.forEach((city, stations) {
        for (var station in stations) {
          double price = station['price'];
          if (maxPrice == null || price > maxPrice!) {
            maxPrice = price;
            expensiveStation = {
              'city': city,
              'name': station['name'],
              'price': price,
            };
          }
        }
      });

      setState(() {
        stationAPrice = expensiveStation?['price']?.toDouble() ?? 150.0;
        stationBPrice = cheapestStation?['price']?.toDouble() ?? 140.0;
        stationAName = expensiveStation?['name'] ?? "Station A";
        stationBName = cheapestStation?['name'] ?? "Station B";
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = "Failed to fetch gas prices: $e";
        isLoading = false;
      });
      print("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("FuelLink: Ontario Savings")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("FuelLink: Ontario Savings")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    isLoading = true;
                    errorMessage = null;
                  });
                  _fetchGasPrices();
                },
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    double dollarSavings = gasPriceService.calculateSavings(
      stationAPrice!,
      stationBPrice!,
      tankSize: tankSize,
    );
    String cheaperStation = stationAPrice! < stationBPrice! ? stationAName : stationBName;
    String displaySavings = dollarSavings.toStringAsFixed(2); // Ensure precise decimal formatting

    return Scaffold(
      appBar: AppBar(
        title: const Text("FuelLink: Ontario Savings"),
        actions: [
          // Settings button
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
                child: const Tooltip(
                  message: "Settings & Preferences",
                  child: Icon(Icons.settings, size: 24),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. THE MAP
          const GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(43.6532, -79.3832), // Toronto Coordinates
              zoom: 12,
            ),
          ),
          
          // 2. THE SAVINGS OVERLAY (High-engagement positioning for ad revenue)
          // Psychology: "Save $X" message creates urgency → Users stay longer → More ad impressions
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HOOK: High-impact savings message (social media worthy!)
                  Row(
                    children: [
                      const Icon(Icons.trending_down, color: Colors.green, size: 28),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Save \$$displaySavings TODAY",
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            Text(
                              "on a full tank at $cheaperStation",
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 14),
                  
                  // Price comparison
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            Text(
                              stationAName,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              "${stationAPrice?.toStringAsFixed(1)}¢",
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                            ),
                          ],
                        ),
                        const Icon(Icons.arrow_forward, color: Colors.green),
                        Column(
                          children: [
                            Text(
                              stationBName,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              "${stationBPrice?.toStringAsFixed(1)}¢",
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 14),
                  
                  // SMART TIP: McTeague Logic - Ontario pricing patterns with Volatility Multiplier
                  // Psychology: "Wait 2 hours and save even more" keeps user engaged
                  // Current price: ${((stationAPrice! + stationBPrice!) / 2).toStringAsFixed(1)}¢ (avg)
                  ..._buildSmartTipWidget(
                    avgPrice: (stationAPrice! + stationBPrice!) / 2,
                  ),
                  
                  const SizedBox(height: 14),
                  
                  // Vehicle preset buttons: Common Ontario vehicles
                  const Text("Vehicle Type:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPresetButton("🚗 Civic\n40L", 40.0),
                        const SizedBox(width: 8),
                        _buildPresetButton("🚙 RAV4\n65L", 65.0),
                        const SizedBox(width: 8),
                        _buildPresetButton("🛻 F-150\n95L", 95.0),
                        const SizedBox(width: 8),
                        _buildPresetButton("⚙️ Custom", null), // Open dialog for custom
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Fine-grained slider for advanced users
                  Row(
                    children: [
                      const Text("Tank: ", style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: tankSize,
                          min: 20,
                          max: 100,
                          divisions: 16,
                          label: "${tankSize.toStringAsFixed(0)}L",
                          onChanged: (newSize) {
                            setState(() {
                              tankSize = newSize;
                            });
                          },
                        ),
                      ),
                      Text(
                        "${tankSize.toStringAsFixed(0)}L",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Content strategy note: YouTube integration hook
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Daily Ontario Gas Report: Share your savings on YouTube! (#FuelLink)",
                            style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 3. AD BANNER PLACEHOLDER (Position below savings card for psychology)
          Positioned(
            bottom: 10,
            left: 10,
            right: 10,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  "Google Ad Banner\n(Users engaged with savings → Higher CTR)",
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build quick-select preset button for common Ontario vehicles
  Widget _buildPresetButton(String label, double? tankVolume) {
    return GestureDetector(
      onTap: tankVolume != null
          ? () {
              setState(() {
                tankSize = tankVolume;
              });
            }
          : () {
              // Open custom tank size dialog
              _showCustomTankDialog();
            },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: tankSize == tankVolume ? Colors.green : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: tankSize == tankVolume ? Colors.green : Colors.grey[400]!,
            width: 2,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: tankSize == tankVolume ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }

  /// Dialog for custom tank size input
  void _showCustomTankDialog() {
    showDialog(
      context: context,
      builder: (context) {
        double customSize = tankSize;
        return AlertDialog(
          title: const Text("Custom Tank Size"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                value: customSize,
                min: 20,
                max: 150,
                divisions: 26,
                label: "${customSize.toStringAsFixed(0)}L",
                onChanged: (value) {
                  setState(() {
                    customSize = value;
                  });
                },
              ),
              Text(
                "Size: ${customSize.toStringAsFixed(0)}L",
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  tankSize = customSize;
                });
                Navigator.pop(context);
              },
              child: const Text("Set"),
            ),
          ],
        );
      },
    );
  }
  /// McTeague Logic: Build smart tip widget based on current time and price volatility
  /// Psychology: Strategic timing to keep users in the app longer
  /// "Wait 2 hours and save $X more" = Extended session = More ad impressions
  /// Volatility-aware: Adjusts savings estimate if prices are over 180¢
  List<Widget> _buildSmartTipWidget({
    double avgPrice = 0.0,
  }) {
    final tipData = gasPriceService.getSmartTipMessage(
      tankSize: tankSize,
      currentPrice: avgPrice,
    );
    final showTip = tipData['showTip'] as bool;
    
    if (!showTip) {
      return [];
    }

    final icon = tipData['icon'] as String;
    final title = tipData['title'] as String;
    final message = tipData['message'] as String;
    final timeRemaining = tipData['timeRemaining'] as String;
    final estimatedSavings = tipData['estimatedSavings'] as double;
    final colorCode = tipData['colorCode'] as String;
    
    // Map color code to Flutter Color
    final color = colorCode == 'amber' ? Colors.amber : Colors.green;

    // Format estimated savings for before 6 PM case
    final savingsText = gasPriceService.isAfterSixPM() 
        ? "" 
        : "\n💰 Additional savings: \$${estimatedSavings.toStringAsFixed(2)}";

    return [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withAlpha((color.alpha * 0.15).toInt()),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    timeRemaining + savingsText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }}