import 'package:flutter/material.dart';
import 'package:volume_watcher/volume_watcher.dart';

import 'logger.dart';

class VolumeControl {
  static bool _listenerAdded = false;
  static BuildContext? _context;
  static DateTime? _lastSnackbarTime;

  static Future<void> init(
      {required logFile, required BuildContext context}) async {
    try {
      _context = context;

      if (!_listenerAdded) {
        // Listen for volume changes
        VolumeWatcher.addListener((event) async {
          final newVolume = await VolumeWatcher.getCurrentVolume;
          final maxVolume = await VolumeWatcher.getMaxVolume;

          // Check if volume has been changed by the user
          if (newVolume != 1.0) {
            // Log the change and display a message
            logToFile(
              DateTime.now().toString(),
              'VOLUME_WATCHER',
              'Volume changed by user to $newVolume/$maxVolume',
              logFile,
            );

            // Set volume to maximum
            // await VolumeWatcher.setVolume(1.0);

            // // Log the change and display a message
            // logToFile(
            //   DateTime.now().toString(),
            //   'VOLUME_WATCHER',
            //   'Volume automatically changed back to 1',
            //   logFile,
            // );

            // if (_lastSnackbarTime != null) {
            //   print(DateTime.now().difference(_lastSnackbarTime!));
            // }

            // // Display a snackbar with a message, only if the last snackbar was displayed more than 5 seconds ago
            // if (_lastSnackbarTime == null ||
            //     DateTime.now().difference(_lastSnackbarTime!) >
            //         const Duration(seconds: 2)) {
            //   _lastSnackbarTime = DateTime.now();
            //   showVolumeLockedSnackbar();
            // }
          }
        });

        _listenerAdded = true;
      }
    } catch (e) {
      logToFile(
        DateTime.now().toString(),
        'VOLUME_WATCHER',
        'Error initializing volume control: $e',
        logFile,
      );
    }
  }

  static void showVolumeLockedSnackbar() {
    if (_context != null) {
      ScaffoldMessenger.of(_context!).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.volume_off),
              SizedBox(width: 8),
              Text("Volume verrouillé")
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
