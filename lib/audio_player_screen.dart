import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'logger.dart';
import 'volume_control.dart';
import 'feedback_survey.dart';
import 'info_screen.dart';
import 'trigger_manager.dart';

class AudioPlayerScreen extends StatefulWidget {
  static const routeName = '/audio-player-screen';

  String audioFile;
  final Map<String, Map<String, dynamic>> playlists;
  final String cortifyPath;
  final String selectedStimulusType;
  final logFile;

  AudioPlayerScreen(
      {Key? key,
      required this.playlists,
      required this.selectedStimulusType,
      required this.cortifyPath,
      required this.logFile,
      required this.audioFile})
      : super(key: key);

  @override
  _AudioPlayerScreenState createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  late AudioPlayer _audioPlayer;

  final TriggerManager _triggerManager = TriggerManager();

  // late AudioPlayer _triggerPlayer;
  late Duration _duration = Duration.zero;
  late Duration _position = Duration.zero;
  late bool _isPlaying = false;
  late bool _isPaused = true;

  late StreamSubscription<Duration> _positionSubscription;
  late StreamController<Duration> _positionController;
  late Stream<Duration> _positionStream;

  // Timer? _endOfAudioTimer;

  // Flag to track whether the survey popup has already been shown
  bool _hasShownSurvey = false;

  void initAudioPlayer() async {
    print("AudioPlayerScreen: Initalization of AudioPlayer");
    // print(widget.selectedStimulusType);
    _audioPlayer = AudioPlayer();
    final audioPath =
        "${widget.cortifyPath}/media/${widget.selectedStimulusType}/${widget.audioFile}";
    await _audioPlayer.setUrl(audioPath);
    _duration = (_audioPlayer.duration)!;

    // Detect and log any change to the player state (playing or paused)
    _audioPlayer.playerStateStream.listen((event) {
      final playing = event.playing;
      if (playing != _isPlaying) {
        setState(() {
          _isPlaying = playing;
        });
        logToFile(
          DateTime.now().toString(),
          'PLAYER_STATE',
          _isPaused
              ? 'isPlaying: $_isPlaying - Current audio position: ${_position - Duration(seconds: 5)}'
              : 'isPlaying: $_isPlaying - Current audio position: $_position',
          widget.logFile,
        );
      }
      // // Log any changes to processing state
      // logToFile(
      //   '${DateTime.now().toString()}: PLAYER_STATE: processingState: ${event.processingState} - (Current audio position: $_position)',
      //   widget.logFile,
      // );

      // if (event.processingState == ProcessingState.completed) {
      //   _showEndOfAudioDialog();
      // }
    });

    _audioPlayer.durationStream.listen((event) {
      onDurationChanged(event ?? Duration.zero);
    });

    _playAudio('init');
  }

  @override
  void initState() {
    super.initState();

    // Log the initialization of the screen
    logToFile(DateTime.now().toString(), 'SCREEN_MANAGER',
        'Initialization of $widget', widget.logFile);

    // VolumeControl.init(logFile: widget.logFile);

    // Send NewAcqTrigger at the begining of the audio
    _triggerManager.sendNewAcqTrigger(widget.logFile);

    initAudioPlayer();

    // Audiostream position listener
    _positionController = StreamController<Duration>.broadcast();
    _positionStream = _positionController.stream;
    _positionSubscription = _audioPlayer.positionStream.listen((position) {
      setState(() {
        _position = position;
        _positionController.add(position);
        if (position >= _duration) {}
      });
    });

    // Duration listener
    _audioPlayer.durationStream.listen((duration) {
      setState(() {
        _duration = duration ?? Duration.zero;
      });

      // // Start the timer when the audio is 1 second away from the end
      // final endOfAudioPosition = duration! - const Duration(seconds: 1);
      // _positionStream
      //     .where((position) => position >= endOfAudioPosition)
      //     .listen((position) {
      //   // Only start the timer if it hasn't already been started
      //   _endOfAudioTimer ??= Timer(const Duration(seconds: 1), () {
      //     _showSurveyPopup();
      //     _endOfAudioTimer = null;
      //   });
      // });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _triggerManager.dispose();
    _positionSubscription.cancel();
    _positionController.close();
    // _positionUpdateTimer.cancel();
    // _endOfAudioTimer?.cancel();

    super.dispose();
  }

  // Show End of Audio Survey Popup
  void _showSurveyPopup() async {
    logToFile(DateTime.now().toString(), 'FEEDBACK_SURVEY',
        'Showing survey popup for ${widget.audioFile}', widget.logFile);

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => FeedbackSurvey(
          currentMEDIA: widget.audioFile,
          selectedStimulusType: widget.selectedStimulusType,
          playlists: widget.playlists,
          cortifyPath: widget.cortifyPath,
          logFile: widget.logFile,
        ),
      ),
    );
  }

