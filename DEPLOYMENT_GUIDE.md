# FuelLink Firebase Deployment Guide
## Complete End-to-End Setup (April 2026)

---

## Overview

This guide walks through deploying FuelLink's backend infrastructure:
- **Daily Email System** (7 AM EST triggers)
- **User Authentication** (Google Sign-In + Firestore)
- **Cloud Functions** (Price fetching, email sending, analytics)
- **Firestore Database** (User profiles, price history, logs)

**Estimated Setup Time:** 30-45 minutes  
**Cost:** ~$0.40-1.00/day at 500 users (Firestore + email API costs)

---

## Part 1: Firebase Console Setup (10 minutes)

### 1.1 Create Firebase Project

```bash
# Option A: Via Firebase Console
1. Go to https://console.firebase.google.com
2. Click "Create Project"
3. Project name: "fuellink-ontario"
4. Enable Google Analytics (optional)
5. Create
```

### 1.2 Set Up Authentication

```bash
# Console Navigation: Project > Build > Authentication

1. Click "Sign-in method"
2. Click "Google"
3. Toggle "Enable" (blue)
4. Set Project name: "FuelLink Ontario"
5. Set Support email: your-email@gmail.com
6. Save
```

### 1.3 Create Firestore Database

```bash
# Console Navigation: Project > Build > Firestore Database

1. Click "Create Database"
2. Mode: "Start in production mode"
3. Location: "us-east1 (South Carolina)" - closest to Toronto
4. Create
```

**Why production mode?**
- Security rules prevent unauthorized writes
- We'll configure rules to allow Cloud Functions (Admin SDK)
- Client-side auth via Firebase Auth token

### 1.4 Download Service Account Key

```bash
# Console Navigation: Project Settings > Service Accounts

1. Click "Generate New Private Key"
2. Save as: functions/service-account.json
3. ⚠️ NEVER commit this file to Git (add to .gitignore)
```

---

## Part 2: Local Setup (5 minutes)

### 2.1 Install Firebase CLI

```bash
# macOS/Linux
curl -sL https://firebase.tools | bash

# Windows (via Chocolatey)
choco install firebase-tools

# Or download from: https://firebase.tools/
```

### 2.2 Authenticate Firebase CLI

```bash
firebase login

# Opens browser for authentication
# Select "Continue" with your Google account
# CLI now has permission to deploy
```

### 2.3 Initialize Firebase Project

```bash
cd /path/to/FuelLink

# Existing project - connect to Firebase
firebase use --add

# When prompted:
# - Select project: fuellink-ontario
# - Alias: default (press Enter)

# Verify
firebase projects:list
```

---

## Part 3: Configure Environment Variables (5 minutes)

### 3.1 Create RapidAPI Gas Price API Key

```bash
# 1. Go to https://rapidapi.com/DeveloperAmoebas/api/gas-price
# 2. Click "Subscribe to Test"
# 3. Plan: Free (or paid for higher limits)
# 4. Copy: API Key from dashboard (top right)
# 5. Save securely
```

### 3.2 Create SendGrid API Key

```bash
# 1. Sign up: https://sendgrid.com/ (free tier: 100 emails/day)
# 2. Go to: Settings > API Keys
# 3. Click "Create API Key"
# 4. Name: "fuellink-daily-emails"
# 5. Permissions: "Mail Send" only
# 6. Generate
# 7. Copy and save immediately (can't retrieve after)

# Verify sender email (required for all sends):
# Settings > Sender Authentication > Verify a Single Sender
# Email: daily@fuellink.app (or your domain)
```

### 3.3 Store Secrets in Firebase Environment

```bash
# Deploy env variables securely to Firebase
firebase functions:config:set \
  rapidapi.key="YOUR_RAPIDAPI_KEY" \
  sendgrid.key="SG.YOUR_SENDGRID_KEY" \
  sendgrid.from="daily@fuellink.app"

# Verify
firebase functions:config:get
```

---

## Part 4: Deploy Cloud Functions (10 minutes)

### 4.1 Install Dependencies

```bash
cd functions
npm install

# Verify build works
npm run build
# Should create lib/ folder with compiled .js files
```

