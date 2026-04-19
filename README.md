# FuelLink Ontario 🚗⛽
## Real-Time Gas Price Comparison + Daily Smart Alerts

**Status:** Production-ready backend infrastructure (April 2026)  
**Target Market:** Ontario residents seeking gas savings  
**Revenue Model:** Daily emails + in-app ads + YouTube Shorts integration

---

## 📋 Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Core Features](#core-features)
4. [File Structure](#file-structure)
5. [Quick Start](#quick-start)
6. [API Documentation](#api-documentation)
7. [Deployment](#deployment)
8. [Monitoring & Analytics](#monitoring--analytics)
9. [Contributing](#contributing)

---

## 🎯 Project Overview

**FuelLink** combines real-time gas price data with predictive analytics to help Ontario residents find the cheapest gas and maximize savings. The app uses the "McTeague Logic" (6 PM price drop prediction) to increase user engagement through strategic timing alerts.

### Key Metrics

- **Target Users:** 500→5,000 within 6 months
- **Email Open Rate:** 4x higher with daily emails (documented psychology)
- **Avg Savings per User:** $3-7 per tank ($30-70/month)
- **Revenue Per User:** ~$0.40/day (AdMob + email list value)

---

## 🏗️ Architecture

### System Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    End Users (iOS/Android)              │
│                    Flutter App (FuelLink)               │
└────────────────────────┬────────────────────────────────┘
                         │ Firebase Auth
                         ▼
┌─────────────────────────────────────────────────────────┐
│                  Firebase Console                        │
├─────────────────────────────────────────────────────────┤
│ ✓ Authentication (Google Sign-In)                       │
│ ✓ Firestore Database (User profiles, subscriptions)     │
│ ✓ Cloud Functions (Daily email scheduler)               │
│ ✓ Cloud Storage (Optional: price history archives)      │
└────────┬────────────────────────┬──────────────────────┘
         │                        │
         ▼                        ▼
    RapidAPI                   SendGrid
    (Gas Prices)              (Email Delivery)
    - /canada endpoint        - 100 emails/day (free tier)
    - Ontario stations        - Custom templates
    - Real-time pricing       - Unsubscribe handling
```

### Data Flow

1. **User Signs In:**
   - Google Sign-In → Firebase Auth token
   - Auth creates Firestore user document
   - User profile stored with `isSubscribed: true`

2. **Daily Email Trigger (7 AM EST):**
   - Cloud Function scheduled pubsub trigger
   - Fetches latest Ontario gas prices from RapidAPI
   - Queries Firestore for all `isSubscribed: true` users
   - Personalizes email (vehicle size, province preferences)
   - Sends via SendGrid API
   - Logs email send in Firestore `emailLogs` collection

3. **User Interaction:**
   - Opens email with latest gas prices & McTeague prediction
   - Clicks "Open App" deep link
   - Returns to app for full gas price comparison
   - Clicks station to open Google Maps navigation

4. **Settings Management:**
   - User toggles email subscription in Settings screen
   - Firestore `isSubscribed` field updates in real-time
   - Next day's email send query excludes unsubscribed users

---

## ✨ Core Features

### 1️⃣ Real-Time Gas Price Comparison
- **API:** RapidAPI Gas Price API (`/canada` endpoint)
- **Data:** ~50+ Ontario gas stations
- **Refresh:** Real-time (updated within 1-2 hours)
- **Sorting:** Cheapest first, with savings calculation

**How to Use:**
```dart
// lib/gas_api.dart
final prices = await fetchOntarioPrices();
final cheapest = prices.first; // Sorted by price
final savings = calculateSavings(highest, cheapest, tankSize: 65);
```

### 2️⃣ McTeague Logic (6 PM Price Prediction)
- **Timing:** Independent stations typically drop prices 6-8.5¢/L by 6 PM
- **Volatility-Aware:** Higher volatility (>180¢) = larger drop (8.5¢ vs 6¢)
- **User Benefit:** "Wait until 6 PM to save an extra $X" messaging
- **Engagement:** Keeps users in app throughout the day

**How to Use:**
```dart
// Predicts 6-8.5¢/L drop depending on market volatility
final prediction = getSmartTipMessage(tankSize: 65, currentPrice: 185);
// Returns: { icon, title, message, estimatedSavings, color }
```

### 3️⃣ Personalized Daily Emails
- **Frequency:** 7:00 AM EST every morning
- **Content:** Top 3 cheapest stations + McTeague prediction
- **Personalization:** Vehicle size savings calculation
- **CTA:** "Open App" deep link for re-engagement

**Email Template Includes:**
- Cheapest station location & price
- Estimated savings on user's vehicle
- "Wait until 6 PM?" call-to-action (McTeague)
- Market sentiment (High/Normal/Low volatility)
- YouTube Shorts link (future integration)
- Unsubscribe link (GDPR compliant)

### 4️⃣ User Authentication & Profiles
- **Auth:** Google Sign-In via Firebase Auth
- **Storage:** User profile in Firestore with fields:
  - `email` (string)
  - `displayName` (string)
  - `photoUrl` (string)
  - `isSubscribed` (boolean) ⭐ **Revenue-Critical**
  - `preferredVehicleSize` (number: 40/65/95L)
  - `province` (string: "ON")
  - `createdAt` (timestamp)
  - `lastEmailSent` (timestamp)

**Firestore Structure:**
```
users/
  {userId}/
    email: "user@gmail.com"
    displayName: "John Doe"
    photoUrl: "https://..."
    isSubscribed: true ⭐
    preferredVehicleSize: 65
    province: "ON"
    createdAt: 2026-04-13T10:00:00Z
    lastEmailSent: 2026-04-13T07:00:00Z
```

### 5️⃣ Settings & Preferences
- **Email Toggle:** Real-time Firestore update on subscription change
- **Vehicle Selection:** 40L (Civic), 65L (RAV4), 95L (F-150)
- **Province Selection:** Defaults to Ontario
- **Account Management:** Sign out, delete account (GDPR)

---

## 📁 File Structure

```
FuelLink/
├── lib/                           # Flutter app (Dart)
│   ├── main.dart                  # App entry, routing, AuthWrapper
│   ├── gas_api.dart               # RapidAPI integration, McTeague logic
│   ├── auth_service.dart          # Firebase Auth, Firestore user mgmt
│   ├── login_screen.dart          # Google Sign-In UI
│   ├── settings_screen.dart       # User profile, email toggle ⭐
│   └── firebase_options.dart      # Firebase config (auto-generated)
│
├── functions/                     # Firebase Cloud Functions (TypeScript)
│   ├── src/
│   │   └── index.ts               # Daily email trigger, unsubscribe handler
│   ├── package.json               # Dependencies
│   └── tsconfig.json              # TypeScript config
│
├── android/                       # Android native config
│   └── app/
│       ├── google-services.json   # Firebase config
│       └── build.gradle           # Google Services plugin
│
├── ios/                           # iOS native config
│   └── Runner/
│       └── GoogleService-Info.plist # Firebase config
│
├── pubspec.yaml                   # Flutter dependencies
├── firebase.json                  # Firebase project config
├── firestore.rules                # Firestore security rules
│
├── DEPLOYMENT_GUIDE.md            # Step-by-step deployment instructions
├── DEPLOYMENT_CHECKLIST.md        # Quick-reference checklist
├── FIREBASE_SETUP.sh              # Setup automation script
└── README.md                      # This file
```

---

## 🚀 Quick Start

### Prerequisites
- Flutter SDK (3.19+)
- Node.js 20+
- Firebase CLI
- Google Play Developer account (future: for app store)

### 1. Clone & Install
```bash
git clone <repo-url>
cd FuelLink

# Flutter setup
flutter pub get

# Cloud Functions setup
cd functions
npm install
cd ..
```

### 2. Create Firebase Project
```bash
# Via Firebase Console (recommended):
# 1. Go to https://console.firebase.google.com
# 2. Create project: "fuellink-ontario"
# 3. Enable Google Sign-In authentication
# 4. Create Firestore database (us-east1 region)

# OR via CLI:
firebase init
firebase projects:create fuellink-ontario
```

### 3. Configure FlutterFire
```bash
flutterfire configure --project=fuellink-ontario
# Generates lib/firebase_options.dart with credentials
```

### 4. Set API Keys
```bash
# Get keys from:
# 1. RapidAPI: https://rapidapi.com/DeveloperAmoebas/api/gas-price
# 2. SendGrid: https://sendgrid.com/

# Store in Firebase:
firebase functions:config:set \
  rapidapi.key="YOUR_KEY" \
  sendgrid.key="YOUR_KEY" \
  sendgrid.from="daily@fuellink.app"
```

### 5. Deploy Cloud Functions
```bash
cd functions
npm run deploy
cd ..

# Or full deploy:
firebase deploy
```

### 6. Run App
```bash
flutter run
# Or for web:
flutter run -d web
```

---

## 📡 API Documentation

### Cloud Functions (HTTP Triggers)

#### 1. Daily Email Report (Auto)
**Trigger:** Every day at 7:00 AM EST (via pubsub scheduler)

**Payload:** None (automatic)

**Response:**
```json
{
  "status": "success",
  "emailsSent": 120,
  "emailsFailed": 2,
  "timestamp": "2026-04-13T07:15:30Z"
}
```

#### 2. Unsubscribe Handler
**Endpoint:** `POST /unsubscribeUser`

**Query Params:**
- `email` (string): User email to unsubscribe

**cURL Example:**
```bash
curl -X POST \
  "https://REGION-fuellink-ontario.cloudfunctions.net/unsubscribeUser?email=user@gmail.com"
```

**Response:**
```json
{
  "success": true,
  "message": "✅ You have been unsubscribed from FuelLink daily reports."
}
```

#### 3. Price Drop Predictor
**Endpoint:** `GET /predictPriceDrop`

**Query Params:**
- `currentPrice` (number): Current price in cents/L
- `tankSize` (number, optional): Tank size in liters (default: 65)

**cURL Example:**
```bash
curl "https://REGION-fuellink-ontario.cloudfunctions.net/predictPriceDrop?currentPrice=185&tankSize=65"
```

**Response:**
```json
{
  "currentPrice": 185,
  "estimatedDrop": 8.5,
  "waitTime": "11 hours (until 6 PM)",
  "potentialSavings": "5.53",
  "savingsByHour": "0.503",
  "confidence": "high (volatile market)"
}
```

### Firestore Collections

#### users Collection
```
Collection: users
Primary Key: userId (Firebase Auth UID)

Document Structure:
{
  "email": "user@gmail.com",
  "displayName": "John Doe",
  "photoUrl": "https://...",
  "isSubscribed": true,
  "preferredVehicleSize": 65,
  "province": "ON",
  "createdAt": Timestamp,
  "lastEmailSent": Timestamp,
  "unsubscribeTime": Timestamp (null if subscribed)
}
```

#### emailLogs Collection
```
Collection: emailLogs
Document ID: Auto-generated

Document Structure:
{
  "date": "2026-04-13",
  "totalSubscribed": 150,
  "emailsSent": 148,
  "emailsFailed": 2,
  "averagePrice": 184.5,
  "cheapestPrice": 165.2,
  "expensivePrice": 201.8,
  "volatility": 4.2,
  "timestamp": Timestamp
}
```

#### priceHistory Collection
```
Collection: priceHistory
Document ID: Auto-generated

Document Structure:
{
  "averagePrice": 184.5,
  "cheapestPrice": 165.2,
  "expensivePrice": 201.8,
  "cheapestCity": "Toronto",
  "totalStations": 52,
  "volatility": 4.2,
  "timestamp": Timestamp
}
```

---

## 🔧 Deployment

### Full Deployment
```bash
# 1. Install dependencies
flutter pub get
cd functions && npm install && cd ..

# 2. Build & test
flutter analyze
cd functions && npm run build && cd ..

# 3. Deploy everything
firebase deploy

# 4. Verify
firebase functions:log --follow
```

### Incremental Deployment
```bash
# Deploy only functions (faster for iteration)
firebase deploy --only functions

# Deploy only Firestore rules
firebase deploy --only firestore:rules

# Deploy specific function
firebase functions:delete sendDailyGasPriceReport
firebase deploy --only functions:sendDailyGasPriceReport
```

### Local Testing
```bash
# Start emulators
firebase emulators:start

# In another terminal, test function
curl -X POST http://localhost:5001/fuellink-ontario/northamerica-northeast1/sendDailyGasPriceReport
```

---

## 📊 Monitoring & Analytics

### Key Metrics to Track

1. **Email Performance (Firestore > emailLogs)**
   - Daily email send success rate
   - Average price tracked over time
   - Market volatility trends

2. **User Engagement (Firestore > users)**
   - Active subscriber count
   - New sign-ups per day
   - Unsubscribe rate

3. **Function Performance (Firebase Console)**
   - Execution time
   - Memory usage
   - Error rate
   - Billing

### Sample Queries

**Get Active Subscribers:**
```javascript
db.collection('users')
  .where('isSubscribed', '==', true)
  .get()
  .then(snapshot => console.log(snapshot.size))
```

**Get Yesterday's Email Stats:**
```javascript
const yesterday = new Date();
yesterday.setDate(yesterday.getDate() - 1);

db.collection('emailLogs')
  .where('timestamp', '>=', yesterday)
  .get()
  .then(snapshot => {
    snapshot.forEach(doc => console.log(doc.data()));
  })
```

---

## 🤝 Contributing

### Development Workflow

1. **Feature Branch:**
   ```bash
   git checkout -b feature/new-feature
   ```

2. **Local Testing:**
   ```bash
   flutter run
   # or
   firebase emulators:start
   ```

3. **Code Style:**
   ```bash
   flutter format lib/
   flutter analyze
   ```

4. **Commit & Push:**
   ```bash
   git commit -m "feat: brief description"
   git push origin feature/new-feature
   ```

5. **Pull Request:**
   - Submit PR to `main` branch
   - Include testing notes
   - Request review

### Coding Standards

- **Dart:** Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
- **TypeScript:** Follow [Google TypeScript Style](https://google.github.io/styleguide/tsguide.html)
- **Comments:** Document business logic (McTeague, volatility, etc.)
- **Tests:** Unit tests for gas_api.dart, integration tests for auth_service

---

## 🔐 Security & Privacy

### Data Protection

- **Auth:** OAuth 2.0 via Firebase Auth (no passwords stored)
- **Transport:** HTTPS/TLS for all API calls
- **Storage:** Firestore with security rules (user data isolation)
- **GDPR:** Unsubscribe links and account deletion supported

### Environment Variables

**Never commit secrets:**
```bash
# .gitignore
functions/service-account.json
functions/.env.local
.env
.env.local
```

**Store via Firebase:**
```bash
firebase functions:config:set rapidapi.key="SECRET"
# Accessed in Cloud Functions via:
# const apiKey = process.env.rapidapi_key;
```

---

## 📱 Future Roadmap

- [ ] **YouTube Shorts Integration** (Step 13: Automated daily price narratives)
- [ ] **Push Notifications** (In-app alerts for major price drops)
- [ ] **Multi-Province Support** (Expand beyond Ontario)
- [ ] **AI Price Prediction** (ML model for next-day forecast)
- [ ] **Loyalty Program** (Referral rewards, badges)
- [ ] **Web Dashboard** (Analytics for content creators)

---

## 💰 Monetization Strategy

### Revenue Streams

1. **Google AdMob** ($0.20-0.40 per user/day)
   - In-app banners (home screen)
   - Interstitial ads (after settings)
   - Rewarded ads (optional: "Extra offer" feature)

2. **Email List** ($0.05-0.10 per user/day)
   - YouTube Shorts link (affiliate traffic)
   - Sponsored gas brand offers
   - Insurance/auto-care partner ads

3. **Premium Features** (Future)
   - Smart alerts (push notifications for major drops)
   - Saved routes (navigation history)

### Cost Breakdown (500 active users)

| Item | Daily Cost |
|------|:--:|
| Firebase (Firestore + Functions) | $0.40 |
| SendGrid emails (500 × 1 email) | $0.10 |
| RapidAPI gas price calls | $0.05 |
| **Total** | **~$0.55** |

**Revenue Target:** $0.40-0.60 per user per day  
**Breakeven:** ~800-1000 active users  
**Margin:** 40-50% after infrastructure costs

---

## 📞 Support & Contact

- **Issues:** GitHub Issues
- **Discussions:** GitHub Discussions
- **Email:** support@fuellink.app

---

## 📄 License

MIT License - See LICENSE file for details

---

**Status:** ✅ Ready for Production  
**Last Updated:** April 13, 2026  
**Maintainer:** Your Name (FuelLink Team)

---

## 🎉 Quick Links

- [Deployment Guide](DEPLOYMENT_GUIDE.md) - Step-by-step setup
- [Deployment Checklist](DEPLOYMENT_CHECKLIST.md) - Quick reference
- [Firebase Setup Script](FIREBASE_SETUP.sh) - Automation (bash)
- [Firebase Console](https://console.firebase.google.com)
- [RapidAPI Gas Price API](https://rapidapi.com/DeveloperAmoebas/api/gas-price)
- [SendGrid Documentation](https://sendgrid.com/docs)

Happy saving! 🚗💰
