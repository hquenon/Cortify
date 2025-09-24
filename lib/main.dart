import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:external_path/external_path.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import 'home_screen.dart';
import 'audio_player_screen.dart';
import 'playlist_screen.dart';
import 'info_screen.dart';
import 'logger.dart';
import 'volume_control.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request access to storage
  var status = await Permission.storage.request();

  // Get storage directory paths
  var publicPath = await ExternalPath.getExternalStorageDirectories();
  var cortifyPath = "${publicPath[0]}/Cortify";

  // Update playlists before running the app
  final playlists = await loadJsonFile(cortifyPath);
  // final playlists = await makePlaylistsFromCSV(cortifyPath);

  runApp(ChangeNotifierProvider(
    create: (_) => CortifyState(playlists, cortifyPath),
    child: Cortify(
      playlists: playlists,
      cortifyPath: cortifyPath,
    ),
  ));
}

class Cortify extends StatefulWidget {
  const Cortify({
    Key? key,
    required this.playlists,
    required this.cortifyPath,
    // required this.messengerKey
  }) : super(key: key);

  final Map<String, Map<String, dynamic>> playlists;
  final String cortifyPath;
  // late var messengerKey;

  @override
  State<Cortify> createState() => CortifyState(playlists, cortifyPath);
}

class CortifyState extends State<Cortify> with ChangeNotifier {
  File? _logFile;
  // late final GlobalKey<ScaffoldMessengerState> _messengerKey;

  int _currentIndex = 0;

  Map<String, Map<String, dynamic>> playlists;
  String cortifyPath;

  CortifyState(
    this.playlists,
    this.cortifyPath,
    // this._messengerKey,
  );

  @override
  void initState() {
    super.initState();
    _initializeLogFile();
    // _messengerKey.currentState!.showSnackBar(SnackBar(
    //   content: Text('Initializing Cortify...'),
    //   duration: const Duration(seconds: 2),
    // ));
    // VolumeControl.init(logFile: _logFile, context: context);
  }

  Future<void> _initializeLogFile() async {
    // Create the log file and return it
    final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    final logFileName = 'cortify_log_$timestamp.txt';

    final publicPath = await ExternalPath.getExternalStorageDirectories();
    final cortifyLogsPath = "${publicPath[0]}/Cortify/logs";

    // Create the log file if it does not exist
    final logFile = File('$cortifyLogsPath/$logFileName');
    if (!logFile.existsSync()) {
      logFile.createSync(recursive: true);
    }

    // Set up the logger
    Logger.root.level = Level.ALL;
    final logger = Logger('Cortify');

    // Logger.root.level = Level.ALL;

    // Write to console and log file
    logger.onRecord.listen((record) async {
      logFile.writeAsString('${record.time}: ${record.message}\n',
          mode: FileMode.append);
    });

    logToFile(DateTime.now().toString(), 'APPLICATION_STATUS',
        'Launching $widget', logFile);

    // Log device information
    logDeviceInfo(logFile);

    setState(() {
      _logFile = logFile;
    });
  }

  void onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  // This widget is the root of the application.
  @override
  Widget build(BuildContext context) {
    final List<Widget> _children = [
      HomeScreen(
        playlists: playlists,
        cortifyPath: cortifyPath,
        logFile: _logFile,
      ),
      PlaylistScreen(
        selectedStimulusType: '',
        playlists: playlists,
        cortifyPath: cortifyPath,
        logFile: _logFile,
      ),
      AudioPlayerScreen(
        audioFile: '',
        selectedStimulusType: '',
        playlists: playlists,
        cortifyPath: cortifyPath,
        logFile: _logFile,
      ),
      InfoScreen(
        logFile: _logFile,
      ),
    ];

    return _logFile != null
        ? Builder(
            builder: (context) => MaterialApp(
              title: 'Cortify',
              theme: ThemeData(
                // This is the theme of the application.
                primaryColor: const Color(0xFF7D70BA),
                // accentColor: const Color(0xFF90C290),
                scaffoldBackgroundColor: const Color(0xFF343633),
                colorScheme: ColorScheme.fromSwatch(
                  primarySwatch: const MaterialColor(0xFF7D70BA, <int, Color>{
                    50: Color(0xFFECE8F5),
                    100: Color(0xFFC5BFD8),
                    200: Color(0xFF9D94BC),
                    300: Color(0xFF75699E),
                    400: Color(0xFF554C88),
                    500: Color(0xFF342F71),
                    600: Color(0xFF2F2A68),
                    700: Color(0xFF28235C),
                    800: Color(0xFF221F52),
                    900: Color(0xFF16153E),
                  }),

                  backgroundColor:
                      const Color(0xFF343633), // dark grey background
                ),
                textTheme: const TextTheme(
                  displayLarge: TextStyle(color: Colors.white),
                  displayMedium: TextStyle(color: Colors.white),
                  displaySmall: TextStyle(color: Colors.white),
                  headlineLarge: TextStyle(color: Colors.white),
                  headlineMedium: TextStyle(color: Colors.white),
                  headlineSmall: TextStyle(color: Colors.white),
                  titleLarge: TextStyle(color: Colors.white),
                  titleMedium: TextStyle(color: Colors.white),
                  titleSmall: TextStyle(color: Colors.white),
                  bodyLarge: TextStyle(color: Colors.white),
                  bodyMedium: TextStyle(color: Colors.white),
                  bodySmall: TextStyle(color: Colors.white),
                ),
              ),

              // Routes for navigating between screens
              initialRoute: '/',
              routes: {
                HomeScreen.routeName: (context) => HomeScreen(
                      playlists: playlists,
                      cortifyPath: cortifyPath,
                      logFile: _logFile!,
                    ),
                PlaylistScreen.routeName: (context) => PlaylistScreen(
                      selectedStimulusType: '',
                      playlists: playlists,
                      cortifyPath: cortifyPath,
                      logFile: _logFile!,
                    ),
                AudioPlayerScreen.routeName: (context) => AudioPlayerScreen(
                      audioFile: '',
                      selectedStimulusType: '',
                      playlists: playlists,
                      cortifyPath: cortifyPath,
                      logFile: _logFile!,
                    ),
                InfoScreen.routeName: (context) => InfoScreen(
                      logFile: _logFile!,
                    ),
              },
              home: Scaffold(
                body: _children[_currentIndex],
              ),
            ),
          )
        : const Padding(
            padding: EdgeInsets.fromLTRB(150, 300, 150, 300),
            child: CircularProgressIndicator(),
          );
  }
}

