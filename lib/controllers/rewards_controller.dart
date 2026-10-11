import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../data/level_data.dart';
import '../data/unlockable_data.dart';

/// Holds all state for the Rewards screen. Unlocks are automatic (by
/// level), so the only thing stored is which frame / flair the user
/// has equipped: `users/{uid}.equippedFrame` and `.equippedFlair`.
class RewardsController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String uid;

  RewardsController({required this.uid});

  bool _disposed = false;

  bool isLoading = true;
  int points = 0;
  String? equippedFrameId;
  String? equippedFlairId;

  UserLevel get level => levelForPoints(points);

  Future<void> load() async {
    isLoading = true;
    notifyListeners();

    if (uid.isNotEmpty) {
      try {
        final doc = await _firestore.collection('users').doc(uid).get();
        final data = doc.data();
        points = ((data?['points'] ?? 0) as num).toInt();
        equippedFrameId = data?['equippedFrame'] as String?;
        equippedFlairId = data?['equippedFlair'] as String?;
      } catch (e) {
        debugPrint('RewardsController: failed to load: $e');
      }
    }

    isLoading = false;
    notifyListeners();
  }

  bool isUnlocked(Unlockable item) => level.number >= item.requiredLevel;

  bool isEquipped(Unlockable item) {
    final current = item.type == UnlockableType.frame
        ? (equippedFrameId ?? 'frame_plain')
        : (equippedFlairId ?? 'flair_none');
    return current == item.id;
  }

  /// Returns an error/info message to show, or null on success.
  Future<String?> equip(Unlockable item) async {
    if (!isUnlocked(item)) {
      final needed = kLevels[(item.requiredLevel - 1)
          .clamp(0, kLevels.length - 1)];
      return 'Reach Lv. ${needed.number} (${needed.title}) to unlock '
          '${item.name}.';
    }

    final isFrame = item.type == UnlockableType.frame;
    final previous = isFrame ? equippedFrameId : equippedFlairId;

    if (isFrame) {
      equippedFrameId = item.id;
    } else {
      equippedFlairId = item.id;
    }
    notifyListeners();

    try {
      await _firestore.collection('users').doc(uid).set(
        {isFrame ? 'equippedFrame' : 'equippedFlair': item.id},
        SetOptions(merge: true),
      );
      return null;
    } catch (e) {
      debugPrint('RewardsController: failed to equip: $e');
      if (isFrame) {
        equippedFrameId = previous;
      } else {
        equippedFlairId = previous;
      }
      notifyListeners();
      return "Couldn't save that. Check your connection and try again.";
    }
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
