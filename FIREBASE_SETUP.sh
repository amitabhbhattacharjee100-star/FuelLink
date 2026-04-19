#!/bin/bash
# Firebase Setup & Daily Email Implementation Guide for FuelLink
# Purpose: Configure Firebase backend for daily gas price reports
# Last Updated: April 13, 2026

# ============================================================================
# PART 1: Firebase Project Setup
# ============================================================================

# 1. Create Firebase Project
# Go to: https://console.firebase.google.com
# Create new project: "fuellink-ontario"
# Enable Google Analytics (optional, for tracking)

# 2. Set up Authentication
# Console > Authentication > Sign-in method > Google
# Enable Google Sign-In
# Add authorized domains (your app domain if web)

# 3. Run FlutterFire CLI to generate firebase_options.dart
firebase install -g  # Install Firebase CLI if needed
flutterfire configure --project=fuellink-ontario

# ============================================================================
# PART 2: Firestore Database Setup
# ============================================================================

# Create Firestore Database in Firebase Console:
# - Start in production mode
# - Region: us-east1 (closest to Ontario for latency)

# FIRESTORE SECURITY RULES (Copy to Firestore > Rules):
# ============================================
# rules_version = '2';
# service cloud.firestore {
#   match /databases/{database}/documents {
#     // Users collection
#     match /users/{userId} {
#       allow read, write: if request.auth.uid == userId;
#       allow list: if request.auth != null;
#     }
#     
#     // Daily emails log (for analytics)
#     match /emailLogs/{logId} {
#       allow read: if request.auth != null;
#       allow write: if false; // Only Cloud Function can write
#     }
#     
#     // Gas price snapshots (for history)
#     match /priceHistory/{historyId} {
#       allow read: if request.auth != null;
#       allow write: if false; // Only Cloud Function can write
#     }
#   }
# }

# ============================================================================
# PART 3: Firestore Collections & Indexes
# ============================================================================

# USER COLLECTION SCHEMA
# Collection: users
# Fields:
#   - email (string): "user@gmail.com"
#   - displayName (string): "John Doe"
#   - photoUrl (string): "https://..."
#   - createdAt (timestamp): FieldValue.serverTimestamp()
#   - isSubscribed (boolean): true
#   - lastEmailSent (timestamp): null initially
#   - province (string): "ON" (Ontario)
#   - preferredVehicleSize (number): 65 (liters)
#   - unsubscribeTime (timestamp): null until unsubscribed
#   - lastToggleTime (timestamp): When subscription was toggled

# Create composite index for emails:
# Console > Firestore > Indexes
# Collection: users
# Fields: "isSubscribed" (Ascending), "lastEmailSent" (Ascending)
# This powers the daily email query efficiently

# ============================================================================
# PART 4: Firebase Cloud Functions (Node.js/TypeScript)
# ============================================================================

# 1. Create functions directory:
cd functions
npm init -y
npm install firebase-functions firebase-admin dotenv axios

# 2. Create functions/src/index.ts file:

cat > functions/src/index.ts << 'EOF'
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import axios from "axios";
import * as nodemailer from "nodemailer";

admin.initializeApp();

const db = admin.firestore();

// Configure Sendgrid or Mailgun for email sending
// Option A: Sendgrid
const sgMail = require("@sendgrid/mail");
sgMail.setApiKey(process.env.SENDGRID_API_KEY);

// Option B: Mailgun (alternative)
// import mailgun from "mailgun.js";
// const mg = mailgun.client({username: "api", key: process.env.MAILGUN_KEY});

/**
 * DAILY EMAIL TRIGGER: Runs every morning at 7:00 AM EST
 * - Fetches latest Ontario gas prices
 * - Sends email to subscribed users
 * - Logs email sends for analytics
 */
