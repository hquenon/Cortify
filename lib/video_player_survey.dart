import 'package:flutter/material.dart';
import 'logger.dart';

import 'home_screen.dart';
import 'volume_control.dart';
import 'video_player_screen.dart';

class VideoPlayerSurvey extends StatefulWidget {
  final String currentVideo;
  final String selectedStimulusType;
  final Map<String, Map<String, dynamic>> playlists;
  final String cortifyPath;
  final logFile;

  const VideoPlayerSurvey({
    Key? key,
    required this.currentVideo,
    required this.selectedStimulusType,
    required this.playlists,
    required this.cortifyPath,
    required this.logFile,
  }) : super(key: key);

  @override
  _VideoPlayerSurveyState createState() => _VideoPlayerSurveyState();
}

class _VideoPlayerSurveyState extends State<VideoPlayerSurvey> {
  late String _selectedOption = "";

  @override
  Widget build(BuildContext context) {
    const double padding = 30.0;
    const double buttonSize = 80.0;

    // Helper method to handle option selection
    void _onOptionSelected(String value) {
      setState(() {
        _selectedOption = value;
      });

      // Log the survey response
      logToFile(
        DateTime.now().toString(),
        'FEEDBACK_SURVEY',
        'Survey response for ${widget.currentVideo}: $_selectedOption',
        widget.logFile,
      );

      // Get the index of the media in the playlist
      final videoFiles =
          widget.playlists[widget.selectedStimulusType]!.keys.toList();
      final currentIndex = videoFiles.indexOf(widget.currentVideo);

      // Find the next media (or go back to the start if currently last in list)
      late String nextVideoFile;
      if (currentIndex < videoFiles.length - 1) {
        nextVideoFile = videoFiles[currentIndex + 1];
      } else {
        nextVideoFile = videoFiles.first;
      }

      // Navigate to the next video or back to the home screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(
            videoFile: nextVideoFile,
            selectedStimulusType: widget.selectedStimulusType,
            playlists: widget.playlists,
            cortifyPath: widget.cortifyPath,
            logFile: widget.logFile,
          ),
        ),
      );
    }

    return AlertDialog(
      backgroundColor:
          Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 0),
      title: const Padding(
        padding: EdgeInsets.symmetric(vertical: 10.0),
        child: Text("Votre opinion sur cette vidéo:"),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // LIKE/DISLIKE ROW
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // LIKE BUTTON
              InkWell(
                onTap: () => _onOptionSelected("LIKED"),
                child: Container(
                  width: buttonSize,
                  height: buttonSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16.0),
                    color: Colors.green,
                  ),
                  child: const Icon(Icons.thumb_up, size: 36.0),
                ),
              ),

              // PADDING
              const SizedBox(width: padding),

              // DISLIKE BUTTON
              InkWell(
                onTap: () => _onOptionSelected("DISLIKED"),
                child: Container(
                  width: buttonSize,
                  height: buttonSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16.0),
                    color: Colors.red,
                  ),
                  child: const Icon(Icons.thumb_down, size: 36.0),
                ),
              ),
            ],
          ),

          // PADDING
          const SizedBox(height: padding),

          // "I DIDN'T WATCH" BUTTON
          ConstrainedBox(
            constraints:
                const BoxConstraints(minWidth: buttonSize * 2 + padding),
            child: ElevatedButton.icon(
              onPressed: () => _onOptionSelected('IGNORED'),
              icon: const Icon(Icons.remove_red_eye_outlined, size: 24.0),
              label: const Text(
                'Je n\'ai pas regardé',
                style: TextStyle(color: Colors.black),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),

          // PADDING
          const SizedBox(height: 16.0),
        ],
      ),
      actions: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.home, color: Colors.white),
              onPressed: () {
                // Log the action
                logToFile(
                  DateTime.now().toString(),
                  'FEEDBACK_SURVEY',
                  'Survey response for ${widget.currentVideo}: NONE',
                  widget.logFile,
                );
                logToFile(
                  DateTime.now().toString(),
                  'SCREEN_MANAGER',
                  'Going back to HomeScreen',
                  widget.logFile,
                );
                // Navigate back to the home screen
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  HomeScreen.routeName,
                  (route) => false,
                );
              },
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.arrow_forward, color: Colors.white),
              onPressed: () => _onOptionSelected('NONE'),
            ),
          ],
        ),
      ],
    );
  }

  // This method should be similar to the one in your audio survey class
  void logToFile(
      String dateTime, String category, String message, var logFile) {
    // Implement your logging functionality here
  }
}
