# MediDrop Liquid Dosing System - Implementation Guide

## Overview
This is a **liquid dosing system** that monitors a single medicine bottle using an ultrasonic sensor connected to an ESP8266 microcontroller. The system displays real-time liquid levels in the Flutter app through Firebase Realtime Database.

## System Architecture

```
┌─────────────────┐         ┌──────────────────┐         ┌────────────────┐
│   ESP8266 + US  │  ──→    │  Firebase Realtime │  ──→  │  Flutter App   │
│   (Sensor)      │  WiFi   │     Database      │  Sync  │  (Display)     │
└─────────────────┘         └──────────────────┘         └────────────────┘

US Sensor reads distance → Converts to liquid level → Stored in Firebase → App listens & updates UI
```

## Features Implemented

### 1. **Liquid Level Model** (`lib/models/liquid_level.dart`)
- Tracks bottle capacity and current liquid level
- Calculates percentage automatically
- Detects low levels (< 20%)
- Stores sensor ID and last updated timestamp
- Converts to/from Firebase format

### 2. **Liquid Level Service** (`lib/services/liquid_level_service.dart`)
- `getDefaultBottle()` - Gets or creates the default bottle
- `updateLiquidLevel()` - Updates liquid level from ESP8266
- `streamLiquidLevel()` - Real-time listener for Firebase changes
- `writeLiquidLevel()` - Save bottle data
- `readLiquidLevel()` - Fetch bottle data

### 3. **Liquid Level Widget** (`lib/widgets/liquid_level_bar.dart`)
- Visual liquid level bar with gradient fill
- Shows percentage and ml information
- Color changes based on level (green = normal, red = low)
- Last updated timestamp
- Low level warning message

### 4. **Home Screen Integration**
- Displays liquid level bar prominently on dashboard
- Real-time updates from Firebase
- Located above "Today's Medicines" section
- Settings button to access test screen

### 5. **Test Screen** (`lib/screens/liquid_level_test_screen.dart`)
- Manually adjust liquid level for testing
- Quick percentage buttons (100%, 75%, 50%, 25%, 10%, 0%)
- View current bottle status
- Accessible via settings icon on home screen

## Database Structure

```
medidrop-5c183
└── liquid_levels/
    └── bottle_001/
        ├── id: "bottle_001"
        ├── bottleName: "Main Medicine Bottle"
        ├── capacity: 500.0  (ml)
        ├── currentLevel: 250.0  (ml)
        ├── percentageLevel: 50.0
        ├── lastUpdated: "2025-11-15T10:30:00.000Z"
        ├── sensorId: "ESP86_001"
        └── isLow: false
```

## Real-Time Data Flow

1. **ESP8266 Sends Data** (every 5 seconds)
   ```
   Ultrasonic Sensor → Distance (cm)
   Distance → Liquid Level (ml)
   Update Firebase: /liquid_levels/bottle_001/currentLevel
   ```

2. **App Listens to Changes**
   ```
   Stream listener on /liquid_levels/bottle_001
   Updates whenever value changes
   UI rebuilds with new data
   ```

3. **Home Screen Updates**
   - Liquid level bar updates in real-time
   - Color changes if level drops below 20%
   - Warning message appears when low
   - Test screen shows current status

## ESP8266 Setup

### Hardware Connections
```
Ultrasonic Sensor (HC-SR04)
├── VCC → ESP8266 5V
├── GND → ESP8266 GND
├── TRIG → D5 (GPIO14)
└── ECHO → D6 (GPIO12)

WiFi: ESP8266 connects to your network
```

### Software Setup
1. Install Arduino IDE with ESP8266 board support
2. Install Firebase ESP8266 library
3. Edit `ESP8266_SKETCH.ino`:
   - Set `WIFI_SSID` and `WIFI_PASSWORD`
   - Firebase credentials are already set
4. Upload to ESP8266
5. Monitor serial output