export const sendDailyGasPriceReport = functions
  .region("northamerica-northeast1") // Toronto region for latency
  .pubsub.schedule("0 7 * * *") // 7:00 AM daily (UTC-5)
  .timeZone("America/Toronto") // EST timezone
  .onRun(async (context) => {
    console.log("[DailyEmail] Starting daily gas price report send...");

    try {
      // 1. Fetch current Ontario gas prices
      const priceResponse = await axios.get(
        "https://gas-price.p.rapidapi.com/canada",
        {
          headers: {
            "x-rapidapi-host": "gas-price.p.rapidapi.com",
            "x-rapidapi-key": process.env.GAS_PRICE_API_KEY,
          },
        }
      );

      const ontarioPrices = priceResponse.data.result;
      const averagePrice = calculateAveragePrice(ontarioPrices);
      const cheapestStation = findCheapestStation(ontarioPrices);

      // 2. Save price snapshot
      const priceSnapshot = {
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        averagePrice: averagePrice,
        cheapestStation: cheapestStation,
        totalStations: ontarioPrices.length,
      };

      await db.collection("priceHistory").add(priceSnapshot);

      // 3. Get all subscribed users
      const subscribedUsers = await db
        .collection("users")
        .where("isSubscribed", "==", true)
        .get();

      console.log(
        `[DailyEmail] Found ${subscribedUsers.size} subscribed users`
      );

      // 4. Send emails
      const emailPromises: Promise<any>[] = [];

      subscribedUsers.forEach((userDoc) => {
        const userData = userDoc.data();
        const email = userData.email;

        const emailPromise = sendDailyReportEmail(
          email,
          userData,
          cheapestStation,
          averagePrice
        );

        emailPromises.push(emailPromise);
      });

      // Wait for all emails
      const results = await Promise.allSettled(emailPromises);
      const successCount = results.filter((r) => r.status === "fulfilled").length;
      const failureCount = results.filter((r) => r.status === "rejected").length;

      console.log(
        `[DailyEmail] Sent ${successCount} emails, ${failureCount} failures`
      );

      // 5. Log summary
      await db.collection("emailLogs").add({
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        totalSubscribed: subscribedUsers.size,
        emailsSent: successCount,
        emailsFailed: failureCount,
        averagePrice: averagePrice,
      });

      return {
        status: "success",
        emailsSent: successCount,
        timestamp: new Date().toISOString(),
      };
    } catch (error) {
      console.error("[DailyEmail] Error:", error);
      return { status: "error", error: error };
    }
  });

/**
 * Send individual daily report email
 * Psychology: High-value email that keeps users engaged
 */
