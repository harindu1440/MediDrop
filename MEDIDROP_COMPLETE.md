# MediDrop - Smart Medicine Reminder System

A comprehensive Flutter application for managing medications, setting reminders, and tracking medicine intake with Firebase Realtime Database integration.

## 🎯 Project Overview

MediDrop is a medicine reminder application that helps patients manage their medications effectively by providing:
- **Medication Tracking** - Add, edit, and manage medicines
- **Smart Reminders** - Set scheduled reminders for each medication
- **Real-time Sync** - Firebase integration for data persistence
- **User Profile** - Maintain patient health information
- **Medication History** - Track taken medicines

## ✨ Features

### 1. **Splash Screen**
- Beautiful animated intro screen
- Smooth fade-in and scale animations
- Automatic navigation to home screen

### 2. **Dashboard**
- Overview of all medicines
- Today's medication schedule
- Quick stats (Total medicines, Today's doses)
- Recent medicines list

### 3. **Medicine Management**
- **Add Medicine Screen**: Add new medications with dosage, frequency, and time
- **Medicine List Screen**: View all medicines with details
- **Delete Functionality**: Remove medicines from the list

### 4. **Medicine Details**
Each medicine includes:
- Medicine name
- Dosage (e.g., 500mg)
- Frequency (Once a day, Twice a day, etc.)
- Reminder time
- Date added

### 5. **User Profile**
- Edit user information
- Health details (Blood type, Allergies, Emergency contact)
- Patient information management

### 6. **Real-time Database Integration**
- Firebase Realtime Database for data persistence
- Automatic sync across devices
- Real-time updates

## 📱 App Structure

```
lib/
├── main.dart                          # App entry point
├── firebase_operations.dart           # Firebase helper functions
├── screens/
│   ├── splash_screen.dart            # Splash/Loading screen
│   ├── home_screen.dart              # Main dashboard
│   ├── add_medicine_screen.dart       # Add new medicine
│   ├── medicine_list_screen.dart      # View all medicines
│   └── profile_screen.dart           # User profile
└── models/
    └── medicine.dart                  # Medicine data model
```

## 🔧 Firebase Configuration

The app is configured with Firebase Realtime Database:
- **Project ID**: medidrop-5c183
- **Database URL**: `https://medidrop-5c183-default-rtdb.firebaseio.com`
- **Region**: us-central1

### Database Structure

```
medidrop-5c183-default-rtdb
└── medicines/
    └── {medicineId}/
        ├── id: string
        ├── name: string
        ├── dosage: string
        ├── frequency: string
        ├── time: string
        └── dateAdded: string (ISO 8601)
```

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.9.2 or higher)
- Android Studio or Xcode
- Firebase account

### Installation

1. **Clone the repository**
```bash
cd medidrop
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Configure Firebase**
- The `google-services.json` is already configured for Android
- Ensure Firebase Realtime Database is enabled in Firebase Console

4. **Run the app**
```bash
flutter run
```

## 📋 Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^4.2.1
  firebase_database: ^12.0.4
  cupertino_icons: ^1.0.8

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
```

## 🎨 UI/UX Features

- **Modern Material Design**: Follows Material Design 3 guidelines
- **Gradient Backgrounds**: Eye-catching gradients for better UI
- **Smooth Animations**: Fade-in and scale animations
- **Responsive Layout**: Adapts to different screen sizes
- **Dark/Light Support**: Theme support ready
- **Bottom Navigation**: Easy navigation between screens

## 🔐 Firebase Security Rules

Current rules (for development - Update for production):
```json
{
  "rules": {
    ".read": true,
    ".write": true
  }
}
```

**Production Rules (recommended)**:
```json
{
  "rules": {
    ".read": "auth != null",
    ".write": "auth != null",
    "medicines": {
      ".indexOn": ["userId"]
    }
  }
}
```

## 📊 Data Model

### Medicine Class
```dart
class Medicine {
  final String id;
  final String name;
  final String dosage;
  final String frequency;
  final String time;
  final DateTime dateAdded;
}
```

## 🔄 Data Flow

1. **User adds medicine** → MediDrop stores in Firebase
2. **Firebase syncs** → Data persists across devices
3. **App loads** → Retrieves all medicines from Firebase
4. **User deletes** → Medicine removed from database
5. **Real-time updates** → All changes reflected immediately

## 🧪 Testing the App

### Test Firebase Connection
- Navigate to Dashboard
- Check if medicines load from Firebase
- Add a new medicine and verify it appears in the list

### Add Medicine Example
- Name: "Aspirin"
- Dosage: "100mg"
- Frequency: "Once a day"
- Time: "09:00 AM"

### Features to Test
✅ Splash screen animations
✅ Dashboard stats
✅ Add medicine functionality
✅ View medicines list
✅ Delete medicine
✅ Edit profile
✅ Firebase data persistence

## 🐛 Troubleshooting

### Firebase Connection Issues
- Verify database URL in `main.dart`
- Check Firebase project is active
- Ensure Android app is registered in Firebase Console

### Build Issues
```bash
# Clean build
flutter clean
flutter pub get
flutter run
```

### No medicines appearing
- Check Firebase database has data
- Verify security rules allow reads
- Check console logs for errors

## 📈 Future Enhancements

- [ ] Push notifications for reminders
- [ ] Medicine intake history tracking
- [ ] Doctor/patient role separation
- [ ] Prescription image upload
- [ ] Medicine interaction warnings
- [ ] Offline mode with local storage
- [ ] Export medication report
- [ ] Multi-language support
- [ ] Dark theme
- [ ] Advanced analytics

## 📝 License

This project is open source and available under the MIT License.

## 👥 Contributors

- Student development team

## 📞 Support

For issues and questions, please check the Firebase console and app logs.

---

**Version**: 1.0.0
**Last Updated**: November 14, 2025
**Status**: ✅ Complete & Working
