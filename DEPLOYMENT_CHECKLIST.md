# FuelLink Backend Deployment Checklist
## Quick Reference for Day-of-Deployment

---

## Pre-Deployment (Complete Before Starting)

- [ ] **Firebase Console Access**
  - [ ] Google account with admin permissions
  - [ ] Project created: "fuellink-ontario"

- [ ] **API Keys Obtained**
  - [ ] RapidAPI key for gas prices (from rapidapi.com)
  - [ ] SendGrid API key with "Mail Send" permission (from sendgrid.com)

- [ ] **Tools Installed**
  - [ ] Firebase CLI (`firebase --version`)
  - [ ] Node.js 20+ (`node --version`)
  - [ ] Flutter SDK (`flutter --version`)

- [ ] **Repository State**
  - [ ] All code committed to Git
  - [ ] `.gitignore` includes `functions/service-account.json`
  - [ ] `.gitignore` includes `functions/.env.local`

---

## Part 1: Firebase Console (15 min)

### Step 1: Create Authentication
- [ ] Go to Firebase Console > Project > Build > Authentication
- [ ] Enable Google Sign-In method
- [ ] Set project name: "FuelLink Ontario"
- [ ] Set support email

### Step 2: Create Firestore
- [ ] Go to Firestore Database
- [ ] Create in production mode
- [ ] Region: us-east1
- [ ] Deploy security rules (from firestore.rules)

### Step 3: Download Service Account Key
- [ ] Project Settings > Service Accounts > Generate Key
- [ ] Save as `functions/service-account.json`
- [ ] **DO NOT COMMIT** to Git

### Step 4: Verify Settings
- [ ] Authentication enabled for Google Sign-In
- [ ] Firestore database created and empty
- [ ] Region is us-east1

---

## Part 2: Local Environment (10 min)

### Step 5: Set Up Firebase CLI
```bash
firebase login
firebase use --add
# Select: fuellink-ontario
# Alias: default
```
- [ ] `firebase projects:list` shows "fuellink-ontario"

### Step 6: Configure Environment Variables
```bash
firebase functions:config:set \
  rapidapi.key="YOUR_RAPIDAPI_KEY" \
  sendgrid.key="SG.YOUR_SENDGRID_KEY" \
  sendgrid.from="daily@fuellink.app"
```
- [ ] No errors in CLI output
- [ ] `firebase functions:config:get` shows all three keys

### Step 7: Verify Function Files
```bash
cd functions
npm install
npm run build
```
- [ ] `lib/` folder created with compiled JS
- [ ] No errors during build
- [ ] `node_modules/` installed

---

## Part 3: Deploy (5 min)

### Step 8: Deploy Cloud Functions
```bash
firebase deploy --only functions
```
- [ ] Three functions deployed:
  - [ ] `sendDailyGasPriceReport` (pubsub trigger)
  - [ ] `unsubscribeUser` (HTTP trigger)
  - [ ] `predictPriceDrop` (HTTP trigger)

### Step 9: Deploy Firestore Rules
```bash
firebase deploy --only firestore:rules
```
- [ ] Rules deployed without errors
- [ ] Console > Firestore > Rules shows updated rules

### Step 10: Deploy Firestore Indexes
```bash
firebase deploy --only firestore:indexes
```
- [ ] Indexes created (or auto-created on first email send)

---

## Part 4: Flutter Setup (5 min)

### Step 11: Configure FlutterFire
```bash
cd /path/to/FuelLink
flutterfire configure --project=fuellink-ontario
# Select: android, ios, web
```
- [ ] `lib/firebase_options.dart` generated
- [ ] No errors during configuration

### Step 12: Set Up Android
- [ ] Download `google-services.json` from Firebase Console
- [ ] Copy to: `android/app/google-services.json`
- [ ] Update `android/build.gradle` with google-services plugin
- [ ] Update `android/app/build.gradle` with plugin application

### Step 13: Set Up iOS
- [ ] Download `GoogleService-Info.plist` from Firebase Console
- [ ] Copy to: `ios/Runner/GoogleService-Info.plist`
- [ ] Add to Xcode project (Build Phases > Copy Bundle Resources)

### Step 14: Verify Flutter Build
```bash
flutter pub get
flutter analyze
```
- [ ] No errors or warnings
- [ ] All dependencies resolved

---

## Part 5: Testing (10 min)

### Step 15: Test Authentication
```bash
flutter run
```
- [ ] Login screen displays
- [ ] Google Sign-In button functional
- [ ] After sign-in, user document created in Firestore

### Step 16: Test Settings
- [ ] Settings screen accessible from home
- [ ] Email toggle works (check Firestore `isSubscribed` updates)
- [ ] Vehicle size selector functional
- [ ] Sign out works

### Step 17: Test Email Send (Optional)
```bash
firebase functions:call sendDailyGasPriceReport --data="{}"
```
- [ ] Check `firebase functions:log`
- [ ] Verify documents created in Firestore:
  - [ ] `priceHistory/` collection has entry
  - [ ] `emailLogs/` collection has entry
- [ ] Check email service (SendGrid dashboard) for delivery

### Step 18: Test Unsubscribe
- [ ] Manually visit unsubscribe link from email
- [ ] Verify Firestore user `isSubscribed = false`
- [ ] Confirmation page displays

---

## Post-Deployment (Ongoing)

- [ ] **Monitor Logs:** `firebase functions:log --follow`
- [ ] **Set Up Alerts:** Console > Functions > Create Alert Policy
- [ ] **Enable Backups:** Console > Firestore > Backups > Create Schedule
- [ ] **Test Daily:** Wait for 7 AM EST or manually trigger function
- [ ] **Monitor Costs:** Console > Firestore > Usage (should be <$1/day at 500 users)

---

## Emergency Rollback

If issues occur:

```bash
# Disable functions (keep Firestore data)
firebase functions:delete sendDailyGasPriceReport

# Disable authentication
# Console > Authentication > Google > Disable

# Restore Firestore from backup
# Console > Backups > Restore
```

---

## Success Criteria ✅

**All of these should be true:**

1. Firebase project operational with Google Sign-In working
2. FlutterFire CLI configured Firebase options
3. Three Cloud Functions deployed and monitored
4. Firestore collections created with correct schema
5. Firestore security rules enforced
6. Flutter app successfully signs in users
7. Settings screen updates Firestore in real-time
8. Email sends at 7 AM EST (verified with test trigger)
9. Unsubscribe links work and update user profile
10. No errors in Firebase Function logs

---

## Contact & Support

- **Firebase Docs:** https://firebase.google.com/docs
- **SendGrid Support:** https://support.sendgrid.com
- **RapidAPI Support:** https://rapidapi.com/support

---

**Estimated Total Time:** ~45 minutes  
**Status:** Ready to deploy ✅  
**Last Updated:** April 13, 2026
