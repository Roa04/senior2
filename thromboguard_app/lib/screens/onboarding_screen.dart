import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/models.dart';
import '../widgets/bottom_nav_shell.dart';
import '../services/user_data_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _age = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  String _sex = 'Male';
  String _hypertension = 'No';
  String _smoker = 'No';
  String _diabetes = 'No';
  double? _bmi;

  final List<EmergencyContact> _contacts = [EmergencyContact(name: '', phone: '')];

  void _recalcBmi() {
    final h = double.tryParse(_height.text);
    final w = double.tryParse(_weight.text);
    setState(() {
      _bmi = (h != null && w != null && h > 0 && w > 0) ? w / ((h / 100) * (h / 100)) : null;
    });
  }

  bool _saving = false;

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = PatientProfile(
      age: int.tryParse(_age.text) ?? 0,
      sex: _sex,
      hypertension: _hypertension == 'Yes',
      smoker: _smoker == 'Yes',
      heightCm: double.tryParse(_height.text) ?? 0,
      weightKg: double.tryParse(_weight.text) ?? 0,
      diabetes: _diabetes,
      contacts: _contacts.where((c) => c.name.isNotEmpty).toList(),
    );
    setState(() => _saving = true);
    try {
      await UserDataService.saveProfile(profile);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save your profile. Please try again.')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => BottomNavShell(profile: profile)),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(labelText: label);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Container(
              width: 410,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 42,
                            backgroundColor: Color(0xFFE1F1FF),
                            child: Icon(Icons.account_circle, color: AppColors.blue, size: 56),
                          ),
                          SizedBox(height: 10),
                          Text('New User Setup',
                              style: TextStyle(color: AppColors.navy, fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('Enter your medical profile parameters',
                              style: TextStyle(color: Color(0xFF6C757D), fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _SectionTitle('MEDICAL PARAMETERS'),
                    Row(children: [
                      Expanded(
                          child: TextFormField(
                              controller: _age,
                              keyboardType: TextInputType.number,
                              decoration: _dec('Age'),
                              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: DropdownButtonFormField<String>(
                        initialValue: _sex,
                        decoration: _dec('Sex'),
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(value: 'Female', child: Text('Female')),
                        ],
                        onChanged: (v) => setState(() => _sex = v!),
                      )),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: DropdownButtonFormField<String>(
                        initialValue: _hypertension,
                        decoration: _dec('Hypertension'),
                        items: const [
                          DropdownMenuItem(value: 'No', child: Text('No')),
                          DropdownMenuItem(value: 'Yes', child: Text('Yes')),
                        ],
                        onChanged: (v) => setState(() => _hypertension = v!),
                      )),
                      const SizedBox(width: 12),
                      Expanded(
                          child: DropdownButtonFormField<String>(
                        initialValue: _smoker,
                        decoration: _dec('Smoker Status'),
                        items: const [
                          DropdownMenuItem(value: 'No', child: Text('No')),
                          DropdownMenuItem(value: 'Yes', child: Text('Yes')),
                        ],
                        onChanged: (v) => setState(() => _smoker = v!),
                      )),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: TextFormField(
                              controller: _height,
                              keyboardType: TextInputType.number,
                              decoration: _dec('Height (cm)'),
                              onChanged: (_) => _recalcBmi(),
                              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: TextFormField(
                              controller: _weight,
                              keyboardType: TextInputType.number,
                              decoration: _dec('Weight (kg)'),
                              onChanged: (_) => _recalcBmi(),
                              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null)),
                    ]),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _diabetes,
                      decoration: _dec('Diabetes Status'),
                      items: const [
                        DropdownMenuItem(value: 'No', child: Text('No')),
                        DropdownMenuItem(value: 'Type 1', child: Text('Type 1')),
                        DropdownMenuItem(value: 'Type 2', child: Text('Type 2')),
                      ],
                      onChanged: (v) => setState(() => _diabetes = v!),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        border: Border.all(color: AppColors.blue, style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _bmi == null ? 'Live Calculated BMI: --' : 'Live Calculated BMI: ${_bmi!.toStringAsFixed(1)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const _SectionTitle('FAMILY EMERGENCY CONTACTS'),
                        TextButton.icon(
                          onPressed: () => setState(() => _contacts.add(EmergencyContact(name: '', phone: ''))),
                          icon: const Icon(Icons.add, size: 16, color: AppColors.blue),
                          label: const Text('Add', style: TextStyle(color: AppColors.blue)),
                        ),
                      ],
                    ),
                    ..._contacts.asMap().entries.map((e) {
                      final i = e.key;
                      final c = e.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: AppColors.bgCard,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(14)),
                        child: Column(children: [
                          TextFormField(
                            decoration: _dec('Contact Name & Relation'),
                            onChanged: (v) => c.name = v,
                            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            decoration: _dec('Contact Phone Number'),
                            keyboardType: TextInputType.phone,
                            onChanged: (v) => c.phone = v,
                            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                          ),
                          if (i > 0)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => setState(() => _contacts.removeAt(i)),
                                child: const Text('Remove', style: TextStyle(color: AppColors.red)),
                              ),
                            ),
                        ]),
                      );
                    }),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                          onPressed: _saving ? null : _submit, child: Text(_saving ? 'Saving...' : 'Complete Setup & Enter App')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(text,
          style: const TextStyle(
              color: AppColors.blue, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }
}
