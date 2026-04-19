# 🚀 FuelLink Deployment - Quick Start (Windows PowerShell)

## Step 1: Set Secure Firebase Secrets

Run these commands **in PowerShell** (not bash). This teaches Firebase your API keys securely:

```powershell
# ✅ Copy and paste EACH command one at a time:

firebase functions:config:set gas_api.key="YOUR_RAPIDAPI_KEY"

firebase functions:config:set sendgrid.key="SG.YOUR_SENDGRID_KEY"

firebase functions:config:set sendgrid.from="daily@fuellink.app"
```

**Where to get keys:**
- **RapidAPI Key:** https://rapidapi.com/DeveloperAmoebas/api/gas-price (free account)
- **SendGrid Key:** https://sendgrid.com → Settings > API Keys (100 free emails/day)

**Example:**
```powershell
firebase functions:config:set gas_api.key="xxxxxxx.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
firebase functions:config:set sendgrid.key="SG.1234567890abcdefghijklmnopqrstuvwxyz"
firebase functions:config:set sendgrid.from="daily@fuellink.app"
```

✅ **Verify it worked:**
```powershell
firebase functions:config:get
```

Should show:
```json
{
  "gas_api": { "key": "set" },
  "sendgrid": { "key": "set", "from": "set" }
}
```

---

## Step 2: Deploy Cloud Functions

Navigate to the functions folder and deploy:

```powershell
# Go into functions directory
cd functions

# Install dependencies (including SendGrid)
npm install

# Deploy to Firebase
firebase deploy --only functions
```

**Expected output:**
```
✓ sendDailyGasPriceReport (pubsub trigger - runs daily at 7:00 AM EST) ✅
✓ unsubscribeUser (HTTP trigger)                                      ✅
✓ predictPriceDrop (HTTP trigger)                                     ✅

Deployed successfully!
```

---

## Step 3: Test It Works

```powershell
# Watch the function logs in real-time
firebase functions:log --follow
```

**To manually trigger the email (testing only):**
```powershell
firebase functions:call sendDailyGasPriceReport --data="{}"
```

---

## ✅ You're Done! 

Your 7:00 AM Ontario commuter email system is now **LIVE** 🎉

- ⏰ Daily emails trigger at 7:00 AM EST
- 📧 SendGrid sends to all subscribers
- 🔐 Secrets stored securely in Firebase
- 📊 McTeague Logic automatically included
- 💾 Analytics logged to Firestore

---

## Troubleshooting

**Error: "firebase: command not found"**
```powershell
# Install Firebase CLI globally
npm install -g firebase-tools
firebase --version  # Should show version
```

**Error: "GAS_PRICE_API_KEY not configured"**
```powershell
# You forgot Step 1! Run:
firebase functions:config:set gas_api.key="YOUR_KEY"
firebase deploy --only functions
```

**Error: "SENDGRID_API_KEY not configured"**
```powershell
# You forgot Step 1! Run:
firebase functions:config:set sendgrid.key="YOUR_KEY"
firebase deploy --only functions
```

**Emails not sending?**
1. Check SendGrid sender verification: https://sendgrid.com → Settings > Sender Authentication
2. Verify email address is verified (needs green checkmark)
3. Check function logs: `firebase functions:log --follow`

---

## Next: Connect Flutter App

Once emails are working, configure your Flutter app:

```bash
# From FuelLink root:
flutterfire configure --project=fuellink-ontario

# Then run:
flutter pub get
flutter run
```

Sign in with Google → Should create user in Firestore → Email should go out tomorrow at 7 AM!

---

**Time to Deploy:** ~10 minutes ⚡  
**Status:** ✅ Production Ready  
**Next Update:** Tomorrow at 7:00 AM EST 📧
