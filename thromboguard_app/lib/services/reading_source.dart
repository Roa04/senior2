import '../models/models.dart';

/// Anything that produces VitalReading objects: the simulator today,
/// the BLE wristband + cloud model later. The UI only knows this interface,
/// so switching sources never requires touching the screens.
abstract class ReadingSource {
  Stream<VitalReading> get readings;
  void start();
  void dispose();
}
