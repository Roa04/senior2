import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';
import '../models/models.dart';
import '../screens/login_screen.dart';
import '../services/user_data_service.dart';

class ProfileScreen extends StatefulWidget {
  final PatientProfile profile;
  const ProfileScreen({super.key, required this.profile});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _age;
  late TextEditingController _height;
  late TextEditingController _weight;
  late String _sex;
  late String _hyper;
  late String _smoker;
  late String _diabetes;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _age = TextEditingController(text: p.age.toString());
    _height = TextEditingController(text: p.heightCm.toStringAsFixed(0));
    _weight = TextEditingController(text: p.weightKg.toStringAsFixed(0));
    _sex = p.sex;
    _hyper = p.hypertension ? 'Yes' : 'No';
    _smoker = p.smoker ? 'Yes' : 'No';
    _diabetes = p.diabetes;
  }

  double get _bmi {
    final h = double.tryParse(_height.text) ?? 0;
    final w = double.tryParse(_weight.text) ?? 0;
    return h > 0 ? w / ((h / 100) * (h / 100)) : 0;
  }

  void _save() async {
    widget.profile
      ..age = int.tryParse(_age.text) ?? widget.profile.age
      ..sex = _sex
      ..hypertension = _hyper == 'Yes'
      ..smoker = _smoker == 'Yes'
      ..heightCm = double.tryParse(_height.text) ?? widget.profile.heightCm
      ..weightKg = double.tryParse(_weight.text) ?? widget.profile.weightKg
      ..diabetes = _diabetes;
    String msg = 'Profile saved successfully!';
    try {
      await UserDataService.saveProfile(widget.profile);
    } catch (_) {
      msg = 'Could not save to the cloud. Please try again.';
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Column(children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: Color(0xFFE1F1FF),
                    child: Icon(Icons.account_circle, color: AppColors.blue, size: 56),
                  ),
                  SizedBox(height: 8),
                  Text('User Profile',
                      style: TextStyle(color: AppColors.navy, fontSize: 20, fontWeight: FontWeight.bold)),
                ]),
              ),
              const SizedBox(height: 16),
              const Text('MEDICAL PARAMETERS',
                  style: TextStyle(color: AppColors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: _age,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Age'),
                        onChanged: (_) => setState(() {}))),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _sex,
                    decoration: const InputDecoration(labelText: 'Sex'),
                    items: const [
                      DropdownMenuItem(value: 'Male', child: Text('Male')),
                      DropdownMenuItem(value: 'Female', child: Text('Female')),
                    ],
                    onChanged: (v) => setState(() => _sex = v!),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _hyper,
                    decoration: const InputDecoration(labelText: 'Hypertension'),
                    items: const [
                      DropdownMenuItem(value: 'No', child: Text('No')),
                      DropdownMenuItem(value: 'Yes', child: Text('Yes')),
                    ],
                    onChanged: (v) => setState(() => _hyper = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _smoker,
                    decoration: const InputDecoration(labelText: 'Smoker Status'),
                    items: const [
                      DropdownMenuItem(value: 'No', child: Text('No')),
                      DropdownMenuItem(value: 'Yes', child: Text('Yes')),
                    ],
                    onChanged: (v) => setState(() => _smoker = v!),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: _height,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Height (cm)'),
                        onChanged: (_) => setState(() {}))),
                const SizedBox(width: 12),
                Expanded(
                    child: TextField(
                        controller: _weight,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Weight (kg)'),
                        onChanged: (_) => setState(() {}))),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _diabetes,
                decoration: const InputDecoration(labelText: 'Diabetes Status'),
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
                  border: Border.all(color: AppColors.blue),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Calculated BMI: ${_bmi.toStringAsFixed(1)} kg/m²',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              const Text('FAMILY EMERGENCY CONTACTS',
                  style: TextStyle(color: AppColors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...widget.profile.contacts.map((c) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(14)),
                    child: Column(children: [
                      TextFormField(
                        initialValue: c.name,
                        decoration: const InputDecoration(labelText: 'Contact Name & Relation'),
                        onChanged: (v) => c.name = v,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: c.phone,
                        decoration: const InputDecoration(labelText: 'Contact Phone Number'),
                        onChanged: (v) => c.phone = v,
                      ),
                    ]),
                  )),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save, 
                  child: const Text('Save Profile Changes')
                ),
              ),
              const SizedBox(height: 24), // Spacing before sign out button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}