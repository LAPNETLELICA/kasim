import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import '../providers/selected_services_provider.dart';

class SessionController {
  final Ref ref;

  SessionController(this.ref);

  Future<void> activateLock(String sessionId) async {
    final selectedServicesNotifier = ref.read(selectedServicesProvider.notifier);
    final allowedHosts = selectedServicesNotifier.flatHostList;

    // Update Firestore session document
    await FirebaseFirestore.instance.collection('sessions').doc(sessionId).update({
      'allowedHosts': allowedHosts,
      'lockActivated': true,
      'lockTimestamp': FieldValue.serverTimestamp(),
    });

    // Push to RTDB for agents
    final rtdbRef = FirebaseDatabase.instance.ref('sessions/$sessionId');
    await rtdbRef.update({
      'command': 'LOCK',
      'allowedHosts': allowedHosts,
      'timestamp': ServerValue.timestamp,
    });
  }

  Future<void> deactivateLock(String sessionId) async {
    // Update Firestore
    await FirebaseFirestore.instance.collection('sessions').doc(sessionId).update({
      'lockActivated': false,
      'unlockTimestamp': FieldValue.serverTimestamp(),
    });

    // Push to RTDB
    final rtdbRef = FirebaseDatabase.instance.ref('sessions/$sessionId');
    await rtdbRef.update({
      'command': 'UNLOCK',
      'timestamp': ServerValue.timestamp,
    });
  }
}

final sessionControllerProvider = Provider((ref) => SessionController(ref));