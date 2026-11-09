import 'package:flutter_test/flutter_test.dart';
import 'package:thromboguard/models/models.dart';
import 'package:thromboguard/services/ptbxl_service.dart';

void main() {
  group('classifyFromScpCodes', () {
    test('NORM -> normal', () {
      expect(PtbxlService.classifyFromScpCodes({'NORM': 100.0}), RiskLevel.normal);
    });
    test('STTC/CD/HYP codes -> abnormal', () {
      expect(PtbxlService.classifyFromScpCodes({'LVH': 80.0}), RiskLevel.abnormal);
      expect(PtbxlService.classifyFromScpCodes({'CLBBB': 90.0}), RiskLevel.abnormal);
    });
    test('MI codes -> critical (even alongside abnormal codes)', () {
      expect(PtbxlService.classifyFromScpCodes({'IMI': 80.0}), RiskLevel.critical);
      expect(PtbxlService.classifyFromScpCodes({'LVH': 50.0, 'ASMI': 70.0}), RiskLevel.critical);
    });
  });

  group('serialization', () {
    test('PatientProfile round-trips through map', () {
      final p = PatientProfile(
        age: 40, sex: 'Female', hypertension: true, smoker: false,
        heightCm: 165, weightKg: 60, diabetes: 'No',
        contacts: [EmergencyContact(name: 'Mom', phone: '+970590000000')],
      );
      final q = PatientProfile.fromMap(p.toMap());
      expect(q.age, 40);
      expect(q.contacts.single.name, 'Mom');
      expect(q.hypertension, true);
    });
  });
}