async function sendDailyReportEmail(
  userEmail: string,
  userData: any,
  cheapestStation: any,
  averagePrice: number
): Promise<void> {
  const tankSize = userData.preferredVehicleSize || 65;
  const savingsEstimate = ((averagePrice - cheapestStation.price) * tankSize) / 100;

  // Calculate estimated savings if waiting until 6 PM
  const volatilityMultiplier = averagePrice > 180 ? 8.5 : 6;
  const waitingSavings = (volatilityMultiplier * tankSize) / 100;

  const emailContent = {
    to: userEmail,
    from: "noreply@fuellink.app",
    subject: `🚗 FuelLink: Save $${savingsEstimate.toFixed(2)} on gas today!`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h1>⛽ FuelLink Ontario Daily Report</h1>
        
        <div style="background: #f0f8f0; padding: 20px; border-radius: 8px; margin: 20px 0;">
          <h2>💰 Today's Top Savings</h2>
          <p><strong>${cheapestStation.name}</strong> in ${cheapestStation.city}</p>
          <p style="font-size: 24px; color: green;">💵 ${cheapestStation.price}¢/L</p>
          <p>Save <strong>$${savingsEstimate.toFixed(2)}</strong> on a full tank (${tankSize}L)</p>
        </div>
        
        <div style="background: #fff3cd; padding: 20px; border-radius: 8px; margin: 20px 0;">
          <h3>⏰ McTeague Prediction</h3>
          <p>Wait until 6:00 PM? Prices typically drop 6-8.5¢/L.</p>
          <p>Potential savings: <strong>$${waitingSavings.toFixed(2)}</strong> more</p>
        </div>
        
        <div style="background: #e3f2fd; padding: 20px; border-radius: 8px; margin: 20px 0;">
          <h3>📊 Market Snapshot</h3>
          <p>Average Ontario price: <strong>${averagePrice.toFixed(1)}¢/L</strong></p>
          <p>Range: ${Math.min(...[cheapestStation.price]).toFixed(1)}¢ - ${Math.max(...[cheapestStation.price]).toFixed(1)}¢</p>
        </div>
        
        <div style="text-align: center; margin: 30px 0;">
          <a href="https://fuellink.app" style="background: green; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; display: inline-block;">
            📱 Open FuelLink App
          </a>
        </div>
        
        <div style="text-align: center; margin-top: 40px; font-size: 12px; color: #999;">
          <p>
            <a href="https://fuellink.app/unsubscribe?email=${encodeURIComponent(userEmail)}" style="color: #999; text-decoration: none;">
              Unsubscribe from daily emails
            </a>
          </p>
          <p>© 2026 FuelLink Ontario | Helping Ontarians save on gas</p>
        </div>
      </div>
    `,
  };

  await sgMail.send(emailContent);
  console.log(`[Email] Sent to: ${userEmail}`);
}

function calculateAveragePrice(stations: any[]): number {
  if (stations.length === 0) return 0;
  const sum = stations.reduce((acc, station) => acc + station.gasoline, 0);
  return sum / stations.length;
}

function findCheapestStation(stations: any[]): any {
  return stations.reduce((cheapest, current) =>
    current.gasoline < cheapest.gasoline ? current : cheapest
  );
}

/**
 * UNSUBSCRIBE HANDLER: HTTP-triggered function
 * URL: https://us-central1-fuellink-ontario.cloudfunctions.net/unsubscribeUser
 * Usage: https://fuellink.app/unsubscribe?email=user@gmail.com
 */
export const unsubscribeUser = functions
  .https.onRequest(async (request, response) => {
    const email = request.query.email as string;

    if (!email) {
      response.status(400).send("Email required");
      return;
    }

    try {
      const userDocs = await db
        .collection("users")
        .where("email", "==", email)
        .limit(1)
        .get();

      if (userDocs.empty) {
        response.status(404).send("User not found");
        return;
      }

      const docId = userDocs.docs[0].id;
      await db.collection("users").doc(docId).update({
        isSubscribed: false,
        unsubscribeTime: admin.firestore.FieldValue.serverTimestamp(),
      });

      response.send(
        "✅ You have been unsubscribed from FuelLink daily reports."
      );
    } catch (error) {
      console.error("[Unsubscribe] Error:", error);
      response.status(500).send("Error processing unsubscribe");
    }
  });

EOF

# 3. Create .env.local file with secrets:
cat > functions/.env.local << 'EOF'
GAS_PRICE_API_KEY=your_rapidapi_key_here
SENDGRID_API_KEY=your_sendgrid_key_here
EOF

# 4. Update functions/package.json:
npm install --save-dev typescript @types/node

# 5. Create tsconfig.json:
cat > functions/tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "module": "commonjs",
    "noImplicitAny": true,
    "outDir": "lib",
    "sourceMap": true,
    "target": "ES2020"
  },
  "compileOnSave": true,
  "include": ["src"]
}
EOF

# 6. Deploy Cloud Functions:
firebase deploy --only functions

# ============================================================================
# PART 5: Sendgrid Configuration
# ============================================================================

# 1. Sign up for Sendgrid: https://sendgrid.com
# 2. Create API key with Mail Send permission
# 3. Add to Firebase Environment:
firebase functions:config:set sendgrid.api_key="SG.xxxx"

# 4. Verify sender email (required for SMTP)
# Go to Sendgrid Dashboard > Settings > Sender Authentication

# ============================================================================
# PART 6: Android Setup (for google_sign_in)
# ============================================================================

# 1. Download google-services.json from Firebase Console:
# Console > Project Settings > Download google-services.json
# Move it to: android/app/google-services.json

# 2. Update android/build.gradle:
# buildscript {
#   dependencies {
#     classpath 'com.google.gms:google-services:4.3.15'
#   }
# }

# 3. Update android/app/build.gradle:
# apply plugin: 'com.google.gms.google-services'

# ============================================================================
# PART 7: iOS Setup (for google_sign_in)
# ============================================================================

# 1. Download GoogleService-Info.plist from Firebase Console
# Move it to: ios/Runner/GoogleService-Info.plist

# 2. In Xcode:
# - Select GoogleService-Info.plist
# - Check "Copy items if needed"
# - Select all targets

# 3. Update Info.plist with URL schemes from GoogleService-Info.plist

# ============================================================================
# PART 8: Testing the Setup
# ============================================================================

# 1. Test Google Sign-In locally:
flutter run

# 2. Sign in with a test account
# 3. Go to Settings > Toggle "Receive Daily Reports"
# 4. Check Firestore to verify user document created

# 5. Test Cloud Function locally:
firebase emulators:start

# 6. Trigger function locally:
curl -X POST http://localhost:5001/fuellink-ontario/northamerica-northeast1/sendDailyGasPriceReport

# ============================================================================
# PART 9: PRODUCTION MONITORING
# ============================================================================

# Monitor email sends:
firebase functions:log --follow

# Check Firestore usage:
# Console > Firestore > Usage tab

# Monitor failures:
# Console > Functions > Logs

print "[Setup] ✅ Firebase setup complete!"
print "[Setup] Next Steps:"
print "[Setup]   1. Run: flutterfire configure"
print "[Setup]   2. Install: npm install in functions/"
print "[Setup]   3. Deploy: firebase deploy"
print "[Setup]   4. Test Google Sign-In in app"
