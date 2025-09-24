import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'logger.dart';

import 'home_screen.dart';
import 'volume_control.dart';
import 'audio_player_screen.dart';
import 'video_player_screen.dart';

class FeedbackSurvey extends StatefulWidget {
  final String currentMEDIA;
  final String selectedStimulusType;
  final Map<String, Map<String, dynamic>> playlists;
  final String cortifyPath;
  final logFile;
  // final Function() onComplete;

  const FeedbackSurvey({
    super.key,
    required this.currentMEDIA,
    required this.selectedStimulusType,
    required this.playlists,
    required this.cortifyPath,
    required this.logFile,
    // required this.onComplete,
  });

  @override
  _FeedbackSurveyState createState() => _FeedbackSurveyState();
}

class _FeedbackSurveyState extends State<FeedbackSurvey> {
  late String _selectedOption = "";
  late AudioPlayer player;

  @override
  void initState() {
    super.initState();

    logToFile(DateTime.now().toString(), 'SCREEN_MANAGER',
        'Initialization of $widget', widget.logFile);

    // VolumeControl.init(logFile: widget.logFile);

    player = AudioPlayer();
    playSound(); // send new acquisition trigger
  }

  Future<void> playSound() async {
    await player.setAudioSource(AudioSource.asset(
        'assets/trigger_new_acquisition_block/trigger_new_acquisition_block.wav'));
    player.play();
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  void _onOptionSelected(String value) {
    setState(() {
      _selectedOption = value;
    });

    logToFile(
      DateTime.now().toString(),
      'FEEDBACK_SURVEY',
      'Survey response for ${widget.currentMEDIA}: $_selectedOption',
      widget.logFile,
    );

    // Get the index of the media in the playlist
    final mediaFiles =
        widget.playlists[widget.selectedStimulusType]!.keys.toList();
    final currentIndex = mediaFiles.indexOf(widget.currentMEDIA);

    // Find the next media (or go back to the start if currently last in list)
    late String nextMediaFile;
    if (currentIndex < mediaFiles.length - 1) {
      nextMediaFile = mediaFiles[currentIndex + 1];
    } else if (currentIndex == mediaFiles.length - 1) {
      nextMediaFile = mediaFiles.first;
    }
    // Navigator.pop(context);

    // Conditional navigation based on selectedStimulusType
    if (widget.selectedStimulusType == "Vidéos") {
      // Navigate to the VideoPlayerScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(
            videoFile: nextMediaFile,
            selectedStimulusType: widget.selectedStimulusType,
            playlists: widget.playlists,
            cortifyPath: widget.cortifyPath,
            logFile: widget.logFile,
          ),
        ),
      );
    } else {
      // Navigate to the AudioPlayerScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AudioPlayerScreen(
            audioFile: nextMediaFile,
            selectedStimulusType: widget.selectedStimulusType,
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
    const double padding = 30.0;
    const double buttonSize = 80.0;
    // Feedback popup
    return AlertDialog(
      backgroundColor:
          Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 0),
      title: const Padding(
        padding: EdgeInsets.symmetric(vertical: 10.0),
        child: Text("Votre opinion sur ce contenu:"),
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
              const SizedBox(
                width: padding,
              ),

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
          const SizedBox(
            height: padding,
          ),

          // "I DIDN'T LISTEN" BUTTON
          ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: buttonSize * 2 + padding,
            ),
            child: ElevatedButton.icon(
              onPressed: () => _onOptionSelected('IGNORED'),
              icon: const Icon(Icons.headset_off, size: 24.0),
              label: const Text(
                'Je n\'ai pas écouté',
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
          const SizedBox(
            height: 16.0,
          ),
        ],
      ),
      actions: [
        Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.home,
                color: Colors.white,
              ),
              onPressed: () {
                logToFile(
                    DateTime.now().toString(),
                    'FEEDBACK_SURVEY',
                    'Survey response for ${widget.currentMEDIA}: NONE',
                    widget.logFile);
                logToFile(DateTime.now().toString(), 'SCREEN_MANAGER',
                    'Going back to HomeScreen', widget.logFile);
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  HomeScreen.routeName,
                  (route) => false,
                );
              },
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(
                Icons.arrow_forward,
                color: Colors.white,
              ),
              onPressed: () => _onOptionSelected('NONE'),
            ),
          ],
        ),
      ],
    );
  }
}
