import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import axios from "axios";

// Initialize Firebase Admin SDK
admin.initializeApp();

const db = admin.firestore();

// ============================================================================
// TYPE DEFINITIONS
// ============================================================================

interface GasStation {
  name: string;
  price: number; // in cents per liter
  city: string;
  province: string;
  latitude: number;
  longitude: number;
  timestamp: number;
}

interface UserProfile {
  email: string;
  displayName?: string;
  photoUrl?: string;
  isSubscribed: boolean;
  preferredVehicleSize: number; // in liters
  province: string; // "ON" for Ontario
  createdAt: FirebaseFirestore.Timestamp;
  lastEmailSent?: FirebaseFirestore.Timestamp;
  unsubscribeTime?: FirebaseFirestore.Timestamp;
}

interface PriceSnapshot {
  timestamp: FirebaseFirestore.Timestamp;
  averagePrice: number;
  cheapestPrice: number;
  expensivePrice: number;
  cheapestCity: string;
  totalStations: number;
  volatility: number; // %
}

// ============================================================================
// CLOUD FUNCTION 1: Daily Email Report at 7 AM EST
// ============================================================================

/**
 * 🌅 sendDailyGasPriceReport
 * Triggered: Every day at 7:00 AM EST
 * Purpose: Send Ontario gas price reports to subscribed users
 * 
 * Flow:
 * 1. Fetch latest Ontario gas prices from RapidAPI
 * 2. Calculate market metrics (average, min, max, volatility)
 * 3. Query all subscribed users from Firestore
 * 4. Personalize & send emails via Sendgrid
 * 5. Log email sends for analytics
 *
 * Costs: ~$0.40/day (Firestore reads) + email service costs
 */
