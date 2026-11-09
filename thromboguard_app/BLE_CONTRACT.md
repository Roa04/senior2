# Wristband <-> App contract (BLE)

The ESP32 must advertise with the name **ThromboGuard** and expose one
service with two notify characteristics. UUIDs are in `lib/config.dart`.

| Item | UUID |
|---|---|
| Service | 7a1c0001-5b6e-4f5a-9c1d-0a0b0c0d0e0f |
| Vitals (notify) | 7a1c0002-5b6e-4f5a-9c1d-0a0b0c0d0e0f |
| ECG (notify) | 7a1c0003-5b6e-4f5a-9c1d-0a0b0c0d0e0f |

## Vitals - 4 bytes, send about once per second
| Byte | Meaning |
|---|---|
| 0-1 | heart rate in bpm, uint16 little-endian (0 = no reading) |
| 2 | SpO2 in %, uint8 |
| 3 | flags: bit0 = fall detected, bit1 = finger not on sensor |

## ECG - raw samples at 250 Hz
Each notification = up to 10 samples, each int16 little-endian (up to 20
bytes). Send continuously. The raw ADC value is fine: the server
normalises it.

## Test without the wristband (nRF Connect on the Samsung)
1. Install "nRF Connect for Mobile" (free).
2. Open the **Advertiser** tab -> add a record, Complete Local Name = `ThromboGuard`.
3. Add the GATT server with the service/characteristics above and send
   values by hand. (Easier: a second ESP32 or any BLE dev board.)
