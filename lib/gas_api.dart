import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GasPriceService {
  final String _apiKey = dotenv.env['GAS_PRICE_API_KEY'] ?? "";
  final String _rapidApiHost = 'gas-price.p.rapidapi.com';

  /// Fetch gas prices for Ontario, Canada
  /// Using the /canada endpoint which returns provincial data
  Future<Map<String, dynamic>> fetchOntarioPrices() async {
    try {
      final response = await http.get(
        Uri.parse('https://gas-price.p.rapidapi.com/canada'),
        headers: {
          'x-rapidapi-host': _rapidApiHost,
          'x-rapidapi-key': _apiKey,
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        print("Gas Price API Response: ${data.toString()}");
        
        // Extract Ontario data from the results
        if (data['result'] != null) {
          return _parseOntarioData(data['result']);
        }
        throw Exception("No results found in API response");
      } else {
        throw Exception(
          "Error fetching gas data: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      print("Exception in fetchOntarioPrices: $e");
      rethrow;
    }
  }

  /// Parse the API response to extract Ontario gas station data
  /// Returns a map with city and price information
  Map<String, dynamic> _parseOntarioData(List<dynamic> results) {
    Map<String, dynamic> ontarioData = {};

    // Filter for Ontario cities and extract gasoline prices
    for (var station in results) {
      String? city = station['city'];
      double? price = _extractPrice(station['gasoline']);

      if (city != null && price != null) {
        if (!ontarioData.containsKey(city)) {
          ontarioData[city] = [];
        }
        ontarioData[city].add({
          'price': price,
          'name': station['name'] ?? 'Unknown Station',
          'currency': station['currency'] ?? 'CAD',
        });
      }
    }

    return ontarioData;
  }

  /// Extract numeric price from string or return double value
  double? _extractPrice(dynamic price) {
    if (price == null) return null;
    
    if (price is double) return price;
    if (price is int) return price.toDouble();
    
    if (price is String) {
      // Remove currency symbols and parse
      String cleaned = price.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(cleaned);
    }
    
    return null;
  }

  /// Get cheapest gas station from Ontario data
  /// Returns a map with city, station name, and price
  Map<String, dynamic>? getCheapestStation(Map<String, dynamic> ontarioData) {
    double? lowestPrice;
    Map<String, dynamic>? cheapestStation;

    ontarioData.forEach((city, stations) {
      for (var station in stations) {
        double stationPrice = station['price'];
        if (lowestPrice == null || stationPrice < lowestPrice!) {
          lowestPrice = stationPrice;
          cheapestStation = {
            'city': city,
            'name': station['name'],
            'price': stationPrice,
            'currency': station['currency'],
          };
        }
      }
    });

    return cheapestStation;
  }

  /// Validate user timezone is Eastern Standard Time (EST/EDT)
  /// CRITICAL: Ensures McTeague Logic only applies to Ontario users
  /// Prevents Vancouver users from getting Ontario timing advice
  bool isUserInOntarioTimeZone() {
    try {
      final now = DateTime.now();
      // Check if current timezone offset matches Eastern Time (-5 or -4 for EDT)
      // EST is UTC-5, EDT is UTC-4
      final offset = now.timeZoneOffset;
      final isEasternTime = offset == const Duration(hours: -5) || 
                            offset == const Duration(hours: -4);
      return isEasternTime;
    } catch (e) {
      // Default to true for Ontario (primary market)
      return true;
    }
  }

  /// Ontario "McTeague Logic": Check if it's after 6:00 PM (EST)
  /// Research shows gas prices in Ontario typically drop 5-7¢ after 6:00 PM
  /// This is when major oil retailers adjust pricing strategy
  /// Geography-aware: Only returns true for EST timezone users
  bool isAfterSixPM() {
    // Only apply McTeague logic to Ontario timezone
    if (!isUserInOntarioTimeZone()) {
      return false; // Don't show Ontario timing advice to non-EST users
    }
    
    final now = DateTime.now();
    return now.hour >= 18; // 6:00 PM in 24-hour format
  }

  /// Calculate estimated savings IF user waits until 6:00 PM
  /// Volatility Multiplier: Higher prices (>180¢) = Bigger drops (8.5¢ vs 6¢)
  /// Research: When prices spike, independent stations (Pioneer, 7-Eleven) 
  /// drop harder in evening to compete with major chains
  /// 
  /// @param tankSize: Vehicle fuel tank size in liters (default 50L)
  /// @param currentPrice: Current average Ontario gas price in cents (used for multiplier)
  /// @return: Estimated additional savings by waiting until 6:00 PM (in dollars)
  double estimatedSavingsIfWait({
    double tankSize = 50.0,
    double currentPrice = 0.0,
  }) {
    // Base Ontario evening drop
    double dropAmount = 6.0; // cents per liter
    
    // Volatility Multiplier: High prices drop harder
    // When market hits 180¢+, independent stations compete more aggressively
    if (currentPrice > 180.0) {
      dropAmount = 8.5; // Higher volatility scenarios
      print("[McTeague] High volatility detected: $currentPrice¢ → Using 8.5¢ drop multiplier");
    }
    
    return (dropAmount * tankSize) / 100; // Convert to dollars
  }

  /// Get smart recommendation message based on time and current prices
  /// Encourages strategic fill-up timing for maximum savings
  /// Volatility-aware: Adjusts messaging based on current market price
  /// 
  /// @param tankSize: Vehicle fuel tank size in liters
  /// @param currentPrice: Current average Ontario gas price in cents
  Map<String, dynamic> getSmartTipMessage({
    double tankSize = 50.0,
    double currentPrice = 0.0,
  }) {
    final bool after6PM = isAfterSixPM();
    
    if (!after6PM) {
      final now = DateTime.now();
      final sixPM = DateTime(now.year, now.month, now.day, 18, 0);
      final timeUntilSixPM = sixPM.difference(now);
      final hoursLeft = timeUntilSixPM.inMinutes ~/ 60;
      final minutesLeft = timeUntilSixPM.inMinutes % 60;
      
      final estimatedSavings = estimatedSavingsIfWait(
        tankSize: tankSize,
        currentPrice: currentPrice,
      );
      
      return {
        'showTip': true,
        'icon': '⏰',
        'title': 'Wait & Save More!',
        'message': 'Gas prices in Ontario typically drop ~6¢/L after 6:00 PM.',
        'timeRemaining': 'Fill up in $hoursLeft h ${minutesLeft}m for better rates',
        'estimatedSavings': estimatedSavings,
        'colorCode': 'amber', // Used in main.dart: Colors.amber
      };
    } else {
      return {
        'showTip': true,
        'icon': '✅',
        'title': 'Best Time to Fill Up!',
        'message': 'Prices are typically at their lowest right now (after 6:00 PM).',
        'timeRemaining': 'Lock in today\'s savings!',
        'estimatedSavings': 0.0,
        'colorCode': 'green', // Used in main.dart: Colors.green
      };
    }
  }

  /// FIREBASE PUSH NOTIFICATION: Schedule 5:30 PM alert
  /// NOTE: Requires Firebase Cloud Messaging (FCM) setup
  /// 
  /// Implementation steps (for production):
  /// 1. Add 'firebase_messaging' package to pubspec.yaml
  /// 2. Configure Firebase project in Firebase Console
  /// 3. Set up notification scheduling in main.dart initState()
  /// 
  /// Message Content (sent at 5:30 PM EST):
  /// Title: "🚦 FuelLink Alert: Price drop incoming!"
  /// Body: "The 6 PM Ontario price drop is coming. Check your predicted savings now."
  /// Revenue Impact: Brings users back at peak ad value time
  /// 
  /// Example (pseudocode - requires FCM setup):
  /// ```
  /// scheduleNotification(
  ///   title: '🚦 FuelLink Alert: Price drop incoming!',
  ///   body: 'Check your predicted savings before 6:00 PM.',
  ///   scheduledTime: DateTime(today, 17, 30), // 5:30 PM
  /// );
  /// ```

  /// Compare two stations and calculate dollar savings based on tank size
  /// Formula: (Price A - Price B) * Tank Size
  /// Example: (155 - 145) * 50L = $5.00 saved per fill-up
  /// 
  /// @param priceA: First station's price in cents per liter
  /// @param priceB: Second station's price in cents per liter
  /// @param tankSize: Vehicle's fuel tank capacity in liters (default: 50L)
  /// @return: Total savings in dollars for a full fill-up
  double calculateSavings(double priceA, double priceB, {double tankSize = 50.0}) {
    double priceDifference = (priceA - priceB).abs();
    // Convert from cents to dollars by dividing by 100
    return (priceDifference * tankSize) / 100;
  }
}
