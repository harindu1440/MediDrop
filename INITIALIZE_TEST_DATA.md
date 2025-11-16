# Initialize Test Data in Firebase

To test the liquid dosing system, you need to create initial data in Firebase Realtime Database.

## Option 1: Firebase Console (Easiest)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **medidrop-5c183**
3. Go to **Realtime Database**
4. Click **+** to add new data
5. Enter path: `liquid_levels/bottle_001`
6. Copy-paste this JSON:

```json
{
  "id": "bottle_001",
  "bottleName": "Main Medicine Bottle",
  "capacity": 500,
  "currentLevel": 250,
  "percentageLevel": 50,
  "lastUpdated": "2025-11-15T00:00:00.000Z",
  "sensorId": "ESP86_001",
  "isLow": false
}
```

7. Click **Add**
8. Done! 🎉

---

## Option 2: Using Flutter App (Recommended for Testing)

1. Run the app
2. Open **Home Screen**
3. Click **⚙️** (settings icon) → **Test Liquid Level**
4. Click **100%** button to fill bottle
5. Click **"Update Liquid Level"**
6. Go back to home screen - liquid bar is now visible!

The test screen automatically creates the database entry if it doesn't exist.

---

## Option 3: From Dart Code

You can initialize data programmatically. Add this to `main.dart` in `initState()`:

```dart
import 'services/liquid_level_service.dart';
import 'models/liquid_level.dart';

// Initialize test bottle
final testBottle = LiquidLevel(
  id: 'bottle_001',
  bottleName: 'Main Medicine Bottle',
  capacity: 500.0,
  currentLevel: 250.0,
  lastUpdated: DateTime.now(),
  sensorId: 'ESP86_001',
);

await LiquidLevelService.writeLiquidLevel(testBottle);
```

---

## Verify Data Was Created

1. Open Firebase Console
2. Navigate to **Realtime Database**
3. Look for `liquid_levels` → `bottle_001`
4. You should see all fields

---

## Test Real-Time Updates

After creating the initial data:

1. Open app home screen - you'll see the liquid level bar!
2. Open Test Liquid Level screen
3. Change the percentage (e.g., 75%)
4. Click "Update Liquid Level"
5. Go back to home screen
6. Watch the bar update instantly! 🎯

---

## Next: Connect ESP8266

Once you verify the Flutter app works:

1. Upload `ESP8266_SKETCH.ino` to your ESP8266
2. Sensor will start sending real data
3. App updates automatically from sensor readings
4. You're done! The system is live! 🚀

---

## Troubleshooting

**Liquid level bar not showing?**
- Check if `bottle_001` exists in Firebase
- Verify database structure matches above JSON
- Check Firebase connection in app console

**Updates not working?**
- Ensure database rules allow read/write access
- Check app console for connection errors
- Verify internet connection is stable

**Data not appearing in Firebase?**
- Check you're in correct project (medidrop-5c183)
- Verify you selected Realtime Database (not Firestore)
- Confirm the path is: `liquid_levels/bottle_001`

---

Your system is ready! Start testing now! 🎉
