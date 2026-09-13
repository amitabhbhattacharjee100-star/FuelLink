import 'dart:io';
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
import 'price_history_screen.dart';

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
        '/history': (_) => const PriceHistoryScreen(),
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
  double tankSize = 50.0;

  // All stations flattened for list & map markers
  List<Map<String, dynamic>> allStations = [];
  Set<Marker> _mapMarkers = {};
  GoogleMapController? _mapController;

  // AdMob
  BannerAd? _bannerAd;
  bool _bannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    gasPriceService = GasPriceService();
    _fetchGasPrices();
    _loadBannerAd();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  void _loadBannerAd() {
    // TODO: Replace these test unit IDs with your real AdMob unit IDs from
    // .env or Firebase Remote Config before publishing to production.
    // Real IDs look like: ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX
    final adUnitId = dotenv.env[Platform.isAndroid
            ? 'ADMOB_BANNER_ANDROID'
            : 'ADMOB_BANNER_IOS'] ??
        (Platform.isAndroid
            ? 'ca-app-pub-3940256099942544/6300978111' // Android test fallback
            : 'ca-app-pub-3940256099942544/2934735716'); // iOS test fallback

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _bannerAdLoaded = true),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
        },
      ),
    )..load();
  }

  Future<void> _fetchGasPrices() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final ontarioData = await gasPriceService.fetchOntarioPrices();

      if (ontarioData.isEmpty) {
        setState(() {
          errorMessage = "No gas stations found in Ontario";
          isLoading = false;
        });
        return;
      }

      // Flatten all stations into a sorted list (cheapest first)
      final List<Map<String, dynamic>> flat = [];
      ontarioData.forEach((city, stations) {
        for (var station in stations) {
          flat.add({
            'city': city,
            'name': station['name'],
            'price': (station['price'] as num).toDouble(),
          });
        }
      });
      flat.sort((a, b) => (a['price'] as double).compareTo(b['price'] as double));

      final cheapestStation = flat.isNotEmpty ? flat.first : null;
      final expensiveStation = flat.isNotEmpty ? flat.last : null;

      // Build map markers (green = cheapest, red = most expensive)
      final Set<Marker> markers = {};
      for (int i = 0; i < flat.length; i++) {
        final s = flat[i];
        final coords = _cityCoords(s['city'] as String);
        final isCheapest = i == 0;
        final isExpensive = i == flat.length - 1;

        final hue = isCheapest
            ? BitmapDescriptor.hueGreen
            : isExpensive
                ? BitmapDescriptor.hueRed
                : BitmapDescriptor.hueOrange;

        markers.add(
          Marker(
            markerId: MarkerId('station_$i'),
            position: coords,
            icon: BitmapDescriptor.defaultMarkerWithHue(hue),
            infoWindow: InfoWindow(
              title: s['name'] as String,
              snippet: '${(s['price'] as double).toStringAsFixed(1)}¢/L • ${s['city']}',
            ),
          ),
        );
      }

      setState(() {
        allStations = flat;
        _mapMarkers = markers;
        stationAPrice = expensiveStation?['price'] ?? 150.0;
        stationBPrice = cheapestStation?['price'] ?? 140.0;
        stationAName = expensiveStation?['name'] ?? "Station A";
        stationBName = cheapestStation?['name'] ?? "Station B";
        isLoading = false;
      });

      // Fly camera to cheapest station if map is ready
      if (cheapestStation != null && _mapController != null) {
        final coords = _cityCoords(cheapestStation['city'] as String);
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(coords, 11),
        );
      }
    } catch (e) {
      setState(() {
        errorMessage = "Failed to fetch gas prices: $e";
        isLoading = false;
      });
    }
  }

  /// Approximate coordinates for common Ontario cities
  LatLng _cityCoords(String city) {
    const Map<String, LatLng> knownCities = {
      'Toronto': LatLng(43.6532, -79.3832),
      'Ottawa': LatLng(45.4215, -75.6972),
      'Mississauga': LatLng(43.5890, -79.6441),
      'Brampton': LatLng(43.6831, -79.7663),
      'Hamilton': LatLng(43.2557, -79.8711),
      'London': LatLng(42.9849, -81.2453),
      'Markham': LatLng(43.8561, -79.3370),
      'Vaughan': LatLng(43.8361, -79.4983),
      'Kitchener': LatLng(43.4516, -80.4925),
      'Windsor': LatLng(42.3149, -83.0364),
    };
    final cityLower = city.toLowerCase();
    for (final entry in knownCities.entries) {
      if (cityLower.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return const LatLng(43.6532, -79.3832); // Default: Toronto
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold is always rendered; loading/error shown inside body
    return Scaffold(
      appBar: AppBar(
        title: const Text("FuelLink: Ontario Savings"),
        actions: [
          // Price history
          IconButton(
            icon: const Icon(Icons.show_chart),
            tooltip: "Price History",
            onPressed: () => Navigator.pushNamed(context, '/history'),
          ),
          // Refresh
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh prices",
            onPressed: isLoading ? null : _fetchGasPrices,
          ),
          // Settings
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: "Settings & Preferences",
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Map + savings card occupies most of the screen
          Expanded(
            child: Stack(
              children: [
                // 1. GOOGLE MAP with station markers
                GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(43.6532, -79.3832),
                    zoom: 9,
                  ),
                  markers: _mapMarkers,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: true,
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                ),

                // 2. LOADING OVERLAY
                if (isLoading)
                  Container(
                    color: Colors.white.withAlpha(200),
                    child: const Center(child: CircularProgressIndicator()),
                  ),

                // 3. ERROR OVERLAY
                if (errorMessage != null && !isLoading)
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red[300]!),
                      ),
                      child: Column(
                        children: [
                          Text(errorMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.red[700])),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _fetchGasPrices,
                            icon: const Icon(Icons.refresh),
                            label: const Text("Retry"),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 4. SAVINGS CARD (only when data is loaded)
                if (!isLoading && errorMessage == null)
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: _buildSavingsCard(),
                  ),

                // 5. "View all stations" FAB to open bottom sheet
                if (!isLoading && errorMessage == null && allStations.isNotEmpty)
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: FloatingActionButton.extended(
                      heroTag: 'stationList',
                      onPressed: _showStationsBottomSheet,
                      icon: const Icon(Icons.list),
                      label: Text('${allStations.length} stations'),
                      backgroundColor: Colors.green,
                    ),
                  ),
              ],
            ),
          ),

          // 6. ADMOB BANNER
          if (_bannerAdLoaded && _bannerAd != null)
            SizedBox(
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
    );
  }

  /// Savings card with comparison, McTeague tip, vehicle presets and tank slider
  Widget _buildSavingsCard() {
    final dollarSavings = gasPriceService.calculateSavings(
      stationAPrice!,
      stationBPrice!,
      tankSize: tankSize,
    );
    final cheaperStation =
        stationAPrice! < stationBPrice! ? stationAName : stationBName;
    final displaySavings = dollarSavings.toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

          const SizedBox(height: 12),

          // Price comparison row
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
                    Text(stationAName,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500)),
                    Text("${stationAPrice?.toStringAsFixed(1)}¢",
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red)),
                  ],
                ),
                const Icon(Icons.arrow_forward, color: Colors.green),
                Column(
                  children: [
                    Text(stationBName,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500)),
                    Text("${stationBPrice?.toStringAsFixed(1)}¢",
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // McTeague smart tip
          ..._buildSmartTipWidget(
            avgPrice: (stationAPrice! + stationBPrice!) / 2,
          ),

          const SizedBox(height: 12),

          // Vehicle presets
          const Text("Vehicle Type:",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
                _buildPresetButton("⚙️ Custom", null),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Tank size slider
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
                  onChanged: (v) => setState(() => tankSize = v),
                ),
              ),
              Text("${tankSize.toStringAsFixed(0)}L",
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  /// Bottom sheet listing all stations sorted cheapest first
  void _showStationsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollCtrl) {
            return Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.local_gas_station,
                          color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "Ontario Gas Stations (${allStations.length})",
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      const Text("Cheapest first",
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Builder(
                    builder: (ctx2) {
                      // Pre-calculate savings for all stations once
                      final List<double> savingsList = allStations.map((s) {
                        return gasPriceService.calculateSavings(
                          stationAPrice!,
                          s['price'] as double,
                          tankSize: tankSize,
                        );
                      }).toList();
                      return ListView.builder(
                        controller: scrollCtrl,
                        itemCount: allStations.length,
                        itemBuilder: (_, i) {
                          final s = allStations[i];
                          final price = s['price'] as double;
                          final savings = savingsList[i];
                          final isCheapest = i == 0;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  isCheapest ? Colors.green : Colors.orange[100],
                              child: Text(
                                "${i + 1}",
                                style: TextStyle(
                                  color: isCheapest
                                      ? Colors.white
                                      : Colors.orange[800],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            title: Text(
                              s['name'] as String,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(s['city'] as String,
                                style: const TextStyle(fontSize: 12)),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "${price.toStringAsFixed(1)}¢/L",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isCheapest
                                        ? Colors.green
                                        : Colors.black87,
                                  ),
                                ),
                                if (savings > 0)
                                  Text(
                                    "Save \$${savings.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.green),
                                  ),
                              ],
                            ),
                            onTap: () {
                              Navigator.pop(ctx);
                              final coords = _cityCoords(s['city'] as String);
                              _mapController?.animateCamera(
                                CameraUpdate.newLatLngZoom(coords, 13),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
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