  // Play audio and log current position
  void _playAudio(String condition) {
    if (condition != 'init' && condition != 'button_press') {
      throw ArgumentError('Invalid condition: $condition');
    }

    // Si la lecture est déclenchée manuellement (par appui sur le bouton)
    if (condition == 'button_press') {
      // Envoyer le trigger avant de lancer la lecture
      _triggerManager.sendPlayTrigger(widget.logFile);
    }

    // Lancer la lecture de l'audio
    _audioPlayer.play();
    _isPaused = false;

    String logMessage = condition == 'init'
        ? 'Automatically playing ${widget.audioFile} from $_position'
        : 'Play button pressed. Playing ${widget.audioFile} from $_position';

    logToFile(
      DateTime.now().toString(),
      condition == 'init' ? 'STREAM_POSITION' : 'USER_ACTION',
      logMessage,
      widget.logFile,
    );
  }

  // Pause audio and log current position
  void _pauseAudio() {
    _audioPlayer.pause();

    // Play Pause Trigger (cam)
    _triggerManager.sendPauseTrigger(widget.logFile);

    // Go back 5 seconds
    //var currentPosition = _audioPlayer.position;
    //var newPosition =
    //    currentPosition - const Duration(seconds: 5); // go back 5 seconds
    //if (newPosition < Duration(seconds: 0)) {
    //  newPosition = Duration(seconds: 0);
    //}
    //_audioPlayer.seek(newPosition);

    // Play from position (no go back) (cam)
    var currentPosition = _audioPlayer.position;
    _audioPlayer.seek(_audioPlayer.position);

    logToFile(
      DateTime.now().toString(),
      'USER_ACTION',
      'Pause button pressed. Pausing audio at $currentPosition.',
      widget.logFile,
    );
    //logToFile(
    //DateTime.now().toString(),
    //'STREAM_POSITION',
    //'${widget.audioFile} paused at $currentPosition',
    //widget.logFile,
    //);
  }

  // Update the duration for the whole widget with setState
  void onDurationChanged(Duration duration) {
    setState(() {
      _duration = duration;
    });
  }

  // Update the position in the audiostream for the whole widget with setState
  void onAudioPositionChanged(Duration position) {
    setState(() {
      _position = position;
    });
  }

  Stream<Duration> get _durationStream =>
      _audioPlayer.durationStream.map((event) => event ?? Duration.zero);

