import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
// import 'package:video_thumbnail/video_thumbnail.dart';

import 'audio_player_screen.dart';
import 'video_player_screen.dart';
import 'logger.dart';
import 'volume_control.dart';
import 'info_screen.dart';

class PlaylistScreen extends StatefulWidget {
  static const routeName = '/playlist-screen';

  final String selectedStimulusType;
  final Map<String, Map<String, dynamic>> playlists;
  final String cortifyPath;
  final logFile;

  const PlaylistScreen(
      {super.key,
      required this.playlists,
      required this.selectedStimulusType,
      required this.cortifyPath,
      required this.logFile});

  @override
  _PlaylistScreenState createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  // Define class variables
  late String selectedStimulusType = '';
  late String selection = '';
  late List<String> stimTypes = [];
  late Map<String, Map<String, dynamic>> playlists = {};
  late String _cortifyPath = '';

  @override
  void initState() {
    super.initState();

    selectedStimulusType = widget.selectedStimulusType;
    _cortifyPath = widget.cortifyPath;

    logToFile(DateTime.now().toString(), 'SCREEN_MANAGER',
        'Initialization of $widget', widget.logFile);

    // VolumeControl.init(logFile: widget.logFile);
  }

  @override
  void dispose() {
    super.dispose();

    // logToFile(DateTime.now().toString(), 'SCREEN_MANAGER',
    //     '$widget is disposed', widget.logFile);
  }

  Future<void> makeSelection(String albumOrArtistSelected) async {
    // Update state variable selection
    setState(() {
      selection = albumOrArtistSelected;
    });
  }