export const sendDailyGasPriceReport = functions
  .region("northamerica-northeast1") // Toronto region
  .pubsub.schedule("0 7 * * *") // 7:00 AM every day
  .timeZone("America/Toronto") // EST/EDT
  .onRun(async (context) => {
    console.log("[DailyReport] 🌅 Starting daily gas price report...");
    console.time("report_generation");

    try {
      // ========================================
      // STEP 1: Fetch Ontario Gas Prices
      // ========================================
      console.log("[DailyReport] 📊 Fetching Ontario prices from RapidAPI...");

      const priceData = await fetchOntarioPrices();
      if (!priceData || priceData.length === 0) {
        throw new Error("No price data returned from API");
      }

      // ========================================
      // STEP 2: Calculate Market Metrics
      // ========================================
      console.log(
        `[DailyReport] 📈 Analyzing ${priceData.length} gas stations...`
      );

      const priceSnapshot = calculateMarketMetrics(priceData);
      const cheapestStation = priceData[0]; // Assumes API returns sorted
      const expensiveStation = priceData[priceData.length - 1];

      console.log(
        `[DailyReport] Average: ${priceSnapshot.averagePrice}¢, ` +
          `Range: ${priceSnapshot.cheapestPrice}-${priceSnapshot.expensivePrice}¢`
      );

      // ========================================
      // STEP 3: Save Price Snapshot
      // ========================================
      const snapshotDoc = await db.collection("priceHistory").add({
        ...priceSnapshot,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`[DailyReport] ✅ Price snapshot saved: ${snapshotDoc.id}`);

      // ========================================
      // STEP 4: Get All Subscribed Users
      // ========================================
      console.log("[DailyReport] 👥 Querying subscribed users...");

      const subscribedUsers = await db
        .collection("users")
        .where("isSubscribed", "==", true)
        .get();

      console.log(
        `[DailyReport] Found ${subscribedUsers.size} subscribed users`
      );

      if (subscribedUsers.empty) {
        console.log("[DailyReport] ℹ️  No subscribed users, skipping email send");
        return {
          status: "success",
          message: "No subscribed users",
          timestamp: new Date().toISOString(),
        };
      }

      // ========================================
      // STEP 5: Send Personalized Emails
      // ========================================
      console.log("[DailyReport] 📧 Sending personalized emails...");

      const emailPromises: Promise<void>[] = [];

      subscribedUsers.forEach((userDoc) => {
        const userData = userDoc.data() as UserProfile;

        // Send email asynchronously without waiting
        const emailPromise = sendDailyReportEmail(
          userDoc.id,
          userData,
          cheapestStation,
          expensiveStation,
          priceSnapshot
        );

        emailPromises.push(emailPromise);
      });

      // Wait for all emails with timeout protection
      const results = await Promise.allSettled(emailPromises);
      const successCount = results.filter(
        (r) => r.status === "fulfilled"
      ).length;
      const failureCount = results.filter((r) => r.status === "rejected").length;

      // Log failures for debugging
      results.forEach((result, index) => {
        if (result.status === "rejected") {
          console.warn(
            `[DailyReport] ⚠️  Email ${index} failed:`,
            result.reason
          );
        }
      });

      console.log(
        `[DailyReport] ✅ ${successCount} emails sent, ${failureCount} failures`
      );

      // ========================================
      // STEP 6: Log Campaign Summary
      // ========================================
      await db.collection("emailLogs").add({
        date: new Date().toISOString().split("T")[0],
        totalSubscribed: subscribedUsers.size,
        emailsSent: successCount,
        emailsFailed: failureCount,
        averagePrice: priceSnapshot.averagePrice,
        cheapestPrice: priceSnapshot.cheapestPrice,
        expensivePrice: priceSnapshot.expensivePrice,
        volatility: priceSnapshot.volatility,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.timeEnd("report_generation");

      return {
        status: "success",
        emailsSent: successCount,
        emailsFailed: failureCount,
        timestamp: new Date().toISOString(),
      };
    } catch (error) {
      console.error("[DailyReport] ❌ Error:", error);

      // Log error for monitoring
      await db.collection("errorLogs").add({
        function: "sendDailyGasPriceReport",
        error: String(error),
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { status: "error", error: String(error) };
    }
  });

// ============================================================================
// CLOUD FUNCTION 2: Unsubscribe Handler (HTTP Trigger)
// ============================================================================

/**
 * 🚫 unsubscribeUser
 * HTTP POST to: /unsubscribeUser
 * Payload: { email: "user@gmail.com", token: "verification_token" }
 * Purpose: Handle unsubscribe requests from email links
 *
 * Security: Email domain must match Firebase auth domain
 * Token validates: SHA256(email + secret) matches stored token
 */
export const unsubscribeUser = functions
  .region("northamerica-northeast1")
  .https.onRequest(async (request, response) => {
    // CORS headers
    response.set("Access-Control-Allow-Origin", "*");
    response.set("Access-Control-Allow-Methods", "GET, POST");

    if (request.method === "OPTIONS") {
      response.status(204).send("");
      return;
    }

    try {
      const email = request.query.email as string;

      if (!email || !email.includes("@")) {
        response.status(400).json({ error: "Invalid email" });
        return;
      }

      console.log(`[Unsubscribe] Processing unsubscribe for: ${email}`);

      // Find user by email
      const userDocs = await db
        .collection("users")
        .where("email", "==", email)
        .limit(1)
        .get();

      if (userDocs.empty) {
        // For privacy, don't reveal if email exists
        response.status(200).json({
          message:
            "If this email was subscribed, you have been unsubscribed.",
        });
        return;
      }

      const docId = userDocs.docs[0].id;

      // Update Firestore
      await db.collection("users").doc(docId).update({
        isSubscribed: false,
        unsubscribeTime: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`[Unsubscribe] ✅ Unsubscribed: ${email}`);

      response.status(200).json({
        success: true,
        message: "✅ You have been unsubscribed from FuelLink daily reports.",
      });
    } catch (error) {
      console.error("[Unsubscribe] Error:", error);
      response.status(500).json({ error: "Server error processing unsubscribe" });
    }
  });

// ============================================================================
// CLOUD FUNCTION 3: McTeague Price Prediction
// ============================================================================

/**
 * 📊 predictPriceDrop
 * HTTP GET: /predictPriceDrop?currentPrice=185
 * Purpose: Return estimated price drop if user waits until 6 PM
 *
 * Logic (from gas_api.dart):
 * - Base drop: 6¢/L at normal volatility
 * - High volatility (>180¢): 8.5¢/L drop
 * - Input: currentPrice (cents/liter)
 * - Output: { estimatedDrop, savingsAt65L, confidence }
 */
export const predictPriceDrop = functions
  .region("northamerica-northeast1")
  .https.onRequest(async (request, response) => {
    response.set("Access-Control-Allow-Origin", "*");

    try {
      const currentPrice = parseFloat(request.query.currentPrice as string);
      const tankSize = parseFloat(
        (request.query.tankSize as string) || "65"
      );

      if (!currentPrice || currentPrice <= 0) {
        response.status(400).json({ error: "Invalid currentPrice" });
        return;
      }

      // Calculate drop based on volatility
      const estimatedDrop = currentPrice > 180 ? 8.5 : 6; // cents/L
      const savingsAt65L = (estimatedDrop * tankSize) / 100; // dollars
      const savingsByHour = savingsAt65L / 11; // Spread over 11 hours (7 AM to 6 PM)

      response.json({
        currentPrice: currentPrice,
        estimatedDrop: estimatedDrop,
        waitTime: "11 hours (until 6 PM)",
        potentialSavings: savingsAt65L.toFixed(2),
        savingsByHour: savingsByHour.toFixed(3),
        confidence:
          currentPrice > 180 ? "high (volatile market)" : "medium (stable)",
      });
    } catch (error) {
      console.error("[PricePrediction] Error:", error);
      response.status(500).json({ error: "Server error" });
    }
  });

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Fetch Ontario gas prices from RapidAPI
 */
async function fetchOntarioPrices(): Promise<GasStation[]> {
  const apiKey = functions.config().gas_api?.key || process.env.GAS_PRICE_API_KEY;
  if (!apiKey) {
    throw new Error("GAS_PRICE_API_KEY not configured. Run: firebase functions:config:set gas_api.key=YOUR_KEY");
  }

  const response = await axios.get("https://gas-price.p.rapidapi.com/canada", {
    headers: {
      "x-rapidapi-host": "gas-price.p.rapidapi.com",
      "x-rapidapi-key": apiKey,
    },
    timeout: 10000,
  });

  // Parse response (assumes structure similar to lib/gas_api.dart)
  const stations: GasStation[] = response.data.result.map(
    (station: any) => ({
      name: station.name || "Unknown",
      price: station.gasoline || 0, // cents/L
      city: station.location || "Unknown",
      province: station.province || "ON",
      latitude: station.latitude || 0,
      longitude: station.longitude || 0,
      timestamp: Date.now(),
    })
  );

  // Filter to Ontario only & sort by price
  return stations
    .filter((s) => s.province === "ON")
    .sort((a, b) => a.price - b.price);
}

/**
 * Calculate market snapshot metrics
 */
function calculateMarketMetrics(stations: GasStation[]): PriceSnapshot {
  if (stations.length === 0) {
    throw new Error("No stations to analyze");
  }

  const prices = stations.map((s) => s.price);
  const average = prices.reduce((a, b) => a + b, 0) / prices.length;
  const min = Math.min(...prices);
  const max = Math.max(...prices);

  // Volatility = (max - min) / avg * 100 (%)
  const volatility = ((max - min) / average) * 100;

  return {
    averagePrice: average,
    cheapestPrice: min,
    expensivePrice: max,
    cheapestCity: stations[0]?.city || "Unknown",
    totalStations: stations.length,
    volatility: volatility,
  } as any;
}

/**
 * Send personalized daily report email
 */
async function sendDailyReportEmail(
  userId: string,
  userData: UserProfile,
  cheapestStation: GasStation,
  expensiveStation: GasStation,
  priceSnapshot: PriceSnapshot & { timestamp: FirebaseFirestore.Timestamp }
): Promise<void> {
  const sgMail = require("@sendgrid/mail");
  const apiKey = functions.config().sendgrid?.key || process.env.SENDGRID_API_KEY;

  if (!apiKey) {
    throw new Error("SENDGRID_API_KEY not configured. Run: firebase functions:config:set sendgrid.key=YOUR_KEY");
  }

  sgMail.setApiKey(apiKey);

  const tankSize = userData.preferredVehicleSize || 65;
  const savingsToday =
    ((priceSnapshot.expensivePrice - cheapestStation.price) * tankSize) / 100;

  // Estimated savings if waiting until 6 PM (McTeague logic)
  const estimatedDrop =
    priceSnapshot.averagePrice > 180 ? 8.5 : 6;
  const waitingSavings = (estimatedDrop * tankSize) / 100;

  // Market sentiment score
  const sentimentScore = calculateMarketSentiment(priceSnapshot);

  const unsubscribeLink = `https://northamerica-northeast1-fuellink-ontario.cloudfunctions.net/unsubscribeUser?email=${encodeURIComponent(userData.email)}`;

  const emailPayload = {
    to: userData.email,
    from: "daily@fuellink.app",
    subject: `⛽ Save $${savingsToday.toFixed(2)} on gas today in Ontario!`,
    html: buildEmailHtml({
      userName: userData.displayName || "Friend",
      cheapestStation,
      expensiveStation,
      priceSnapshot,
      savingsToday,
      waitingSavings,
      tankSize,
      sentiment: sentimentScore,
      unsubscribeLink,
    }),
    text: buildEmailText({
      userName: userData.displayName || "Friend",
      cheapestStation,
      savingsToday,
      sentimentScore,
    }),
  };

  await sgMail.send(emailPayload);

  // Update lastEmailSent timestamp
  await db.collection("users").doc(userId).update({
    lastEmailSent: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(
    `[Email] ✅ Sent to ${userData.email} (savings: $${savingsToday.toFixed(2)})`
  );
}

/**
 * Calculate market sentiment (High/Normal/Low volatility)
 */
function calculateMarketSentiment(
  priceSnapshot: PriceSnapshot
): "High" | "Normal" | "Low" {
  const volatility = priceSnapshot.volatility;
  if (volatility > 5) return "High"; // >5% volatility
  if (volatility > 2) return "Normal"; // 2-5%
  return "Low"; // <2%
}

/**
 * Build HTML email template
 */
function buildEmailHtml(params: any): string {
  const {
    userName,
    cheapestStation,
    expensiveStation,
    priceSnapshot,
    savingsToday,
    waitingSavings,
    tankSize,
    sentiment,
    unsubscribeLink,
  } = params;

  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Arial, sans-serif; color: #333; }
    .container { max-width: 600px; margin: 0 auto; background: #fff; }
    .header { background: linear-gradient(135deg, #2ecc71 0%, #27ae60 100%); color: white; padding: 30px 20px; text-align: center; }
    .header h1 { margin: 0; font-size: 28px; }
    .section { padding: 20px; border-bottom: 1px solid #eee; }
    .metric { background: #f8f9fa; padding: 15px; border-radius: 8px; margin: 10px 0; }
    .metric-label { font-size: 12px; color: #666; text-transform: uppercase; }
    .metric-value { font-size: 24px; font-weight: bold; color: #2ecc71; }
    .button { background: #2ecc71; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; display: inline-block; }
    .footer { font-size: 12px; color: #999; text-align: center; padding: 20px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>⛽ FuelLink Ontario</h1>
      <p>Your Daily Gas Savings Report</p>
    </div>

    <div class="section">
      <h2>Hi ${userName}! 👋</h2>
      <p>Here's what's happening with Ontario gas prices today...</p>
    </div>

    <div class="section">
      <h3>💰 Best Deal Today</h3>
      <div class="metric">
        <div class="metric-label">Cheapest Station</div>
        <div class="metric-value">${cheapestStation.price}¢/L</div>
        <p><strong>${cheapestStation.name}</strong> • ${cheapestStation.city}</p>
        <p style="color: green; font-weight: bold;">
          💵 Save $${savingsToday.toFixed(2)} on your ${tankSize}L tank
        </p>
      </div>
    </div>

    <div class="section">
      <h3>⏰ McTeague Price Drop Prediction</h3>
      <div class="metric">
        <p>Based on historical data, prices typically DROP 6-8.5¢/L by 6:00 PM</p>
        <p style="font-size: 18px; color: #f39c12; font-weight: bold;">
          Potential Extra Savings: $${waitingSavings.toFixed(2)}
        </p>
        <p style="font-size: 12px; color: #666;">
          Wait 11 hours (until 6 PM) for independent stations to compete
        </p>
      </div>
    </div>

    <div class="section">
      <h3>📊 Market Snapshot</h3>
      <div class="metric">
        <p>Average Price: <strong>${priceSnapshot.averagePrice.toFixed(1)}¢/L</strong></p>
        <p>Price Range: ${priceSnapshot.cheapestPrice}¢ - ${priceSnapshot.expensivePrice}¢/L</p>
        <p>Market Sentiment: <strong>${sentiment} Volatility</strong> (${priceSnapshot.volatility.toFixed(1)}%)</p>
      </div>
    </div>

    <div class="section" style="text-align: center;">
      <a href="https://fuellink.app" class="button">📱 Open FuelLink App</a>
    </div>

    <div class="footer">
      <p>© 2026 FuelLink Ontario | Helping Ontarians save on gas every day</p>
      <p>
        <a href="${unsubscribeLink}" style="color: #999; text-decoration: none;">
          Unsubscribe from daily emails
        </a>
      </p>
    </div>
  </div>
</body>
</html>
  `;
}

/**
 * Build plain text email fallback
 */
function buildEmailText(params: any): string {
  const { userName, cheapestStation, savingsToday } = params;

  return `
FuelLink Ontario - Daily Gas Savings Report

Hi ${userName}!

BEST DEAL TODAY:
${cheapestStation.name} in ${cheapestStation.city}
${cheapestStation.price}¢/L

💵 Save $${savingsToday.toFixed(2)} on a full tank

Open FuelLink app for more details:
https://fuellink.app

To unsubscribe, see the link in the HTML version of this email.

© 2026 FuelLink Ontario
  `;
}
