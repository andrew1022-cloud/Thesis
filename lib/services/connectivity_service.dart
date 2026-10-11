import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// ConnectivityService
/// -------------------
/// Tells the UI whether the app can currently reach Firebase, without
/// adding a new package.
///
/// It keeps one tiny Firestore listener open (`subjects`, limit 1, with
/// metadata changes). Firestore marks a snapshot `isFromCache` when it
/// can't reach the server, so:
///   - from-cache for more than [_offlineDelay]  -> offline
///   - a server-confirmed snapshot               -> online
/// The delay avoids a flicker at startup, when Firestore always emits
/// the cached copy first. The listener only costs reads when the data
/// actually changes.
///
/// [checkNow] does a one-off server read for "am I really online?"
/// (used before downloading content).
class ConnectivityService {
  ConnectivityService._internal();
  static final ConnectivityService instance = ConnectivityService._internal();

  static const Duration _offlineDelay = Duration(seconds: 5);

  /// true = online (or unknown), false = offline.
  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  Timer? _offlineTimer;

  /// Safe to call repeatedly. Call after the user signs in.
  void start() {
    if (_sub != null) return;
    _sub = FirebaseFirestore.instance
        .collection('subjects')
        .limit(1)
        .snapshots(includeMetadataChanges: true)
        .listen(
      _onSnapshot,
      onError: (Object e) {
        // e.g. permission-denied right after sign-out. Not a network
        // problem, so don't flip to offline.
        debugPrint('ConnectivityService: listener error: $e');
      },
    );
  }

  /// Call on logout.
  void stop() {
    _sub?.cancel();
    _sub = null;
    _offlineTimer?.cancel();
    _offlineTimer = null;
    _set(true);
  }

  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    if (snap.metadata.isFromCache) {
      _offlineTimer ??= Timer(_offlineDelay, () {
        _offlineTimer = null;
        _set(false);
      });
    } else {
      _offlineTimer?.cancel();
      _offlineTimer = null;
      _set(true);
    }
  }

  void _set(bool value) {
    if (isOnline.value != value) isOnline.value = value;
  }

  /// One-off check against the server. Returns true if reachable.
  Future<bool> checkNow() async {
    try {
      await FirebaseFirestore.instance
          .collection('subjects')
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 6));
      _set(true);
      return true;
    } on FirebaseException catch (e) {
      // permission-denied etc. still means the server answered.
      final reachable = e.code != 'unavailable' && e.code != 'deadline-exceeded';
      _set(reachable);
      return reachable;
    } catch (_) {
      _set(false);
      return false;
    }
  }
}
