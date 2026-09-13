# FuelLink Environment Configuration Guide

## Overview

FuelLink uses environment variables to manage sensitive API keys and configuration across Flutter app and Cloud Functions. This document explains:

1. **Where to get each key**
2. **How to configure them locally**
3. **How to deploy them to Firebase**
4. **Security best practices**

---

## Environment Variables Reference

| Variable | Service | Used By | Required | Example |
|----------|---------|---------|----------|---------|
| `GOOGLE_MAPS_API_KEY` | Google Cloud | Flutter app | ✅ | `AIzaSyD...` |
| `GAS_PRICE_API_KEY` | RapidAPI | Flutter + Cloud Functions | ✅ | `xxxxxx.xxxxx...` |
| `ADMOB_APP_ID` | Google AdMob | Flutter app | ✅ | `ca-app-pub-xxxxxxxx` |
| `ADMOB_BANNER_ANDROID` | Google AdMob | Flutter app (banner ad) | ✅ | `ca-app-pub-XXXXXXXX/XXXXXXXX` |
| `ADMOB_BANNER_IOS` | Google AdMob | Flutter app (banner ad) | ✅ | `ca-app-pub-XXXXXXXX/XXXXXXXX` |
| `SENDGRID_API_KEY` | SendGrid | Cloud Functions | ✅ | `SG.xxxxx...` |
| `SENDGRID_FROM_EMAIL` | SendGrid | Cloud Functions | ✅ | `daily@fuellink.app` |

---

## Part 1: Getting API Keys

### 1.1 Google Maps API Key

**Platform:** Google Cloud Console  
**Purpose:** Display gas station map in Flutter app

**Steps:**
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create new project: "fuellink-ontario"
3. APIs & Services > Library > Search "Maps"
4. Click "Maps SDK for Flutter"
5. Click "Enable"
6. Go to "Credentials" > "Create Credentials" > "API Key"
7. Restrict to "Android apps" and "iOS apps"
8. Copy the key

**Android Restriction:**
- Package name: `com.example.fuellink`
- SHA-1 fingerprint: [See Android Setup section]

**iOS Restriction:**
- Bundle IDs: `com.example.fuellink`

**Cost:** Free (~$7 per 1,000 map loads)

---

### 1.2 RapidAPI Gas Price Key

**Platform:** RapidAPI  
**Purpose:** Fetch real-time Ontario gas prices