  @override
  Widget build(BuildContext context) {
    final audioMetadata =
        widget.playlists[widget.selectedStimulusType]![widget.audioFile];
    final title = audioMetadata['title'] ?? '';
    final album = audioMetadata['album'] ?? '';
    final artist = audioMetadata['artist'] ?? '';

    // Create the avatar image for the audio file
    final audioImage = audioMetadata['album_cover'] != null &&
            File("${widget.cortifyPath}/images/album_covers/${audioMetadata['album_cover']}")
                .existsSync()
        ? FileImage(File(
            "${widget.cortifyPath}/images/album_covers/${audioMetadata['album_cover']}"))
        : const AssetImage('assets/images/icons/play-circle.png');

    final playlist = widget.playlists[widget.selectedStimulusType];
    final audioFiles = playlist!.keys.toList();
    final currentIndex = audioFiles.indexOf(widget.audioFile);

    void updateAudioFile(String newAudioFile) {
      // Send trigger for new acquisition block
      _triggerManager.sendNewAcqTrigger(widget.logFile);

      // Record new info
      logToFile(DateTime.now(), 'PLAYER_STATE',
          'Reloaded player with $newAudioFile', widget.logFile);

      // Update AudioPlayerScreen state
      setState(() {
        widget.audioFile = newAudioFile;
        _position = const Duration(seconds: 0);
        _duration =
            Duration(seconds: playlist[newAudioFile]['duration'].round());
      });

      String logMessage = _isPlaying
          ? 'Playing $newAudioFile from ${Duration(seconds: 0)}.'
          : '$newAudioFile paused at ${Duration(seconds: 0)}.';

      logToFile(DateTime.now(), 'USER_ACTION', logMessage, widget.logFile);
    }

    // Create a player state stream listener to show the pop-up when the audio is finished
    _audioPlayer.playerStateStream.listen((state) async {
      if (state.processingState == ProcessingState.completed &&
          !_hasShownSurvey) {
        _showSurveyPopup();
        _hasShownSurvey = true;

        // Send trigger for new acquisition block at the end of the audio file (cam)
        _triggerManager.sendNewAcqTrigger(widget.logFile);

        // Remove the player state stream listener to prevent memory leaks
        _audioPlayer.playerStateStream.drain();
      }
    });

    return Scaffold(
      // APPBAR
      appBar: AppBar(
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
                }),
          ),
        ],
      ),

      // BODY
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // DISPLAY TRACK INFO
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30.0),
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 20.0),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: widget.selectedStimulusType == 'Podcasts' ||
                                      widget.selectedStimulusType ==
                                          'Audiobooks'
                                  ? '$album - '
                                  : '$artist - ',
                              style: TextStyle(
                                fontStyle:
                                    widget.selectedStimulusType == 'Podcasts' ||
                                            widget.selectedStimulusType ==
                                                'Audiobooks'
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                fontSize: 16.0,
                              ),
                            ),
                            TextSpan(
                              text: widget.selectedStimulusType == 'Podcasts' ||
                                      widget.selectedStimulusType ==
                                          'Audiobooks'
                                  ? artist
                                  : album,
                              style: TextStyle(
                                fontStyle:
                                    widget.selectedStimulusType == 'Podcasts' ||
                                            widget.selectedStimulusType ==
                                                'Audiobooks'
                                        ? FontStyle.normal
                                        : FontStyle.italic,
                                fontSize: 16.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),

                // DISPLAY ALBUM COVER OR PLAY ICON IF NOT AVAILABLE
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 100.0, vertical: 50.0),
                  child: Image(
                    image: audioImage as ImageProvider<Object>,
                    fit: BoxFit.fitWidth,
                  ),
                ),

                // DISPLAY POSITION AND DURATION DATA WITH PROGRESS BAR
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 50.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Update the position
                      StreamBuilder<Duration>(
                        stream: _positionStream,
                        builder: (context, snapshot) {
                          final position = snapshot.data ?? Duration.zero;
                          return Text(
                            '${position.inMinutes}:${(position.inSeconds % 60).toString().padLeft(2, '0')}',
                            textAlign: TextAlign.right,
                            // style: TextStyle(fontSize: 24.0),
                          );
                        },
                      ),

                      // Update the duration
                      StreamBuilder<Duration>(
                        stream: _durationStream,
                        builder: (context, snapshot) {
                          final duration = snapshot.data ?? Duration.zero;
                          return Text(
                            '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
                            textAlign: TextAlign.left,
                            // style: TextStyle(fontSize: 24.0),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // STREAM BUILDER TO UPDATE THE AUDIO PROGRESS BAR
                StreamBuilder<Duration>(
                  stream: _positionStream,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30.0),
                      child: Slider(
                        value: position.inSeconds < 0
                            ? 0.0
                            : position.inSeconds > _duration.inSeconds
                                ? _duration.inSeconds.toDouble()
                                : position.inSeconds.toDouble(),
                        max: _duration.inSeconds.toDouble(),
                        onChanged: (double value) {
                          _audioPlayer.seek(Duration(seconds: value.toInt()));

                          // Record slider change
                          String logMessage = _isPlaying
                              ? 'Position of audio changed using the slider. Playing from ${Duration(seconds: value.toInt())}.'
                              : 'Position of audio changed using the slider. Paused at ${Duration(seconds: value.toInt())}.';

                          logToFile(DateTime.now(), 'USER_ACTION', logMessage,
                              widget.logFile);
                        },
                      ),
                    );
                  },
                ),

                // PLAYBACK BUTTONS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // SKIP TO PREVIOUS TRACK
                    IconButton(
                      icon: const ImageIcon(
                        AssetImage("assets/images/icons/step-backward.png"),
                        size: 60.0,
                        color: Colors.white,
                      ),
                      onPressed: () async {
                        // Get previous track
                        // Go to the previous file if exists
                        late String previousAudioFile;
                        if (currentIndex > 0) {
                          previousAudioFile = audioFiles[currentIndex - 1];

                          // Otherwise go to the end of the playlist
                        } else if (currentIndex == 0 && audioFiles.isNotEmpty) {
                          previousAudioFile = audioFiles.last;
                        }

                        // Record button press
                        logToFile(
                            DateTime.now(),
                            'USER_ACTION',
                            '"Previous track" button pressed. Previous track is: $previousAudioFile',
                            widget.logFile);

                        final audioPath =
                            "${widget.cortifyPath}/media/${widget.selectedStimulusType}/$previousAudioFile";
                        await _audioPlayer.setUrl(audioPath);
                        updateAudioFile(previousAudioFile);
                      },
                    ),

                    // BACKWARD 10 SECONDS
                    IconButton(
                      icon: const ImageIcon(
                        AssetImage("assets/images/icons/backward10.png"),
                        size: 60.0,
                        color: Colors.white,
                      ),
                      onPressed: () async {
                        // Record button press
                        logToFile(
                            DateTime.now().toString(),
                            'USER_ACTION',
                            'Backward 10 seconds" button pressed.',
                            widget.logFile);

                        // Get the new position to seek to
                        final newPosition =
                            _position - const Duration(seconds: 10);

                        // Check if new position is after the end of the audio file
                        if (newPosition < const Duration(seconds: 0)) {
                          // If it is, seek to the start
                          _audioPlayer.seek(const Duration(seconds: 0));
                          logToFile(
                            DateTime.now().toString(),
                            'STREAM_POSITION',
                            '${widget.audioFile} ${_isPlaying ? 'playing' : 'paused'} at 0:00:00.00000',
                            widget.logFile,
                          );
                        } else {
                          // If not, seek to the new position
                          _audioPlayer.seek(newPosition).catchError((error) {
                            // Handle any seek errors
                            logToFile(
                              DateTime.now().toString(),
                              'ERROR',
                              'Failed to seek: $error',
                              widget.logFile,
                            );
                          }).then((value) {
                            // Get the current position after seeking to the new position
                            final currentPosition = _audioPlayer.position;
                            // Add the new position to the _positionController
                            _positionController.add(currentPosition);
                            // Log the new position
                            logToFile(
                              DateTime.now().toString(),
                              'STREAM_POSITION',
                              '${widget.audioFile} ${_isPlaying ? 'playing' : 'paused'} at ${newPosition.toString()}',
                              widget.logFile,
                            );
                          });
                        }
                      },
                    ),

                    // PLAY/PAUSE BUTTON
                    Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        // color: Theme.of(context).accentColor,
                      ),
                      child: SizedBox(
                        width: 80,
                        height: 80,
                        child: StreamBuilder<PlayerState>(
                          stream: _audioPlayer.playerStateStream,
                          builder: (context, snapshot) {
                            final playerState = snapshot.data;
                            final processingState =
                                playerState?.processingState;

                            if (processingState == ProcessingState.loading ||
                                processingState == ProcessingState.buffering) {
                              return const CircularProgressIndicator();
                            } else if (_audioPlayer.playing != true) {
                              return IconButton(
                                icon: const Icon(
                                  Icons.play_circle_filled,
                                  size: 60.0,
                                  color: Colors.white,
                                ),
                                onPressed: () => _playAudio('button_press'),
                              );
                            } else if (processingState !=
                                ProcessingState.completed) {
                              return IconButton(
                                icon: const Icon(
                                  Icons.pause_circle_filled,
                                  size: 60.0,
                                  color: Colors.white,
                                ),
                                onPressed: () => _pauseAudio(),
                              );
                            } else {
                              return const CircularProgressIndicator();
                              // return IconButton(
                              //   icon: const Icon(
                              //     Icons.replay_circle_filled,
                              //     size: 60.0,
                              //     color: Colors.white,
                              //   ),
                              //   onPressed: () =>
                              //       _audioPlayer.seek(Duration.zero),
                              //);
                            }
                          },
                        ),
                      ),
                    ),

                    // FORWARD 10 SECONDS
                    IconButton(
                      icon: const ImageIcon(
                        AssetImage("assets/images/icons/forward10.png"),
                        size: 60.0,
                        color: Colors.white,
                      ),
                      onPressed: () async {
                        // Record button press
                        logToFile(
                          DateTime.now().toString(),
                          'USER_ACTION',
                          'Forward 10 seconds" button pressed.',
                          widget.logFile,
                        );

                        // Get the new position to seek to
                        final newPosition =
                            _position + const Duration(seconds: 10);

                        // Check if new position is after the end of the audio file
                        if (newPosition > _duration) {
                          // If it is, seek to the end
                          _audioPlayer.seek(
                              _duration); // - const Duration(seconds: 1));
                          logToFile(
                            DateTime.now().toString(),
                            'STREAM_POSITION',
                            '${widget.audioFile} ${_isPlaying ? 'playing' : 'paused'} at ${_duration - const Duration(seconds: 1)}',
                            widget.logFile,
                          );
                        } else {
                          // If not, seek to the new position
                          _audioPlayer.seek(newPosition).catchError((error) {
                            // Handle any seek errors
                            logToFile(
                              DateTime.now().toString(),
                              'ERROR',
                              'Failed to seek: $error',
                              widget.logFile,
                            );
                          }).then((value) {
                            // Get the current position after seeking to the new position
                            final currentPosition = _audioPlayer.position;
                            // Add the new position to the _positionController
                            _positionController.add(currentPosition);
                            // Log the new position
                            logToFile(
                              DateTime.now().toString(),
                              'STREAM_POSITION',
                              '${widget.audioFile} ${_isPlaying ? 'playing' : 'paused'} at $currentPosition',
                              widget.logFile,
                            );
                          });
                        }
                      },
                    ),

                    // SKIP TO NEXT TRACK
                    IconButton(
                      icon: const ImageIcon(
                        AssetImage("assets/images/icons/step-forward.png"),
                        size: 60.0,
                        color: Colors.white,
                      ),
                      onPressed: () async {
                        // Go to the next file if exists
                        late String nextAudioFile;
                        if (currentIndex < audioFiles.length - 1) {
                          nextAudioFile = audioFiles[currentIndex + 1];
                          // Otherwise go back to start
                        } else if (currentIndex == audioFiles.length - 1) {
                          nextAudioFile = audioFiles.first;
                        }

                        // Record button press
                        logToFile(
                            DateTime.now(),
                            'USER_ACTION',
                            '"Next track" button pressed. Next track is: $nextAudioFile',
                            widget.logFile);

                        final audioPath =
                            "${widget.cortifyPath}/media/${widget.selectedStimulusType}/$nextAudioFile";
                        await _audioPlayer.setUrl(audioPath);
                        updateAudioFile(nextAudioFile);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