Future<Map<String, Map<String, dynamic>>> loadJsonFile(
    String cortifyPath) async {
  final metadataFile = File('$cortifyPath/metadata/metadata.json');
  final contents = await metadataFile.readAsString();
  final jsonMap = json.decode(contents);

  final metadata = <String, Map<String, dynamic>>{};
  for (final key in jsonMap.keys) {
    final Map<String, dynamic> value = jsonMap[key];
    metadata[key] = value.cast<String, dynamic>();
  }
  return metadata;
}



// Future<Map<String, Map<String, dynamic>>> makePlaylistsFromCSV(
//     String cortifyMediaPath) async {
//   final Map<String, Map<String, dynamic>> playlists = {};
//   final metadataFile = File('$cortifyMediaPath/metadata/metadata.csv');
//   final contents = await metadataFile.readAsString(encoding: latin1);

//   // Extract the header row to get the index of each column
//   final List<String> headerRow =
//       contents.substring(0, contents.indexOf('\n')).split(',');

//   // Iterate over each line in the CSV file
//   for (final line in contents.split('\n').skip(1)) {
//     final List<String> rowValues = line.split(',');
//     final Map<String, String> mediaMetadata = {};
//     for (var i = 0; i < headerRow.length && i < rowValues.length; i++) {
//       mediaMetadata[headerRow[i]] = rowValues[i];
//     }

//     // Extract the fields from the row
//     final String filename = mediaMetadata['filename']!;
//     final String stimType = mediaMetadata['stim_type']!;

//     // final String artist = mediaMetadata['artist']!;
//     // final String title = mediaMetadata['title']!;
//     // final String album = mediaMetadata['album']!;
//     // final String albumCover = mediaMetadata['album_cover']!;
//     // final double duration = double.parse(mediaMetadata['duration']!);
//     // final String format = mediaMetadata['format']!;
//     // final int channels = int.parse(mediaMetadata['channels']!);
//     // final double bitrate = double.parse(mediaMetadata['bitrate']!);
//     // final double audioOffset = double.tryParse(mediaMetadata['audio_offset']!) ?? 0;
//     // final int filesize = int.parse(mediaMetadata['filesize']!);
//     // final int samplerate = int.parse(mediaMetadata['samplerate']!);

//     // If this is the first time we've encountered this stimulus type, add it to the playlist Map.
//     playlists[stimType] ??= {};

//     // Add this audio file to the playlist for this stimulus type
//     playlists[stimType]![filename] = {
//       "filename": filename,
//       "title": mediaMetadata['title']!,
//       "artist": mediaMetadata['artist']!,
//       "album": mediaMetadata['album']!,
//       "album_cover": mediaMetadata['album_cover']!,
//       "duration": double.parse(mediaMetadata['duration']!),
//       "format": mediaMetadata['format']!,
//       "channels": int.parse(mediaMetadata['channels']!),
//       "bitrate": double.parse(mediaMetadata['bitrate']!),
//       "audio_offset": double.tryParse(mediaMetadata['audio_offset']!),
//       "filesize": double.parse(mediaMetadata['filesize']!),
//       "samplerate": double.parse(mediaMetadata['samplerate']!),
//     };
//   }

//   return playlists;
// }
