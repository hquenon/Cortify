import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'home_screen.dart';
import 'playlist_screen.dart';
import 'info_screen.dart';

class AppButtons {
  // logFile = '';

  // HOME BUTTON
  static Widget homeButton(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.home),
      onPressed: () {
        // logToFile(
        //     'UserAction: Home button pressed at ${DateTime.now().toString()}',
        //     logFile);
        Navigator.of(context).pushNamed(HomeScreen.routeName);
      },
    );
  }

  // INFO BUTTON
  static Widget infoButton(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.info),
      onPressed: () {
        // logToFile(
        //     'UserAction: Info button pressed at ${DateTime.now().toString()}',
        //     logFile);
        Navigator.of(context).pushNamed(InfoScreen.routeName);
      },
    );
  }

  // PLAYLIST BUTTON
  static Widget playlistButton(BuildContext context) {
    return IconButton(
      icon: Icon(MdiIcons.playlistMusicOutline),
      onPressed: () {
        // logToFile(
        //     'UserAction: Playlist button pressed at ${DateTime.now().toString()}',
        //     logFile);
        Navigator.of(context).pushNamed(PlaylistScreen.routeName);
      },
    );
  }
}