**Steps:**
1. Go to [RapidAPI](https://rapidapi.com)
2. Sign up for free account
3. Search "gas price"
4. Select "Gas Price API" by DeveloperAmoebas
5. Click "Subscribe to Test"
6. Plan: Free (5,000 requests/month)
7. Copy "X-RapidAPI-Key" from dashboard

**Dashboard Location:**
- Home > My Subscriptions > Gas Price API
- Right side: "X-RapidAPI-Key: xxxxxx..."

**Cost:** Free tier (100 requests/day), paid tier ($9.99/month for 500,000 requests)

---

### 1.3 AdMob App ID

**Platform:** Google AdMob  
**Purpose:** In-app advertisements (revenue stream)

**Steps:**
1. Go to [Google AdMob](https://admob.google.com)
2. Sign in with Google account
3. Click "Get started"
4. Select "I'm an app publisher"
5. App name: "FuelLink"
6. iOS: Add apps > Apple App ID (future)
7. Android: Add apps > Package name: `com.example.fuellink`
8. Accept agreements
9. Copy "App ID" (format: `ca-app-pub-xxxxxxxxxxxxxxxx`)

**Time to Approval:** ~24 hours

**Cost:** Free (you earn revenue from ads)

---

### 1.4 SendGrid API Key

**Platform:** SendGrid  
**Purpose:** Send daily email reports

**Steps:**
1. Go to [SendGrid](https://sendgrid.com)
2. Sign up for free account (100 emails/day)
3. Navigate to: Settings > API Keys
4. Click "Create API Key"
5. Name: "fuellink-daily-emails"
6. Permissions: Select only "Mail Send"
7. Generate
8. **Copy immediately** (cannot retrieve later)

**Sender Verification:**
- Settings > Sender Authentication > Verify a Single Sender
- Email: `daily@fuellink.app`
- Complete verification (click link in email)

**Cost:** Free tier (100 emails/day), paid ($19.95/month for unlimited)

---

## Part 2: Local Development Setup

### 2.1 Flutter App (.env file)

**Location:** `lib/.env` (create if doesn't exist)

**Content:**
```bash
# Google Cloud
GOOGLE_MAPS_API_KEY=AIzaSyD1234567890abcdefghijklmnopqrst

# RapidAPI
GAS_PRICE_API_KEY=xxxxxxx.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Google AdMob
ADMOB_APP_ID=ca-app-pub-xxxxxxxxxxxxxxxx~xxxxxxxxxx
ADMOB_BANNER_ANDROID=ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx
ADMOB_BANNER_IOS=ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx
```

**Usage in Dart:**
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

final googleMapsKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
final rapidapiKey = dotenv.env['GAS_PRICE_API_KEY'];
final admobId = dotenv.env['ADMOB_APP_ID'];
```

### 2.2 Cloud Functions (.env.local)

**Location:** `functions/.env.local` (create if doesn't exist)

**Content:**
```bash
# RapidAPI
GAS_PRICE_API_KEY=xxxxxxx.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# SendGrid
SENDGRID_API_KEY=SG.1234567890abcdefghijklmnopqrstuvwxyz1234567890
SENDGRID_FROM_EMAIL=daily@fuellink.app
```

**Usage in TypeScript:**
```typescript
const apiKey = process.env.sendgrid_key;
const rapidapiKey = process.env.rapidapi_key;
```

### 2.3 Git Ignore Secrets

**`.gitignore` (ADD these lines):**
```bash
# Environment files
.env
.env.local
.env.*.local
lib/.env
functions/.env.local

# Firebase
functions/service-account.json

# Keys
*_private.key
*.key
```

**Verify:**
```bash
git status  # Should NOT show .env files
```

---

## Part 3: Deploy to Firebase

### 3.1 Set Environment Variables

**Cloud Functions configuration:**
```bash
firebase functions:config:set \
  rapidapi.key="YOUR_RAPIDAPI_KEY" \
  sendgrid.key="SG.YOUR_SENDGRID_KEY" \
  sendgrid.from="daily@fuellink.app"
```

**Verify:**
```bash
firebase functions:config:get

# Output:
# {
#   "rapidapi": {
#     "key": "YOUR_KEY"
#   },
#   "sendgrid": {
#     "key": "SG.YOUR_KEY",
#     "from": "daily@fuellink.app"
#   }
# }
```

### 3.2 Access in Cloud Functions

**TypeScript (functions/src/index.ts):**
```typescript
// Declared at top of file
const rapidApiKey = process.env.rapidapi_key;
const sendgridKey = process.env.sendgrid_key;
const sendgridFrom = process.env.sendgrid_from;

// Usage
export const sendDailyGasPriceReport = functions.pubsub
  .schedule("0 7 * * *")
  .onRun(async () => {
    const response = await axios.get(
      "https://gas-price.p.rapidapi.com/canada",
      {
        headers: {
          "x-rapidapi-key": rapidApiKey,  // ✅ Used here
        }
      }
    );
```

### 3.3 Deploy Functions

```bash
firebase deploy --only functions

# Output should show:
# ✓ sendDailyGasPriceReport
# ✓ unsubscribeUser
# ✓ predictPriceDrop
```

---

## Part 4: Android & iOS Setup

### 4.1 Android Configuration

**`android/app/build.gradle`:**
```gradle
android {
    defaultConfig {
        applicationId "com.example.fuellink"
        minSdkVersion 21
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"
        
        // Google Maps API key for Android
        manifestPlaceholders = [
            googleMapsApiKey: "YOUR_GOOGLE_MAPS_KEY"
        ]
    }
}
```

**`android/app/src/main/AndroidManifest.xml`:**
```xml
<application>
    <meta-data
        android:name="com.google.android.geo.API_KEY"
        android:value="${googleMapsApiKey}" />
</application>
```

**`android/app/google-services.json`:**
- Download from Firebase Console
- Place in `android/app/` directory
- Auto-configured by flutterfire CLI

### 4.2 iOS Configuration

**`ios/Runner/Info.plist` (add):**
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>FuelLink needs your location to find nearby gas stations</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>FuelLink needs your location to find nearby gas stations</string>
<key>GMSPlacesAPIKey</key>
<string>YOUR_GOOGLE_MAPS_KEY</string>
```

**`ios/Runner/GoogleService-Info.plist`:**
- Download from Firebase Console
- Place in `ios/Runner/` directory
- Add to Xcode: Build Phases > Copy Bundle Resources

---

## Part 5: Security Best Practices

### ✅ Do's

- ✅ Generate separate API keys for different environments (dev, staging, prod)
- ✅ Rotate keys annually or after suspected breach
- ✅ Use Firebase environment variables (never hardcode secrets)
- ✅ Restrict API keys by domain/package/IP
- ✅ Monitor API usage for unusual activity
- ✅ Use HTTPS for all API calls
- ✅ Delete keys when no longer needed

### ❌ Don'ts

- ❌ Never commit `.env` files to Git
- ❌ Never share API keys in Slack, email, or chat
- ❌ Never use production keys in local development
- ❌ Never expose keys in error messages or logs
- ❌ Never grant unnecessary permissions to API keys
- ❌ Never use same key across multiple apps

---

## Part 6: Troubleshooting

### Problem: "API Key not found" error

**Solution:**
```bash
# 1. Verify .env file exists
ls -la lib/.env

# 2. Verify flutter_dotenv is imported
import 'package:flutter_dotenv/flutter_dotenv.dart';

# 3. Add to pubspec.yaml
flutter_dotenv: ^5.1.0

# 4. Add to main.dart before runApp()
await dotenv.load();
```

### Problem: RapidAPI "401 Unauthorized"

**Solution:**
```bash
# 1. Check API key is correct
firebase functions:config:get

# 2. Verify header spelling (case-sensitive)
"x-rapidapi-key": apiKey  # lowercase!

# 3. Check subscription status
# RapidAPI Dashboard > My Subscriptions > Gas Price API
# Should show "Active"
```

### Problem: SendGrid "Authentication failed"

**Solution:**
```bash
# 1. Verify API key starts with "SG."
firebase functions:config:get | grep sendgrid

# 2. Verify sender email is verified
# SendGrid > Settings > Sender Authentication
# Email should have green checkmark

# 3. Check rate limit
# SendGrid Dashboard > Email Activity
# Look for bounce or spam events
```

### Problem: "Too many requests" from RapidAPI

**Solution:**
```bash
# Free tier limit: 100 requests/day
# Cloud Function runs daily = 1 request/day (well under limit)

# If hitting limit:
# 1. Check for duplicate Cloud Function exports
# 2. Check for test code making extra calls
# 3. Upgrade RapidAPI plan
```

---

## Part 7: Monitoring & Alerts

### Firebase Configuration Audit

```bash
# View all configured environment variables
firebase functions:config:get

# Should output:
# {
#   "rapidapi": { "key": "set" },
#   "sendgrid": { "key": "set", "from": "set" }
# }
```

### API Usage Monitoring

**RapidAPI:**
- Dashboard > API Usage > Gas Price API
- Graph shows requests per day
- Alert if approaching limit (100/day free tier)

**SendGrid:**
- Dashboard > Email Activity
- Monitor delivery rate, bounces, spam reports
- Alert if bounce rate > 5%

**Google Maps:**
- Cloud Console > APIs > Maps SDK
- Monitor per day requests
- Alert if exceeding free tier (~$7/1000)

---

## Part 8: Environment Promotion

### Development → Staging → Production

**Step 1: Development (Local)**
```bash
# lib/.env
GOOGLE_MAPS_API_KEY=dev-key-xxxxx
GAS_PRICE_API_KEY=dev-key-xxxxx
ADMOB_APP_ID=ca-app-pub-dev
```

**Step 2: Staging (Firebase Project: fuellink-staging)**
```bash
firebase use fuellink-staging
firebase functions:config:set ... (staging keys)
firebase deploy
```

**Step 3: Production (Firebase Project: fuellink-ontario)**
```bash
firebase use fuellink-ontario  # Default
firebase functions:config:set ... (production keys)
firebase deploy
```

**Switch Firebase Project:**
```bash
firebase use fuellink-ontario      # Production
firebase use fuellink-staging      # Staging
firebase projects:list             # View all
```

---

## Appendix: Key Retrieval Commands

```bash
# Get all Firebase configuration
firebase functions:config:get

# Get specific config
firebase functions:config:get rapidapi

# See Firebase project aliases
firebase projects:list

# View current project
firebase use
```

---

## Support

- **RapidAPI Support:** https://rapidapi.com/support
- **SendGrid Support:** https://support.sendgrid.com
- **Google Cloud Support:** https://cloud.google.com/support
- **Firebase Support:** https://firebase.google.com/support

---

**Last Updated:** April 13, 2026  
**Status:** ✅ Production Ready
