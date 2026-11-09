/// Emergency-flow settings (one place to change them).
library;

/// SAFETY SWITCH. While true, the emergency flow runs normally (red screen,
/// countdown, message text) but NO real SMS is sent and NO call is placed;
/// the screen just shows what it WOULD do. The simulator creates random
/// Critical readings, so keep this true until you test with a number you own,
/// then set it to false.
const bool kEmergencyDryRun = true;

/// Seconds the patient has to press "I'M OK" before the alert goes out.
const int kCountdownSeconds = 10;

// ---------------------------------------------------------------------
// Data source: simulator now, real wristband + cloud AI later.
// ---------------------------------------------------------------------

/// true  = random simulated readings (no wristband, no server needed).
/// false = real wristband over Bluetooth + cloud AI server.
const bool kUseSimulator = true;

/// Address of the FastAPI server (thromboguard_server). While testing on
/// your laptop use its Wi-Fi IP (run `ipconfig`), NOT localhost: the phone
/// can't reach the laptop's "localhost". The phone and laptop must be on
/// the same Wi-Fi. Later replace with the cloud URL (https://...).
const String kApiBaseUrl = 'http://192.168.1.10:8000';

/// Wristband BLE contract. See BLE_CONTRACT.md. The ESP32 must use the
/// same name and UUIDs.
const String kBleDeviceName = 'ThromboGuard';
const String kBleServiceUuid = '7a1c0001-5b6e-4f5a-9c1d-0a0b0c0d0e0f';
const String kBleVitalsUuid = '7a1c0002-5b6e-4f5a-9c1d-0a0b0c0d0e0f';
const String kBleEcgUuid = '7a1c0003-5b6e-4f5a-9c1d-0a0b0c0d0e0f';

/// ECG stream: AD8232 on the ESP32.
const int kEcgSampleRate = 250; // Hz
const int kEcgWindowSeconds = 10; // seconds sent to the AI each time
const int kAnalyzeEverySeconds = 10; // how often a new AI result is produced
