import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'playlist_screen.dart';
import 'logger.dart';
import 'volume_control.dart';
import 'info_screen.dart';

class HomeScreen extends StatefulWidget {
  static const routeName = '/home-screen';
  final Map<String, Map<String, dynamic>> playlists;
  final String cortifyPath;
  final logFile;

  const HomeScreen({
    super.key,
    required this.playlists,
    required this.cortifyPath,
    required this.logFile,
  });

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    logToFile(DateTime.now().toString(), 'SCREEN_MANAGER',
        'Initialization of $widget', widget.logFile);

    // VolumeControl.init(logFile: widget.logFile);
  }

  @override
  void dispose() {
    super.dispose();
    // logToFile(DateTime.now().toString(), 'SCREEN_MANAGER',
    //    '$widget is disposed', widget.logFile);
  }

  // Define the icons for the stimulus types
  final stimTypeIcons = {
    'Musique': Icons.music_note,
    'Audiobooks': Icons.menu_book,
    'Podcasts': Icons.mic,
    'Vidéos': Icons.movie,
    'Tasks': Icons.spatial_audio_sharp
  };

  late final Map<String, bool> disabledStimulusTypes = Map.fromIterable(
    stimTypeIcons.keys,
    value: (_) => true,
  );

  late String selectedStimulusType = '';

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Loop through all the stimulus types and update the disabledStimulusTypes map
    for (final type in widget.playlists.keys) {
      // If a playlist is empty, set the corresponding stimulus type to be disabled
      disabledStimulusTypes[type] = widget.playlists[type]?.isEmpty ?? true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Initialize volume watcher
    VolumeControl.init(logFile: widget.logFile, context: context);

    // Load the playlists when the HomeScreen is initialized
    // final cortstate = context.watch<CortifyState>;
    final playlists = widget.playlists;

    // Update the disabledStimulusTypes map when the playlists change
    for (final type in playlists.keys) {
      disabledStimulusTypes[type] = playlists[type]?.isEmpty ?? true;
    }

    final audiobookAlbums = playlists["Audiobooks"]
        ?.values // Get the values of each audiobook
        .map((file) => file['album']) // Get the album of each audiobook
        .toSet() // Convert to a set to remove duplicates
        .length; // Get the number of unique albums

    return Scaffold(
      backgroundColor: theme.colorScheme.background,

      // Create the top bar with info button
      appBar: AppBar(
        backgroundColor: theme.primaryColor,
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 30.0),
            child: IconButton(
              icon: const Icon(
                Icons.info,
                color: Colors.white,
                size: 25,
              ),
              onPressed: () {
                // Display information screen
                Navigator.pushNamed(context, InfoScreen.routeName,
                    arguments: widget.logFile);
              },
            ),
          ),
        ],
        centerTitle: true,
        elevation: 2,
      ),

      body: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(30, 30, 30, 0),
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(),
                  child: Align(
                    alignment: const AlignmentDirectional(0, 0.05),
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(),
                      child: Align(
                        alignment: const AlignmentDirectional(0, 0),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            const Spacer(),

                            // CORTIFY LOGO
                            Align(
                              alignment: const AlignmentDirectional(0, 0.05),
                              child: Padding(
                                padding: const EdgeInsetsDirectional.fromSTEB(
                                    0, 60, 0, 60),
                                child: Image.asset(
                                  'assets/images/icons/cortify_purple.png',
                                  width: double.infinity,
                                  height: 145,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),

                            // SLOGAN
                            const Padding(
                              padding:
                                  EdgeInsetsDirectional.fromSTEB(0, 0, 0, 30),
                              child: Text(
                                'Aidez la recherche en vous divertissant !',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontFeatures: [FontFeature.enable('smcp')],
                                ),
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // LIST OF STIMULUS TYPES
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(30, 0, 30, 30),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: stimTypeIcons.keys.map((type) {
                    final playlist = playlists[type];

                    // BUTTONS
                    return Expanded(
                      flex: 1,
                      child: InkWell(
                        // Behavior when pressed
                        onTap: disabledStimulusTypes[type]!
                            ? null
                            : () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) => PlaylistScreen(
                                    selectedStimulusType: type,
                                    playlists: widget.playlists,
                                    cortifyPath: widget.cortifyPath,
                                    logFile: widget.logFile,
                                  ),
                                ));
                              },

                        // Button design
                        child: Container(
                          width: double.infinity,
                          height: 60,
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white.withOpacity(0.15),
                          ),
                          foregroundDecoration: BoxDecoration(
                            color: disabledStimulusTypes[type]!
                                ? Colors.grey.withOpacity(0.5)
                                : null,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              // ICON
                              Icon(
                                stimTypeIcons[type],
                                size: 30,
                              ),
                              const SizedBox(width: 20),

                              // STIMULUS TYPE
                              Text(
                                type,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),

                              // NUMBER OF AVAILABLE FILES
                              if (disabledStimulusTypes[type] == true)
                                const Text(
                                  '(Aucun fichier disponible...)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontStyle: FontStyle.italic,
                                  ),
                                )
                              else if (type == 'Audiobooks')
                                Text(
                                  '(${audiobookAlbums} livres)',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              else if (type == 'Musique')
                                Text(
                                  '(${playlist?.length} titres)',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              else if (type == 'Vidéos')
                                Text(
                                  '(${playlist?.length} vidéos)',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              else
                                (Text(
                                  '(${playlist?.length} épisodes)',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                )),
                              const SizedBox(width: 10),
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
