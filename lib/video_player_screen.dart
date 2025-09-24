import 'dart:async';
import 'dart:io';

import 'trigger_manager.dart';
import 'logger.dart';
import 'feedback_survey.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerScreen extends StatefulWidget {
  static const routeName = '/video-player-screen';

  String videoFile;
  final Map<String, Map<String, dynamic>> playlists;
  final String cortifyPath;
  final String selectedStimulusType;
  final logFile;

  VideoPlayerScreen(
      {Key? key,
      required this.playlists,
      required this.selectedStimulusType,
      required this.cortifyPath,
      required this.logFile,
      required this.videoFile})
      : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;
  late bool _showControls = true;
  late bool _isFullScreen = false;
  final TriggerManager _triggerManager = TriggerManager();

  @override
  void initState() {
    super.initState();

    // Create and store the VideoPlayerController.
    _controller = VideoPlayerController.file(File(
        "${widget.cortifyPath}/media/${widget.selectedStimulusType}/${widget.videoFile}"));

    print("Start initialization of controller");

    // Initialize the controller and store the Future for later use.
    _initializeVideoPlayerFuture = _controller.initialize();

    print("Controller initialized");

    // Use the controller to loop the video.
    _controller.setLooping(false);

    // Send trigger for new acquisition block at the begining of the audio file
    _triggerManager.sendNewAcqTrigger(widget.logFile);

    // Add a listener to the video player to detect when it finishes playing
    _controller.addListener(checkVideo);
  }

  @override
  void dispose() {
    // Ensure disposing of the VideoPlayerController to free up resources.
    _controller.dispose();

    super.dispose();
  }

  void checkVideo() {
    // If the video has finished playing
    if (_controller.value.position == _controller.value.duration &&
        !_controller.value.isPlaying) {
      _showSurveyPopup();
      // Remove the listener so it doesn't trigger multiple times
      _controller.removeListener(checkVideo);
    }
  }

  // Show End of Video Survey Popup
  void _showSurveyPopup() async {
    logToFile(DateTime.now().toString(), 'FEEDBACK_SURVEY',
        'Showing survey popup for ${widget.videoFile}', widget.logFile);

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => FeedbackSurvey(
          currentMEDIA: widget.videoFile,
          selectedStimulusType: widget.selectedStimulusType,
          playlists: widget.playlists,
          cortifyPath: widget.cortifyPath,
          logFile: widget.logFile,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var videoMetadata =
        widget.playlists[widget.selectedStimulusType]![widget.videoFile];

    print(videoMetadata);

    final playlist = widget.playlists[widget.selectedStimulusType];
    final videoFiles = playlist!.keys.toList();
    final currentIndex = videoFiles.indexOf(widget.videoFile);

    void updateVideoFile(String newVideoFile) {
      // Send trigger for new acquisition block
      _triggerManager.sendNewAcqTrigger(widget.logFile);

      // Record new info
      logToFile(DateTime.now(), 'PLAYER_STATE',
          'Reloaded player with $newVideoFile', widget.logFile);

      // Update AudioPlayerScreen state
      setState(() {
        widget.videoFile = newVideoFile;
      });

      String logMessage = _controller.value.isPlaying
          ? 'Playing $newVideoFile from ${Duration(seconds: 0)}.'
          : '$newVideoFile paused at ${Duration(seconds: 0)}.';

      logToFile(DateTime.now(), 'USER_ACTION', logMessage, widget.logFile);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.playlists[widget.selectedStimulusType]![widget.videoFile]
                ['title']), // Display the video filename in the app bar
      ),
      body: GestureDetector(
        onTap: () {
          setState(() {
            _showControls =
                !_showControls; // Toggle the display of controls on tap
          });
        },
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            FutureBuilder(
              future: _initializeVideoPlayerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text("Failed to load video."),
                    );
                  }
                  return FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: _controller.value.size.width,
                      height: _controller.value.size.height,
                      child: VideoPlayer(_controller),
                    ),
                  );
                } else {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
              },
            ),
            Visibility(
              visible: _showControls,
              child: AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  color: Colors.black54,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        // SKIP TO PREVIOUS
                        IconButton(
                          icon: const Icon(Icons.skip_previous),
                          color: Colors.white,
                          onPressed: () async {
                            // Get previous video
                            // Go to the previous file if exists
                            late String previousVideoFile;
                            if (currentIndex > 0) {
                              previousVideoFile = videoFiles[currentIndex - 1];
                            }
                            // Otherwise go to the end of the playlist
                            else if (currentIndex == 0 &&
                                videoFiles.isNotEmpty) {
                              previousVideoFile = videoFiles.last;
                            }

                            // Record button press
                            logToFile(
                                DateTime.now(),
                                'USER_ACTION',
                                '"Previous video" button pressed. Previous video is: $previousVideoFile',
                                widget.logFile);

                            final previousVideoPath =
                                "${widget.cortifyPath}/media/${widget.selectedStimulusType}/$previousVideoFile";

                            // Dispose of the old controller before creating a new one.
                            _controller.dispose();
                            _controller =
                                VideoPlayerController.network(previousVideoPath)
                                  ..initialize().then((_) {
                                    // Ensure the first frame is shown after the video is initialized.
                                    setState(() {
                                      updateVideoFile(previousVideoFile);
                                      _controller.play();
                                    });
                                  });
                          },
                        ),

                        // REWIND 10
                        IconButton(
                          icon: const Icon(Icons.replay_10),
                          color: Colors.white,
                          onPressed: () {
                            // Record button press
                            logToFile(
                                DateTime.now().toString(),
                                'USER_ACTION',
                                'Backward 10 seconds" button pressed.',
                                widget.logFile);

                            Duration position = _controller.value.position;
                            Duration tenSeconds = const Duration(seconds: 10);
                            Duration newPosition = position - tenSeconds;
                            _controller.seekTo(newPosition);
                          },
                        ),

                        IconButton(
                          icon: Icon(
                            _controller.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                          ),
                          color: Colors.white,
                          onPressed: () async {
                            // Make onPressed asynchronous
                            var currentPosition = await _controller
                                .position; // Get current position outside setState

                            if (_controller.value.isPlaying) {
                              setState(() {
                                // Pause video
                                _controller.pause();

                                // Play Pause Trigger (cam)
                                _triggerManager
                                    .sendPauseTrigger(widget.logFile);

                                // Record button press
                                logToFile(
                                  DateTime.now().toString(),
                                  'USER_ACTION',
                                  'Pause button pressed. Pausing video at $currentPosition.',
                                  widget.logFile,
                                );
                              });

                              if (currentPosition != null) {
                                await _controller.seekTo(currentPosition);
                              }
                            } else {
                              // Play Play Trigger (cam) when video resumes
                              await _triggerManager
                                  .sendPlayTrigger(widget.logFile);
                              setState(() {
                                // Record button press
                                logToFile(
                                  DateTime.now().toString(),
                                  'USER_ACTION',
                                  'Play button pressed. Playing ${widget.videoFile} from ${_controller.value.position}',
                                  widget.logFile,
                                );

                                // Play video
                                _controller.play();
                              });
                            }
                          },
                        ),

                        // FORWARD 10
                        IconButton(
                          icon: const Icon(Icons.forward_10),
                          color: Colors.white,
                          onPressed: () {
                            // Record button press
                            logToFile(
                              DateTime.now().toString(),
                              'USER_ACTION',
                              'Forward 10 seconds" button pressed.',
                              widget.logFile,
                            );

                            int tenSeconds =
                                10 * 1000; // 10 seconds in milliseconds
                            Duration newPosition = _controller.value.position +
                                Duration(milliseconds: tenSeconds);

                            // Log the new position
                            logToFile(
                              DateTime.now().toString(),
                              'STREAM_POSITION',
                              '${widget.videoFile} ${_controller.value.isPlaying ? 'playing' : 'paused'} at $newPosition',
                              widget.logFile,
                            );
                            _controller.seekTo(newPosition);
                          },
                        ),

                        // SKIP TO NEXT
                        IconButton(
                          icon: const Icon(Icons.skip_next),
                          color: Colors.white,
                          onPressed: () async {
                            // Go to next video
                            late String nextVideoFile;
                            // If not at the end of the list, go to the next video
                            if (currentIndex < videoFiles.length - 1) {
                              nextVideoFile = videoFiles[currentIndex + 1];
                            }
                            // If at the end of the playlist, go back to the first video
                            else {
                              nextVideoFile = videoFiles.first;
                            }

                            // Record button press
                            logToFile(
                                DateTime.now(),
                                'USER_ACTION',
                                '"Next video" button pressed. Next video is: $nextVideoFile',
                                widget.logFile);

                            final nextVideoPath =
                                "${widget.cortifyPath}/media/${widget.selectedStimulusType}/${nextVideoFile}";

                            // Dispose of the old controller before creating a new one.
                            _controller.dispose();
                            _controller =
                                VideoPlayerController.network(nextVideoPath)
                                  ..initialize().then((_) {
                                    // Ensure the first frame is shown after the video is initialized.
                                    setState(() {
                                      updateVideoFile(nextVideoFile);
                                      _controller.play();
                                    });
                                  });
                          },
                        ),

                        IconButton(
                          icon: const Icon(Icons.fullscreen),
                          color: Colors.white,
                          onPressed: () {
                            if (_isFullScreen) {
                              // If the video is currently in fullscreen mode, pop the fullscreen player and show system overlays
                              Navigator.pop(context);
                              SystemChrome.setEnabledSystemUIMode(SystemUiMode
                                  .edgeToEdge); // Updated method to show system overlays

                              _isFullScreen = false;
                            } else {
                              // If the video is not in fullscreen mode, navigate to the fullscreen player and hide system overlays
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      FullScreenPlayer(controller: _controller),
                                ),
                              ).then((value) {
                                // This callback is called when the fullscreen player is popped. Reset the fullscreen mode here.
                                _isFullScreen = false;
                                SystemChrome.setEnabledSystemUIMode(SystemUiMode
                                    .edgeToEdge); // Updated method to show system overlays
                              });

                              SystemChrome.setEnabledSystemUIMode(SystemUiMode
                                  .immersiveSticky); // Updated method to hide system overlays

                              _isFullScreen = true;
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Visibility(
              visible:
                  _isFullScreen, // Show the video in fullscreen mode when _isFullScreen is true
              child: Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: MediaQuery.of(context)
                      .size
                      .height, // Set the height of the video player to match the screen height
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _showControls = !_showControls;
                        _isFullScreen = !_isFullScreen;

                        if (_isFullScreen) {
                          // If the video is currently in fullscreen mode, exit fullscreen mode and show system overlays

                          SystemChrome.setEnabledSystemUIMode(SystemUiMode
                              .edgeToEdge); // This will show the status and navigation bars
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  FullScreenPlayer(controller: _controller),
                            ),
                          );
                        } else {
                          // If the video is not in fullscreen mode, enter fullscreen mode and hide system overlays
                          SystemChrome.setEnabledSystemUIMode(SystemUiMode
                              .immersiveSticky); // This will hide the status and navigation bars
                          Navigator.pop(context);
                        }
                      });
                    },
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: _controller.value.size.width,
                        height: _controller.value.size.height,
                        child: VideoPlayer(_controller),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FullScreenPlayer extends StatefulWidget {
  final VideoPlayerController controller;

  FullScreenPlayer({required this.controller});

  @override
  _FullScreenPlayerState createState() => _FullScreenPlayerState();
}

class _FullScreenPlayerState extends State<FullScreenPlayer> {
  @override
  void dispose() {
// Exit fullscreen mode when the widget is disposed
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          Navigator.pop(context);
        },
        child: Container(
          color: Colors.black,
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: widget.controller.value.size.width,
                height: widget.controller.value.size.height,
                child: VideoPlayer(widget.controller),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
