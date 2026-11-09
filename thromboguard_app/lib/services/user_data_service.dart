import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';

/// Firestore layout:
///   users/{uid}                 -> username, email, createdAt, profile{...}
///   users/{uid}/readings/{id}   -> one document per saved VitalReading
///
/// Note: with offline persistence on, a write's Future may not complete until
/// the server acknowledges it. So callers use a timeout: the write stays
/// queued locally and syncs by itself when the connection returns.
class UserDataService {
  static final _db = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid == null ? null : _db.collection('users').doc(uid);
  }

  static Future<String?> loadUsername() async {
    final doc = _userDoc;
    if (doc == null) return null;
    try {
      final snap = await doc.get().timeout(const Duration(seconds: 3));
      return snap.data()?['username'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Returns null if the user has not completed onboarding yet.
  static Future<PatientProfile?> loadProfile() async {
    final doc = _userDoc;
    if (doc == null) return null;
    final snap = await doc.get();
    final data = snap.data();
    if (data == null || data['profile'] == null) return null;
    return PatientProfile.fromMap(Map<String, dynamic>.from(data['profile'] as Map));
  }

  static Future<void> saveProfile(PatientProfile p) async {
    final doc = _userDoc;
    if (doc == null) throw StateError('Not signed in');
    await doc
        .set({'profile': p.toMap(), 'profileUpdatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true))
        .timeout(const Duration(seconds: 8), onTimeout: () {});
  }

  static Future<void> saveReading(VitalReading r) async {
    final doc = _userDoc;
    if (doc == null) return;
    try {
      await doc.collection('readings').add(r.toMap()).timeout(const Duration(seconds: 8), onTimeout: () => throw TimeoutException('save'));
    } catch (_) {
      // Non-fatal: the reading is already in the on-screen log.
    }
  }

  /// Audit log of emergency events (cancelled / alert opened).
  static Future<void> saveEmergency(Map<String, dynamic> data) async {
    final doc = _userDoc;
    if (doc == null) return;
    try {
      await doc
          .collection('emergencies')
          .add({...data, 'createdAt': FieldValue.serverTimestamp()})
          .timeout(const Duration(seconds: 8), onTimeout: () => throw TimeoutException('save'));
    } catch (_) {}
  }

  static Future<List<VitalReading>> loadRecentReadings({int limit = 50}) async {
    final doc = _userDoc;
    if (doc == null) return [];
    final q = await doc.collection('readings').orderBy('timestamp', descending: true).limit(limit).get();
    return q.docs.map((d) => VitalReading.fromMap(d.data())).toList();
  }
}
