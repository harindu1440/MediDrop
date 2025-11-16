// ESP8266 Sketch for MediDrop Ultrasonic Sensor
// This sketch reads an ultrasonic sensor and sends the liquid level to Firebase

#include <ESP8266WiFi.h>
#include <Firebase_ESP_Client.h>
#include <addons/TokenHelper.h>
#include <addons/RTDBHelper.h>

// WiFi Configuration
#define WIFI_SSID "YOUR_SSID"
#define WIFI_PASSWORD "YOUR_PASSWORD"

// Firebase Configuration
#define API_KEY "AIzaSyDZjpGnBfbsoAo27b9U6fJfV-dr4YJI3vI"
#define DATABASE_URL "https://medidrop-5c183-default-rtdb.firebaseio.com"
#define USER_EMAIL "user@example.com"
#define USER_PASSWORD "password"

// Ultrasonic Sensor Pins
#define TRIGGER_PIN D5  // GPIO14
#define ECHO_PIN D6     // GPIO12

// Firebase objects
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// Timing variables
unsigned long lastUpdateTime = 0;
const unsigned long UPDATE_INTERVAL = 5000;  // Update every 5 seconds

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n\nMediDrop ESP8266 Liquid Level Sensor");
  Serial.println("=====================================\n");
  
  // Setup pins
  pinMode(TRIGGER_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  
  // Connect to WiFi
  connectToWiFi();
  
  // Firebase configuration
  config.api_key = API_KEY;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;
  config.database_url = DATABASE_URL;
  config.token_status_callback = tokenStatusCallback;
  
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
}

void loop() {
  // Read sensor and update database every UPDATE_INTERVAL
  if (millis() - lastUpdateTime >= UPDATE_INTERVAL) {
    lastUpdateTime = millis();
    
    // Read distance from sensor
    float distance = readUltrasonicDistance();
    Serial.print("Distance: ");
    Serial.print(distance);
    Serial.println(" cm");
    
    // Convert distance to liquid level (adjust values based on your bottle setup)
    // Assuming: bottle height = 15cm, empty = 15cm distance, full = 3cm distance
    float liquidLevel = convertDistanceToLevel(distance);
    Serial.print("Liquid Level: ");
    Serial.print(liquidLevel);
    Serial.println(" ml");
    
    // Update Firebase
    updateFirebase(liquidLevel);
  }
  
  delay(100);
}

float readUltrasonicDistance() {
  // Send trigger pulse
  digitalWrite(TRIGGER_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIGGER_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIGGER_PIN, LOW);
  
  // Measure echo duration
  long duration = pulseIn(ECHO_PIN, HIGH, 30000);
  
  // Calculate distance (Speed of sound = 0.034 cm/us)
  float distance = duration * 0.034 / 2;
  
  return distance;
}

float convertDistanceToLevel(float distance) {
  // Calibration values (adjust these based on your bottle setup)
  const float EMPTY_DISTANCE = 15.0;  // Distance when bottle is empty (cm)
  const float FULL_DISTANCE = 3.0;    // Distance when bottle is full (cm)
  const float BOTTLE_CAPACITY = 500.0; // Total capacity in ml
  
  // Clamp distance between full and empty
  if (distance < FULL_DISTANCE) {
    distance = FULL_DISTANCE;
  } else if (distance > EMPTY_DISTANCE) {
    distance = EMPTY_DISTANCE;
  }
  
  // Calculate percentage and convert to ml
  float percentage = (EMPTY_DISTANCE - distance) / (EMPTY_DISTANCE - FULL_DISTANCE);
  float liquidLevel = percentage * BOTTLE_CAPACITY;
  
  return liquidLevel;
}

void updateFirebase(float liquidLevel) {
  if (Firebase.ready() && auth.token.uid()) {
    // Create update data
    FirebaseJson json;
    json.set("currentLevel", liquidLevel);
    json.set("lastUpdated", Firebase.serverTimestamp());
    
    // Update Firebase
    if (Firebase.RTDB.updateNode(&fbdo, "/liquid_levels/bottle_001", &json)) {
      Serial.println("✓ Firebase update successful");
    } else {
      Serial.print("✗ Firebase error: ");
      Serial.println(fbdo.errorReason());
    }
  } else {
    Serial.println("Firebase not ready or not authenticated");
  }
}

void connectToWiFi() {
  Serial.print("Connecting to WiFi: ");
  Serial.println(WIFI_SSID);
  
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n✓ WiFi Connected!");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\n✗ WiFi Connection Failed!");
  }
}

void tokenStatusCallback(token_info_t info) {
  if (info.status == token_status_ready) {
    Serial.println("✓ Firebase token ready");
  } else if (info.status == token_status_error) {
    Serial.print("✗ Firebase token error: ");
    Serial.println(info.error.message);
  }
}