### Calibration
Edit these values in `ESP8266_SKETCH.ino`:
```cpp
const float EMPTY_DISTANCE = 15.0;   // Distance when bottle is empty
const float FULL_DISTANCE = 3.0;     // Distance when bottle is full
const float BOTTLE_CAPACITY = 500.0; // Total capacity in ml
```

Calibrate by:
1. Measure distance when bottle is completely full
2. Measure distance when bottle is completely empty
3. Update the constants above

## Testing Locally

### Without ESP8266
1. Open home screen
2. Tap settings icon (⚙️) in top-right
3. Go to "Test Liquid Level" screen
4. Adjust level using quick buttons or manual input
5. Watch home screen update in real-time

### With ESP8266
1. Upload sketch to ESP8266
2. Monitor serial output to verify:
   - WiFi connection
   - Firebase authentication
   - Distance readings
3. Check Firebase console for updates
4. Verify app updates in real-time

## How Real-Time Updates Work

```dart
// In home_screen.dart
_setupLiquidLevelListener() {
  _liquidLevelSubscription = 
    LiquidLevelService.streamLiquidLevel('bottle_001').listen(
      (liquidLevel) {
        setState(() {
          _liquidLevel = liquidLevel;  // Updates immediately
        });
      },
    );
}
```

The app maintains an active listener on Firebase. When the database value changes:
1. Firebase sends new data to app
2. Listener callback triggers
3. Widget rebuilds with new data
4. UI shows updated liquid level bar

## Firebase Database Rules

Make sure these rules allow the app to read/write liquid levels:

```json
{
  "rules": {
    "liquid_levels": {
      ".read": true,
      ".write": true
    }
  }
}
```

## File Structure

```
lib/
├── models/
│   ├── liquid_level.dart          (New)
│   ├── medicine.dart
│   └── medicine_history.dart
├── services/
│   ├── liquid_level_service.dart  (New)
│   ├── medicine_notification_handler.dart
│   └── notifications_service.dart
├── widgets/
│   └── liquid_level_bar.dart      (New)
├── screens/
│   ├── home_screen.dart           (Updated)
│   ├── liquid_level_test_screen.dart (New)
│   ├── add_medicine_screen.dart
│   └── ...
├── firebase_operations.dart
├── main.dart
└── theme.dart
```

## Future Enhancements

1. **Multiple Bottles** - Extend to support multiple medicine bottles
2. **Historical Data** - Store liquid level history for analytics
3. **Alerts** - Send notifications when level is low
4. **Calibration UI** - In-app calibration wizard
5. **Data Export** - Export usage reports
6. **Predictive Refill** - Predict when bottle needs refill based on usage

## Troubleshooting

### App not updating
- Check Firebase connection
- Verify database rules allow read access
- Check if listener is active in home_screen.dart

### ESP8266 not connecting to WiFi
- Check WiFi credentials in sketch
- Verify WiFi is 2.4GHz (ESP8266 doesn't support 5GHz)
- Check serial output for error messages

### Sensor readings inaccurate
- Calibrate distance values
- Ensure sensor is parallel to bottle
- Check for obstacles blocking sensor

### Firebase updates not working
- Verify API key is correct
- Check database URL
- Ensure WiFi connection is stable
- Monitor serial output for Firebase errors

## Key Components Summary

| Component | Purpose | Location |
|-----------|---------|----------|
| LiquidLevel | Data model for bottle | `lib/models/liquid_level.dart` |
| LiquidLevelService | Firebase operations | `lib/services/liquid_level_service.dart` |
| LiquidLevelBar | UI widget | `lib/widgets/liquid_level_bar.dart` |
| HomeScreen | Displays liquid level | `lib/screens/home_screen.dart` |
| LiquidLevelTestScreen | Manual testing | `lib/screens/liquid_level_test_screen.dart` |
| ESP8266 Sketch | Sensor data sender | `ESP8266_SKETCH.ino` |

---

**System is now ready for real-time liquid level monitoring! 🎯**