### 4.2 Test Locally (Optional)

```bash
# Start emulator
npm run serve

# In another terminal, trigger the function
curl -X POST http://localhost:5001/fuellink-ontario/northamerica-northeast1/sendDailyGasPriceReport

# Should see console logs starting with [DailyReport]
# Check Firestore emulator for created documents
```

### 4.3 Deploy to Firebase

```bash
# From functions/ directory
npm run deploy

# Or from root
firebase deploy --only functions

# Expected output:
# ✓ sendDailyGasPriceReport (pubsub trigger - runs daily at 7 AM EST)
# ✓ unsubscribeUser (HTTP - ~100ms response)
# ✓ predictPriceDrop (HTTP - ~200ms response)
```

### 4.4 Verify Deployment

```bash
# View cloud function logs
firebase functions:log

# Or real-time
firebase functions:log --follow

# Check Firestore collections
# Console > Firestore > Collections
# Should be empty initially, will populate after first email send
```

---

## Part 5: Deploy Firestore Rules & Indexes (5 minutes)

### 5.1 Deploy Security Rules

```bash
# From root directory
firebase deploy --only firestore:rules

# Verification: Console > Firestore > Rules
# Should show the security rules from firestore.rules file
```

### 5.2 Create Composite Index

```bash
# For efficient email queries
# Console Navigation: Firestore > Indexes > Composite

# OR auto-create when function runs:
# - First email send triggers index creation
# - Firestore suggests composite index in console
# - Click "Create" when prompted

# Index details:
# Collection: users
# Fields:
#   1. isSubscribed (Ascending)
#   2. lastEmailSent (Ascending)
```

---

## Part 6: Configure Flutter App (5 minutes)

### 6.1 Run FlutterFire CLI

```bash
cd /path/to/FuelLink

flutterfire configure --project=fuellink-ontario

# Interactive prompts:
# - Platforms: android, ios, web (select all)
# - Creates: lib/firebase_options.dart with credentials
```

### 6.2 Verify Android Setup

```bash
# 1. Download google-services.json from Firebase Console
#    Project Settings > General > Download google-services.json
# 2. Copy to: android/app/google-services.json
# 3. Update android/build.gradle:

cat >> android/build.gradle << 'EOF'
buildscript {
  dependencies {
    classpath 'com.google.gms:google-services:4.3.15'
  }
}
EOF

# 4. Update android/app/build.gradle:
# apply plugin: 'com.google.gms.google-services'
```

### 6.3 Verify iOS Setup

```bash
# 1. Download GoogleService-Info.plist from Firebase Console
# 2. Copy to: ios/Runner/GoogleService-Info.plist
# 3. In Xcode:
#    - Select GoogleService-Info.plist
#    - Check "Copy items if needed"
#    - Select all targets
#    - Click "Create Folder References"
```

### 6.4 Test Flutter App

```bash
# Install dependencies
flutter pub get

# Run on emulator or device
flutter run

# Test flow:
# 1. See LoginScreen with Google Sign-In button
# 2. Click "Sign in with Google"
# 3. Select test account
# 4. Should create user doc in Firestore (users collection)
# 5. Go to Settings
# 6. Toggle "Receive Daily Reports" (should update `isSubscribed`)
# 7. Sign out and back in (verify auth state persistence)
```

---

## Part 7: Testing End-to-End (Optional but Recommended)

### 7.1 Trigger Daily Email Manually

```bash
# Force run the scheduled function (testing only)
firebase functions:call sendDailyGasPriceReport --data="{}"

# Or via curl (if HTTP trigger)
curl -X POST \
  https://northamerica-northeast1-fuellink-ontario.cloudfunctions.net/sendDailyGasPriceReport \
  -H "Content-Type: application/json"

# Check function logs
firebase functions:log

# Expected output:
# [DailyReport] 🌅 Starting daily gas price report...
# [DailyReport] 📊 Fetching Ontario prices from RapidAPI...
# [DailyReport] Found X subscribed users
# [Email] ✅ Sent to user@gmail.com
```

### 7.2 Verify Firestore Updates