  Future<void> screenChanger(
      BuildContext context, String selectedStimulusType, String file) async {
    // Record button press
    logToFile(
      DateTime.now().toString(),
      'USER_ACTION',
      'File selected: $file',
      widget.logFile,
    );

    if (selectedStimulusType == "Vidéos") {
      // Navigate to the VideoPlayerScreen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(
            videoFile: file,
            selectedStimulusType: selectedStimulusType,
            playlists: widget.playlists,
            cortifyPath: widget.cortifyPath,
            logFile: widget.logFile,
          ),
        ),
      );
    } else {
      // Navigate to the AudioPlayerScreen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AudioPlayerScreen(
            audioFile: file,
            selectedStimulusType: selectedStimulusType,
            playlists: widget.playlists,
            cortifyPath: widget.cortifyPath,
            logFile: widget.logFile,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the app's theme data
    final theme = Theme.of(context);

    final playlists = widget.playlists;

    // print(playlists);
    // print(selectedStimulusType);

    // Build the list of media files for the selected stimulus type
    final mediaFiles = playlists[selectedStimulusType]!.keys.toList();
    final albums = mediaFiles
        .map((file) => playlists[selectedStimulusType]![file]['album'])
        .toSet()
        .toList();
    final artists = mediaFiles
        .map((file) => playlists[selectedStimulusType]![file]['artist'])
        .toSet()
        .toList();

    String groupby = '';
    List<dynamic> group = [];

    if (selectedStimulusType == "Audiobooks" ||
        selectedStimulusType == "Tasks" ||
        selectedStimulusType == "Podcasts") {
      groupby =
          "album"; // Set the grouping criteria to "album" if the stimulus type is "Audiobooks"
      group = albums; // Set group to albums
      if (selection.isNotEmpty) {
        print("Sélection actuelle : $selection");
        print("Fichiers avant filtrage : $mediaFiles");
        // If there is a selection, remove media files from the list that don't match the selected album
        mediaFiles.removeWhere((file) =>
            playlists[selectedStimulusType]![file]["album"] != selection);
        print("Fichiers après filtrage : $mediaFiles");
      }
    } else if (selectedStimulusType == "Musique") {
      groupby =
          "artist"; // Set the grouping criteria to "artist" if the stimulus type is "Musique"
      group = artists; // Set group to artists
      if (selection.isNotEmpty) {
        // If there is a selection, remove media files from the list that don't match the selected artist
        mediaFiles.removeWhere((file) =>
            playlists[selectedStimulusType]![file]["artist"] != selection);
      }
    }

    // Sort the group list based on the priority metadata
    group.sort((a, b) {
      final isAPriority = mediaFiles.any((file) =>
          playlists[selectedStimulusType]![file][groupby] == a &&
          playlists[selectedStimulusType]![file]['priority'] == true);
      final isBPriority = mediaFiles.any((file) =>
          playlists[selectedStimulusType]![file][groupby] == b &&
          playlists[selectedStimulusType]![file]['priority'] == true);

      if (isAPriority && !isBPriority) {
        return -1; // a goes before b
      } else if (!isAPriority && isBPriority) {
        return 1; // b goes before a
      } else {
        return 0; // no change
      }
    });

    // Trier les fichiers en fonction de la priorité
    mediaFiles.sort((a, b) {
      final priorityA =
          playlists[selectedStimulusType]![a]['priority'] ?? false;
      final priorityB =
          playlists[selectedStimulusType]![b]['priority'] ?? false;

      if (priorityA && !priorityB) {
        return -1; // a avec priorité avant b
      } else if (!priorityA && priorityB) {
        return 1; // b avec priorité avant a
      } else {
        return 0; // pas de changement si les priorités sont les mêmes
      }
    });

    // If no selection was made yet, build a list of albums/artists to select from
    if ((selectedStimulusType == "Audiobooks" ||
            selectedStimulusType == "Podcasts" ||
            selectedStimulusType == "Tasks" ||
            selectedStimulusType == "Musique") &&
        selection.isEmpty) {
      return Scaffold(
        backgroundColor: theme.colorScheme.background,
        appBar: AppBar(
          backgroundColor: theme.primaryColor,
          leading: Padding(
            padding: const EdgeInsets.only(left: 30.0),
            child: IconButton(
              icon: Icon(Icons.home), // change the icon here
              onPressed: () => Navigator.pop(
                  context), // navigate back when the icon is pressed
            ),
          ),
          title: Text(
            selectedStimulusType, // Set the title of the app bar to the selected stimulus type
          ),
          centerTitle: true,
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
                  // When the info button is pressed, navigate to the information screen
                  Navigator.pushNamed(context, InfoScreen.routeName,
                      arguments: widget.logFile);
                },
              ),
            ),
          ],
          elevation: 2,
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (selectedStimulusType == "Musique")
                const ListTile(
                  title: Padding(
                    padding: EdgeInsets.fromLTRB(30, 2, 30, 2),
                    child: Text(
                      "Artistes",
                      // style: TextStyle(fontSize: 18),
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  tileColor: Color.fromARGB(255, 44, 46, 43),
                ),
              // const Divider(
              //     height: 1,
              //     color: Colors.grey), // Divider for visual separation
              // Container(
              //   height: 5,
              // ),

              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(
                      0, 0, 0, 50), // Padding for the container
                  child: ListView.builder(
                    itemCount: group.length,
                    itemBuilder: (ctx, index) {
                      // For each index, create a list tile for the corresponding album/artist
                      final artistOrAlbumSelected = group[index];
                      final numChapters = mediaFiles
                          .where((file) =>
                              playlists[selectedStimulusType]![file][groupby] ==
                              artistOrAlbumSelected)
                          .length;
                      final representativeMediaFile = mediaFiles.firstWhere(
                        (file) =>
                            playlists[selectedStimulusType]![file][groupby] ==
                            artistOrAlbumSelected,
                      );
                      // cam Vérifie si la propriété 'priority' est vraie dans les métadonnées
                      Color tileColor;
                      if (playlists[selectedStimulusType]![
                              representativeMediaFile]['priority'] ==
                          true) {
                        tileColor = Color(0xFF9D94BC);
                      } else {
                        tileColor = Color.fromARGB(255, 51, 53, 49);
                      }

                      print(
                          "Album cover from audio file: ${playlists[selectedStimulusType]![representativeMediaFile]['filename']}");
                      print(
                          "Path: $_cortifyPath/images/album_covers/${playlists[selectedStimulusType]![representativeMediaFile]['album_cover']}");

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(30, 0, 30, 0),
                        child: Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                  0,
                                  (selectedStimulusType == "Musique") ? 6 : 2,
                                  0,
                                  (selectedStimulusType == "Musique") ? 6 : 2),
                              child: ListTile(
                                leading: Container(
                                  // The leading widget is a container with the album cover as a background image
                                  decoration: BoxDecoration(
                                    image: DecorationImage(
                                      image: playlists[selectedStimulusType]![
                                                          representativeMediaFile]
                                                      ['album_cover'] !=
                                                  null &&
                                              File("$_cortifyPath/images/album_covers/${playlists[selectedStimulusType]![representativeMediaFile]['album_cover']}")
                                                  .existsSync()
                                          ? FileImage(File(
                                              "$_cortifyPath/images/album_covers/${playlists[selectedStimulusType]![representativeMediaFile]['album_cover']}"))
                                          : const AssetImage(
                                                  'assets/images/icons/play-circle.png')
                                              as ImageProvider<Object>,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  width: 50.0,
                                  height: 50.0,
                                ),
                                tileColor: tileColor,
                                title: Text(
                                  artistOrAlbumSelected, // The title of the ListTile is the selected artist or album
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                // The subtitle of the ListTile is null for "Musique", but for other stimulus types it displays the artist name
                                subtitle: selectedStimulusType == "Musique"
                                    ? null
                                    : Text(playlists[selectedStimulusType]![
                                                representativeMediaFile]
                                            ['artist'] ??
                                        ''),
                                trailing: Text(
                                    selectedStimulusType == "Audiobooks"
                                        ? '($numChapters chapitres)'
                                        : '($numChapters titres)'),
                                onTap: () =>
                                    makeSelection(artistOrAlbumSelected),
                              ),
                            ),
                            const Divider(
                              height: 1,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      // If not Audiobooks or Musique or if it is and an album has been selected:
    } else {
      print('Selected Stimulus Type: $selectedStimulusType');
      print('Groupby: $groupby');
      print('Group: $group');
      print('Media Files: $mediaFiles');

      return Scaffold(
        backgroundColor: theme.colorScheme.background,
        appBar: AppBar(
          backgroundColor: theme.primaryColor,
          leading: Padding(
            padding: const EdgeInsets.only(left: 30.0),
            child: IconButton(
              icon: Icon(Icons.home), // change the icon here
              onPressed: () => Navigator.pop(
                  context), // navigate back when the icon is pressed
            ),
          ),
          title: Text(
            selectedStimulusType,
          ),
          centerTitle: true,
          // automaticallyImplyLeading: false,
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
          // centerTitle: true,
          elevation: 2,
        ),

        // List of items
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    // Positioned widget to create a list of albums
                    Positioned(
                      top:
                          0.0, // This list is positioned at the top of the stack
                      left: 0.0,
                      right: 0.0,
                      child: (["Audiobooks", "Tasks", "Musique", "Podcasts"])
                              .contains(selectedStimulusType)
                          ? Column(
                              children: [
                                ListTile(
                                  tileColor: Color.fromARGB(255, 44, 46, 43),
                                  title: Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(30, 4, 30, 4),
                                    child: Text(
                                      // The title of the list item depends on the current selection and stimulus type
                                      selection.isNotEmpty ? selection : '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  trailing: selection.isNotEmpty
                                      ? Padding(
                                          padding:
                                              const EdgeInsets.only(right: 8.0),
                                          child: IconButton(
                                            // If a selection has been made, show an icon button to clear the selection
                                            icon: const Icon(
                                              Icons.arrow_back,
                                              color: Colors.white,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                selection = '';
                                              });
                                            },
                                          ),
                                        )
                                      : null, // If no selection has been made, do not show a button
                                ),
                                // Container(
                                //   height: 5,
                                // ),
                                // const Divider(
                                //     height: 1,
                                //     color: Colors
                                //         .grey), // Divider for visual separation
                              ],
                            )
                          : Container(),
                    ),
                    // Positioned widget to create a list of files
                    Positioned(
                      top: (["Audiobooks", "Tasks", "Musique", "Podcasts"])
                              .contains(selectedStimulusType)
                          ? 60.0
                          : 0.00, // This offsets the list of files from the top by 60.0 pixels to make room for the album list
                      bottom: 0.0,
                      left: 0.0,
                      right: 0.0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(
                            0, 0, 0, 50), // Padding for the list of files
                        // cam : peut être plutot change rici pour que priority = true soit en haut ?? ==> oui !
                        child: ListView.builder(
                          itemCount: mediaFiles.length,
                          itemBuilder: (ctx, index) {
                            // Builder function to create each item in the list
                            final mediaFile = mediaFiles[
                                index]; // Get the media file at this index
                            // Change color if priority = True
                            final isPriority =
                                playlists[selectedStimulusType]![mediaFile]
                                        ['priority'] ??
                                    false;
                            final tileColor = isPriority
                                ? Color(0xFF9D94BC)
                                : Color.fromARGB(255, 51, 53, 49);

                            return Padding(
                              padding: const EdgeInsets.fromLTRB(30, 2, 30, 2),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Use a FutureBuilder to build the list item when the future completes
                                  FutureBuilder<List<Widget>>(
                                    future: _buildAudioListItem(
                                        context,
                                        playlists[selectedStimulusType]![
                                            mediaFile]),
                                    builder: (BuildContext context,
                                        AsyncSnapshot<List<Widget>> snapshot) {
                                      // If the future has completed with data, return a column with the data
                                      if (snapshot.hasData) {
                                        return Container(
                                          color:
                                              tileColor, // Appliquer la couleur de la tile ici
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: snapshot.data!,
                                          ),
                                        );
                                      } else {
                                        // If the future has not completed yet, return an empty container
                                        return Container();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  // Create a list of audio items for each media file
  Future<List<Widget>> _buildAudioListItem(
    BuildContext context,
    Map<String, dynamic> audioFile,
  ) async {
    // Extract the audio metadata from the audio file
    final title = audioFile['title'] ?? '';
    final album = audioFile['album'] ?? '';
    final artist = audioFile['artist'] ?? '';
    final filename = audioFile['filename'] ?? '';
    var audioImage = const AssetImage('assets/images/icons/play-circle.png')
        as ImageProvider<Object>;

    // Determine the audio data to display based on the selected stimulus type
    final stimulusType = widget.selectedStimulusType;
    late String primaryLabel;
    late String secondaryLabel;

    // Convert the duration from seconds to a Duration object
    Duration duration = Duration(seconds: audioFile['duration'].floor());
    // Format the duration as H:mm:ss or mm:ss if H is zero
    String formattedDuration = duration.inHours > 0
        ? '${duration.inHours}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}'
        : '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

    //modifier pour que les titres aussi apparaissent en violet !

    // AUDIO
    if (["Audiobooks", "Tasks", "Musique", "Podcasts"].contains(stimulusType)) {
      if (stimulusType == "Audiobooks" ||
          stimulusType == "Podcasts" ||
          stimulusType == "Tasks") {
        primaryLabel = '$title';
        secondaryLabel = artist;
      } else if (stimulusType == "Musique") {
        primaryLabel = title;
        if (album.isNotEmpty) {
          secondaryLabel = album;
        } else {
          secondaryLabel = '';
        }
      }

      String albumImageName =
          "${audioFile['album']}.jpg"; // replace .jpg with your actual image file extension

      print("Album cover from audio file: ${audioFile['album_cover']}");
      print(
          "Path 1: $_cortifyPath/images/album_covers/${audioFile['album_cover']}");
      print("Path 2: $_cortifyPath/images/album_covers/$albumImageName");

      audioImage = (audioFile['album_cover'] != null &&
              File("$_cortifyPath/images/album_covers/${audioFile['album_cover']}")
                  .existsSync())
          ? FileImage(File(
              "$_cortifyPath/images/album_covers/${audioFile['album_cover']}"))
          : (File("$_cortifyPath/images/album_covers/$albumImageName")
                      .existsSync()
                  ? FileImage(
                      File("$_cortifyPath/images/album_covers/$albumImageName"))
                  : const AssetImage('assets/images/icons/play-circle.png'))
              as ImageProvider<Object>;

      // print(audioImage)

      // VIDEOS
    } else if (stimulusType == "Vidéos") {
      primaryLabel = title;
      secondaryLabel = album.isNotEmpty ? album : '';

      // Use the formatted duration as the secondary label
      // secondaryLabel = formattedDuration;

      // Extract the thumbnail image using the video_thumbnail package
      // final randomPosition = Random().nextInt(duration.inMilliseconds);
      // final thumbnailPath = await VideoThumbnail.thumbnailFile(
      //  video: '$_cortifyPath/media/Vidéos/${audioFile['filename']}',
      //  thumbnailPath: '$_cortifyPath/images/video_thumbnails',
      //  imageFormat: ImageFormat.PNG,
      //  maxWidth:
      //      128, // specify the width of the thumbnail, let the height auto-scaled to keep the source aspect ratio
      //  timeMs: randomPosition,
      //  quality: 75,
      //);

      // Compute the thumbnail filename
      String videoFilenameWithoutExtension = audioFile['filename']
          .substring(0, audioFile['filename'].lastIndexOf('.'));
      String thumbnailFilename = videoFilenameWithoutExtension + '.jpg';
      print(thumbnailFilename);

      // Construct the thumbnail path
      String thumbnailPath =
          '$_cortifyPath/images/video_thumbnails/$thumbnailFilename';

      // Use the thumbnail as the ImageProvider
      audioImage = FileImage(File(thumbnailPath)) as ImageProvider<Object>;
    } else {
      primaryLabel = title.isNotEmpty ? title : filename;
      // secondaryLabel = album.isNotEmpty ? album : '';
    }

    // Create and return the list tile widget for the audio file
    if (secondaryLabel.isEmpty) {
      return [
        ListTile(
          leading: Container(
            decoration: BoxDecoration(
              // borderRadius: BorderRadius.circular(4.0),
              image: DecorationImage(
                image: audioImage,
                fit: BoxFit.cover,
              ),
            ),
            width: selectedStimulusType == "Vidéos" ? 66.666 : 50.0,
            height: 50.0,
          ),
          title: Text(
            primaryLabel,
            style: const TextStyle(color: Colors.white),
          ),
          onTap: () => screenChanger(
            context,
            widget.selectedStimulusType,
            audioFile['filename'],
          ),
          trailing: Text(
            formattedDuration,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
        const Divider(height: 1, color: Colors.grey),
      ];
    } else {
      return [
        ListTile(
          leading: Container(
            decoration: BoxDecoration(
              // borderRadius: BorderRadius.circular(4.0),
              image: DecorationImage(
                image: audioImage,
                fit: BoxFit.cover,
              ),
            ),
            width: selectedStimulusType == "Vidéos" ? 66.666 : 50.0,
            height: 50.0,
          ),
          title: Text(
            primaryLabel,
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            secondaryLabel,
            style: const TextStyle(color: Colors.grey),
          ),
          onTap: () => screenChanger(
            context,
            widget.selectedStimulusType,
            audioFile['filename'],
          ),
          trailing: Text(
            formattedDuration,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
        const Divider(height: 1, color: Colors.grey),
      ];
    }
  }

  Future<ImageProvider> extractThumbnail(String filePath) async {
    final flutterFFmpeg = FlutterFFmpeg();
    final fileName = filePath.split('/').last;
    print(fileName);

    // Set the output file path
    final outputFilePath =
        '"$_cortifyPath/images/video_thumbnails/$fileName.jpg';

    // Delete the output file if it already exists
    if (await File(outputFilePath).exists()) {
      return FileImage(File(outputFilePath));
    } else {
      // Extract the thumbnail from the video file using ffmpeg
      final result = await flutterFFmpeg.execute(
          '-i $filePath -ss 00:00:01 -vframes 1 -q:v 2 $outputFilePath');

      // Check if ffmpeg was successful
      if (result == 0) {
        // Return the thumbnail image as an ImageProvider
        return FileImage(File(outputFilePath));
      } else {
        // Fallback to using a default thumbnail image
        return const AssetImage('assets/images/icons/play-circle.png');
      }
    }
  }
}
