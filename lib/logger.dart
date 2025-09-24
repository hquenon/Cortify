import 'dart:io';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:device_info/device_info.dart';
import 'package:volume_watcher/volume_watcher.dart';

// Define a function that returns the log file
Future<File> getLogFile(String logsDir, String logFileName) async {
  // var logsDir = await getApplicationDocumentsDirectory();
  return File('$logsDir/$logFileName').create(recursive: true);
}

// Define a function that writes logs to the file
void logToFile(timestamp, String category, String message, File logFile) {
  String logMessage = '$timestamp: $category: $message';
  print(logMessage);
  logFile.writeAsStringSync('$logMessage\n', mode: FileMode.append);
}

// Define a function that sets up the logger
Future<File> setupLogger(String logsDir, String logFileName) async {
  var logFile = await getLogFile(logsDir, logFileName);

  // // Set the log level
  // Logger.root.level = Level.ALL;

  // // Write to console and log file
  // Logger.root.onRecord.listen((record) async {
  //   logToFile(record.time, record.message, logFile);
  // });

  // Log device information
  logDeviceInfo(logFile);

  logToFile(DateTime.now().toString(), 'APPLICATION_STATUS',
      'Starting the app...', logFile);

  return logFile;
}

// Log some device information
void logDeviceInfo(File logFile) async {
  var deviceInfo = await DeviceInfoPlugin().androidInfo;
  final volume = await VolumeWatcher.getCurrentVolume;
  final volumeLevel = volume.toInt();

  logToFile(DateTime.now().toString(), 'DEVICE_ID', '${deviceInfo.androidId}',
      logFile);
  logToFile(DateTime.now().toString(), 'DEVICE_MODEL',
      '${deviceInfo.model} (${deviceInfo.device})', logFile);
  logToFile(
      DateTime.now().toString(),
      'OS_VERSION',
      'OS: ${deviceInfo.version.release} (SDK ${deviceInfo.version.sdkInt})',
      logFile);
  logToFile(DateTime.now().toString(), 'VOLUME_LEVEL',
      'Device volume set to: $volumeLevel', logFile);
}
