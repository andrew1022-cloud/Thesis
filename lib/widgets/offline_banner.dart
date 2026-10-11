import 'package:flutter/material.dart';

import '../services/connectivity_service.dart';

/// Slim "You're offline" strip. Collapses to nothing when online.
///
/// Deliberately imports nothing from home_widgets.dart (it's used
/// inside HomeBottomNavBar, which lives there), so it carries its own
/// colors.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  static const Color _amber = Color(0xFFB26A00);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService.instance.isOnline,
      builder: (context, online, _) {
        return AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.bottomCenter,
          child: online
              ? const SizedBox(width: double.infinity)
              : Container(
                  width: double.infinity,
                  color: _amber,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off_rounded,
                          color: Colors.white, size: 14),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          "You're offline — showing downloaded content",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