```bash
# Console > Firestore > Collections
# Check collections created:
# 1. users/ - Your test user profile
# 2. priceHistory/ - Latest price snapshot
# 3. emailLogs/ - Summary of email send
```

### 7.3 Test Unsubscribe Link

```bash
# Click the unsubscribe link from an email
# Or manually call:
curl "https://northamerica-northeast1-fuellink-ontario.cloudfunctions.net/unsubscribeUser?email=test@gmail.com"

# Firestore result:
# users/{userId}.isSubscribed = false
# users/{userId}.unsubscribeTime = [timestamp]
```

---

## Part 8: Production Settings

### 8.1 Configure Cron Schedule

```bash
# Current schedule: 7:00 AM EST daily
# To change, edit functions/src/index.ts:
# .pubsub.schedule("0 7 * * *") // Cron format: minute hour day month dayOfWeek

# Cron examples:
# "0 7 * * *"   - 7:00 AM every day
# "0 7 * * 1-5" - 7:00 AM weekdays only
# "*/15 * * * *" - Every 15 minutes
```

### 8.2 Monitor & Alert Setup

```bash
# Console > Functions > Logs
# Set up alerts:
# 1. Click: "Create Alert Policy"
# 2. Condition: Function execution rate > X errors/minute
# 3. Notification: Email when triggered
```

### 8.3 Firestore Backup

```bash
# Enable automatic daily backups
# Console > Firestore > Backups
# 1. Click "Create Schedule"
# 2. Frequency: Daily
# 3. Retention: 30 days
```

---

## Troubleshooting

### Problem: "sendgrid.key is undefined"
**Solution:** Set config variables
```bash
firebase functions:config:set sendgrid.key="YOUR_KEY"
firebase deploy --only functions
```

### Problem: Emails not sending
**Solution:** Check sender email verification
- SendGrid console > Settings > Sender Authentication
- Verify the "from" email address (daily@fuellink.app)
- Re-send verification link if needed

### Problem: Cloud Function timeout
**Solution:** Increase timeout
```bash
# functions/src/index.ts
.https.onRequest({ timeoutSeconds: 60 }, async (req, res) => {...})
```

### Problem: Firestore quota exceeded
**Solution:** Upgrade billing plan
- Console > Firestore > Quotas
- Enable automatic scaling for production
- Set spending limit

---

## Monitoring & Analytics

### Key Metrics to Track

1. **Email Sends:**
   - Firestore > emailLogs collection
   - Query: Daily success rate

2. **Function Performance:**
   - Console > Functions > Metrics
   - Track: Execution time, memory usage, errors

3. **User Growth:**
   - Firestore > users collection
   - Filter: `isSubscribed == true`
   - Count: Active subscribers

### Sample Dashboard Query

```sql
-- (Pseudo-code for Firestore)
SELECT 
    DATE(timestamp) as date,
    COUNT(*) as emails_sent,
    AVG(CAST(averagePrice as FLOAT64)) as avg_price
FROM emailLogs
GROUP BY date
ORDER BY date DESC
LIMIT 30;
```

---

## Next Steps

1. **[✅ Completed]** Cloud Functions deployed
2. **[✅ Completed]** Firestore database live
3. **[→ Next]** Build YouTube Shorts automation (Step 13)
4. **[→ Next]** Create web unsubscribe page
5. **[→ Next]** Set up AdMob for in-app ads
6. **[→ Next]** Prepare app for Play Store / App Store

---

## Cost Estimate (500 active users)

| Service | Monthly Volume | Cost |
|---------|:--|:--|
| Firestore reads | ~15,000 | $0.06 |
| Firestore writes | ~1,500 | $0.06 |
| Cloud Functions | 30 invocations | $0.40 |
| SendGrid emails | 11,500 (8 free) | $0.10 |
| **TOTAL** | | **~$0.62/day** |

---

## Support

- **Firebase Docs:** https://firebase.google.com/docs
- **Cloud Functions:** https://cloud.google.com/functions/docs
- **Firestore:** https://firebase.google.com/docs/firestore
- **SendGrid:** https://sendgrid.com/docs
- **RapidAPI:** https://rapidapi.com/docs

---

**Last Updated:** April 13, 2026  
**Status:** Ready for production deployment
