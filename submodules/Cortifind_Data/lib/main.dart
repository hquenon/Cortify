import 'dart:io';
import 'package:flutter/material.dart';
import 'package:external_path/external_path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(MyApp());
}

/// Represents the main application widget for the Cortify Log Parser.
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cortify Log Parser',
      theme: ThemeData(
        // This is the theme of the application.
        primaryColor: const Color(0xFF7D70BA),
        // accentColor: const Color(0xFF90C290),
        scaffoldBackgroundColor: const Color(0xFF343633),
        // buttonColor: const Color(0xFF75699E),
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

          backgroundColor: const Color(0xFF343633), // dark grey background
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
      home: LogParserScreen(),
    );
  }
}

/// Represents the screen for the log parser.
class LogParserScreen extends StatefulWidget {
  @override
  _LogParserScreenState createState() => _LogParserScreenState();
}

/// Represents the state of the LogParserScreen widget.
class _LogParserScreenState extends State<LogParserScreen> {
  late String cortifyPath;

  List<DateBlockTimings> dateBlockTimings = [];
  late List<String> selectedTimings = [];
  List<String> collectedTimestamps = [];
  bool showCollectedData = false;
  List<String> displayedTimestamps = [];

  String userName = '';

  Map<int, String> monthsToString = {
    1: "January",
    2: "February",
    3: "March",
    4: "April",
    5: "May",
    6: "June",
    7: "July",
    8: "August",
    9: "September",
    10: "October",
    11: "November",
    12: "December",
  };

  Map<String, int> monthsToInt = {
    "January": 1,
    "February": 2,
    "March": 3,
    "April": 4,
    "May": 5,
    "June": 6,
    "July": 7,
    "August": 8,
    "September": 9,
    "October": 10,
    "November": 11,
    "December": 12,
  };

  @override
  void initState() {
    super.initState();
    requestStoragePermission();
    loadCollectedTimestamps();
  }

  /// Requests storage permission using the permission_handler package.
  void requestStoragePermission() async {
    var status = await Permission.storage.request();
    if (status.isGranted) {
      parseLogs();
      print(dateBlockTimings);
    } else if (status.isDenied) {
      // Handle permission denied
      print('Storage permission denied');
    } else if (status.isPermanentlyDenied) {
      // Handle permission permanently denied
      print('Storage permission permanently denied');
    }
  }

  /// Loads the previously collected timestamps from the log file.
  void loadCollectedTimestamps() async {
    cortifyPath =
        (await ExternalPath.getExternalStorageDirectories())[0] + '/Cortify';
    final appLogFile = File('$cortifyPath/data_collection_log.csv');

    if (await appLogFile.exists()) {
      // File exists, load collected timestamps from the log file
      final content = await appLogFile.readAsString();
      final lines = content.split('\n');

      // Clear the previously displayed timestamps
      displayedTimestamps.clear();

      // Parse the content and populate collectedTimestamps list
      for (var i = 1; i < lines.length; i++) {
        final columns = lines[i].split(',');
        if (columns.length >= 1) {
          final timestamp = columns[0];
          collectedTimestamps.add(timestamp);
          displayedTimestamps
              .add(timestamp); // Add timestamp to displayedTimestamps
        }
      }
    } else {
      // File doesn't exist, assume no data has been collected yet
      // Populate displayedTimestamps with all timestamps from dateBlockTimings when available
      if (dateBlockTimings.isNotEmpty) {
        displayedTimestamps = dateBlockTimings
            .expand((dateBlock) => dateBlock.timestampInfos
                .map((timestampInfo) => timestampInfo.timestamp))
            .toList();
      }
    }

    // Update the UI after loading collected timestamps
    setState(() {});
  }

  /// Saves the newly collected timestamps to the log file.
  void saveCollectedTimestamps(
      String comment, String patientID, List<String> matchingFilenames) async {
    final timestampTable = StringBuffer();
    final currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());

    for (final timestamp in selectedTimings) {
      final logFileName = dateBlockTimings
          .expand((dateBlock) => dateBlock.timestampInfos
              .where((timestampInfo) => timestampInfo.timestamp == timestamp)
              .map((timestampInfo) => timestampInfo.logFileName))
          .firstWhere((fileName) => true, orElse: () => '');

      final matchingFilename = matchingFilenames[selectedTimings.indexOf(
          timestamp)]; // Get the matching filename based on the index of the timestamp

      timestampTable.write(
          '$timestamp,$matchingFilename,${logFileName.split('/').last},$patientID,$userName,$currentDate,$comment\n');
    }
    final appLogFile = File('$cortifyPath/data_collection_log.csv');

    if (!await appLogFile.exists()) {
      // Create the file and write the CSV header
      await appLogFile.create(recursive: true);
      await appLogFile.writeAsString(
          'timestamp_of_iEEG_file,iEEG_filename,cortify_log_file_name,patient_ID,data_collected_by,date_of_collection,comment\n');
    }

    // Write the timestampTable to the log file
    await appLogFile.writeAsString(timestampTable.toString(),
        mode: FileMode.append);

    // Update the collectedTimestamps list
    for (final timestamp in selectedTimings) {
      if (!collectedTimestamps.contains(timestamp)) {
        collectedTimestamps.add(timestamp);
      }
    }

    // Update the displayed and selected timestamps after saving the collected timestamps
    updateDisplayedTimestampsAfterCollection();
    selectedTimings.clear();
    setState(() {});
  }

  /// Toggles the visibility of collected data.
  void toggleShowCollectedData() {
    setState(() {
      showCollectedData = !showCollectedData;
      updateDisplayedTimestampsAfterCollection();
    });
  }

  /// Parses the log files in the Cortify directory to extract timestamp information.
  /// Retrieves the list of log files from the directory and iterates over each file,
  /// calling the `parseLogFile()` method to extract timestamp information and populate
  /// the `dateMap`. After parsing all log files, the `dateBlockTimings` list is created,
  /// sorted, and updated in the UI. Any errors encountered during the parsing process
  /// are caught and logged.
  ///
  /// Throws:
  ///   - Exception: If an error occurs during the parsing process.
  void parseLogs() async {
    try {
      cortifyPath =
          '${(await ExternalPath.getExternalStorageDirectories())[0]}/Cortify';
      final cortifyLogPath = '$cortifyPath/logs';
      var logDir = Directory(cortifyLogPath);

      // Get a list of log files in the directory
      var logFiles = logDir.listSync().whereType<File>().toList();

      var dateMap = <String, List<TimestampInfo>>{};

      for (var logFile in logFiles) {
        await parseLogFile(logFile, logFile.path, dateMap);
      }

      // Create the dateBlockTimings list
      dateBlockTimings = dateMap.entries.map((entry) {
        final date = entry.key;
        final timestampInfos = entry.value;

        // Sort the timestampInfos within the dateBlock
        timestampInfos.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        return DateBlockTimings(date: date, timestampInfos: timestampInfos);
      }).toList();

      // Sort the dateBlockTimings by date
      dateBlockTimings.sort((a, b) {
        final dateA = a.date.split(' ');
        final dateB = b.date.split(' ');

        final dayA = int.parse(dateA[0]);
        final dayB = int.parse(dateB[0]);

        final monthA = monthsToInt[dateA[1]];
        final monthB = monthsToInt[dateB[1]];

        final yearA = int.parse(dateA[2]);
        final yearB = int.parse(dateB[2]);

        if (yearA != yearB) {
          return yearA.compareTo(yearB);
        } else if (monthA != monthB) {
          return monthA!.compareTo(monthB!);
        } else {
          return dayA.compareTo(dayB);
        }
      });

      // Reverse the order of the dateBlockTimings list
      dateBlockTimings = dateBlockTimings.reversed.toList();

      // Update the UI after parsing
      setState(() {
        updateDisplayedTimestamps(); // Update displayed timestamps
      });
    } catch (e) {
      print('Error parsing logs: $e');
    }
  }

  /// Updates the displayed timestamps based on the collected timestamps and showCollectedData flag.
  void updateDisplayedTimestamps() {
    if (collectedTimestamps.isEmpty || showCollectedData) {
      displayedTimestamps = dateBlockTimings
          .expand((dateBlock) => dateBlock.timestampInfos
              .map((timestampInfo) => timestampInfo.timestamp))
          .toList();
    } else {
      displayedTimestamps = dateBlockTimings
          .expand((dateBlock) => dateBlock.timestampInfos
              .map((timestampInfo) => timestampInfo.timestamp))
          .where((timestamp) => !collectedTimestamps.contains(timestamp))
          .toList();
    }

    print("Displayed timestamps: $displayedTimestamps");
    print("Collected timestamps: $collectedTimestamps");
  }

  /// Parses a single log file to extract timestamp information and populates the provided [dateMap].
  ///
  /// Parameters:
  ///   - logFile: The log file to parse.
  ///   - logFilePath: The path of the log file.
  ///   - dateMap: The map to populate with timestamp information grouped by date.
  ///
  /// Throws:
  ///   - Exception: If an error occurs during the parsing process.
  Future<void> parseLogFile(File logFile, String logFileName,
      Map<String, List<TimestampInfo>> dateMap) async {
    var lines = await logFile.readAsLines();

    var blockTriggerLine =
        "NEW_BLOCK: Playing trigger for new acquisition block";
    var surveyPopupLine = "FEEDBACK_SURVEY: Showing survey popup";

    var mostRecentBlockTriggerTimestamp = '';
    var surveyPopupTimestamp = '';

    var blockTriggerTimestamps = <String>[];

    // Parsing the log file
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].contains(blockTriggerLine)) {
        mostRecentBlockTriggerTimestamp = lines[i].substring(0, 19);
        blockTriggerTimestamps.add(mostRecentBlockTriggerTimestamp);
      }

      if (lines[i].contains(surveyPopupLine)) {
        surveyPopupTimestamp = lines[i].substring(0, 19);

        if (mostRecentBlockTriggerTimestamp.isNotEmpty) {
          final DateTime dateTime =
              DateTime.parse(mostRecentBlockTriggerTimestamp);
          final date =
              "${dateTime.day} ${monthsToString[dateTime.month]} ${dateTime.year}";

          if (!dateMap.containsKey(date)) {
            dateMap[date] = [
              TimestampInfo(
                  timestamp: mostRecentBlockTriggerTimestamp,
                  logFileName: logFileName)
            ];
          } else {
            dateMap[date]!.add(TimestampInfo(
                timestamp: mostRecentBlockTriggerTimestamp,
                logFileName: logFileName));
          }

          // Calculate the duration for each timestamp
          for (var j = 0; j < blockTriggerTimestamps.length; j++) {
            final nextTimestampIndex = j + 1;
            final nextTimestamp =
                (nextTimestampIndex < blockTriggerTimestamps.length)
                    ? blockTriggerTimestamps[nextTimestampIndex]
                    : surveyPopupTimestamp;

            final duration =
                calculateDuration(blockTriggerTimestamps[j], nextTimestamp);
            dateMap[date]!.last.duration = duration;
          }
        }
      }
    }
  }

  /// Calculates the duration between two timestamps.
  String calculateDuration(String startTime, String endTime) {
    final DateTime start = DateTime.parse(startTime);
    final DateTime end = DateTime.parse(endTime);
    final Duration difference = end.difference(start);
    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);
    final seconds = difference.inSeconds.remainder(60);

    return '$hours h $minutes min $seconds sec';
  }

  /// Displays an AlertDialog to prompt the user for their name and an optional
  /// comment.  The onChanged callback updates the userName and comment
  /// variables accordingly. The AlertDialog also includes two actions: the
  /// Cancel button, which dismisses the dialog when pressed, and the Save
  /// button, which triggers the saveCollectedTimestamps method with the
  /// provided comment.
  void promptUserName() {
    String comment = ''; // Initialize an empty comment
    String patientID = ''; // Initialize an empty patient ID
    // Initialize matchingFilenames list with empty strings
    var matchingFilenames = List<String>.filled(selectedTimings.length, '');

    for (var i = 0; i < selectedTimings.length; i++) {
      final parsedTimestamp = DateTime.parse(selectedTimings[i]);
      final formattedDate = DateFormat('yyMMdd').format(parsedTimestamp);
      matchingFilenames[i] = formattedDate;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Enter Details',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  autocorrect: false,
                  style: const TextStyle(color: Colors.black),
                  onChanged: (value) {
                    setState(() {
                      userName = value;
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'Your name',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  autocorrect: false,
                  style: const TextStyle(color: Colors.black),
                  onChanged: (value) {
                    setState(() {
                      patientID = value;
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'Patient ID',
                  ),
                ),
                const SizedBox(height: 24),
                Column(
                  children: const [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Complete the iEEG filenames:",
                        style: TextStyle(
                          color: Color(0xFF343633),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                for (var i = 0; i < selectedTimings.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            selectedTimings[i],
                            style: const TextStyle(color: Color(0xFF343633)),
                          ),
                        ),
                        TextField(
                          controller: TextEditingController(
                            text: matchingFilenames[i],
                          ),
                          style: TextStyle(
                            color: matchingFilenames[i] != null &&
                                    matchingFilenames[i].isNotEmpty
                                ? Colors.black
                                : Colors.grey,
                          ),
                          onChanged: (value) {
                            setState(() {
                              matchingFilenames[i] = value;
                            });
                          },
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.grey,
                                width: 1,
                              ),
                            ),
                            hintText:
                                'Matching iEEG Filename for ${selectedTimings[i]}',
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  style: const TextStyle(color: Colors.black),
                  onChanged: (value) {
                    setState(() {
                      comment = value;
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'Comment (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            // Cancel button to dismiss the dialog
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            // Save button to save the collected timestamps and pass the comment to the saveCollectedTimestamps method
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                saveCollectedTimestamps(comment, patientID,
                    matchingFilenames); // Pass the additional information to the saveCollectedTimestamps method
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  /// Updates the displayed timestamps after collecting new timestamps.
  void updateDisplayedTimestampsAfterCollection() {
    displayedTimestamps = dateBlockTimings
        .expand((dateBlock) => dateBlock.timestampInfos
            .map((timestampInfo) => timestampInfo.timestamp))
        .where((timestamp) => !collectedTimestamps.contains(timestamp))
        .toList();
  }

  /// Builds the UI of the LogParserScreen widget.
  ///
  /// This method is responsible for constructing the user interface of the log parser screen.
  /// It returns a [Scaffold] widget that contains an [AppBar] for the application title and actions,
  /// a [ListView.builder] widget to display the date blocks and timestamp information,
  /// and a [BottomAppBar] widget for the bottom navigation bar with select and save buttons.
  /// The UI is dynamically updated based on the state of the screen, such as selected timestamps
  /// and the visibility of collected data.
  @override
  Widget build(BuildContext context) {
    // Calculate the total number of timestamps
    int totalTimings = dateBlockTimings.isNotEmpty
        ? dateBlockTimings
            .map((dateBlock) => dateBlock.timestampInfos.length)
            .reduce((value, element) => value + element)
        : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cortify - Find the data'),
        actions: [
          // Add a button to show/hide the previously collected timestamps
          Row(
            children: [
              TextButton.icon(
                onPressed: toggleShowCollectedData,
                icon: Icon(
                  showCollectedData ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white,
                  size: 20,
                ),
                label: Text(
                  showCollectedData
                      ? 'Hide Collected    '
                      : 'Show Collected    ',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.0,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: dateBlockTimings.length,
        itemBuilder: (context, index) {
          final dateBlock = dateBlockTimings[index];

          // Filter the timestampInfos based on the "Show Collected" option
          final filteredTimestampInfos = dateBlock.timestampInfos
              .where((timestampInfo) =>
                  showCollectedData ||
                  displayedTimestamps.contains(timestampInfo.timestamp))
              .toList();

          // Skip displaying the date block if all timestamps are filtered out
          if (filteredTimestampInfos.isEmpty) {
            return Container();
          }

          return Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey,
                  width: 1.0,
                ),
              ),
            ),
            child: ExpansionTile(
              backgroundColor: Colors.black12,
              textColor: Colors.white,
              collapsedTextColor: Colors.white,
              collapsedIconColor: Colors.grey,
              initiallyExpanded: false,

              // Create the title of the date block
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateBlock.date,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),

              // Add the timestamp information inside the date block
              children: filteredTimestampInfos.map((timestampInfo) {
                final logFileName = timestampInfo.logFileName;
                final timestamp = timestampInfo.timestamp;
                final parsedTimestamp = DateTime.parse(timestamp);

                final hours = parsedTimestamp.hour;
                final minutes = parsedTimestamp.minute;
                final seconds = parsedTimestamp.second;

                final formattedTimestamp = '$hours h $minutes min $seconds sec';

                final isCollected = collectedTimestamps.contains(timestamp);
                final isDisplayed = displayedTimestamps.contains(timestamp);
                final isSelected = selectedTimings.contains(timestamp);

                return Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey,
                        width: 1.0,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(4.0),

                        // Add the CheckboxListTile for timestamp selection
                        child: CheckboxListTile(
                          enabled: isCollected ? false : true,

                          // Create the container for timestamp information
                          title: Container(
                            padding: const EdgeInsets.only(
                                bottom:
                                    8.0), // Adjust the bottom padding as needed
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Timestamp:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w300,
                                          fontSize: 13,
                                          color: isCollected
                                              ? Colors.grey
                                              : Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        formattedTimestamp,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isCollected
                                              ? Colors.grey
                                              : Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Minimum duration:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w300,
                                          fontSize: 12,
                                          color: isCollected
                                              ? Colors.grey
                                              : Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        timestampInfo.duration,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w300,
                                          fontSize: 13,
                                          color: isCollected
                                              ? Colors.grey
                                              : Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Create the container for the log file information
                          subtitle: Container(
                            padding: const EdgeInsets.only(
                                top: 4.0), // Adjust the top padding as needed
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Relevant log file:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w300,
                                    fontSize: 12,
                                    color: isCollected
                                        ? Colors.grey
                                        : Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  logFileName.split('/').last,
                                  style: TextStyle(
                                    color:
                                        isCollected ? Colors.grey : Colors.grey,
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          value: isCollected ? true : isSelected,
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                // Add the timestamp to selectedTimings
                                selectedTimings.add(timestamp);
                              } else {
                                // Remove the timestamp from selectedTimings
                                selectedTimings.remove(timestamp);
                              }
                            });
                          },
                        ),
                      )
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              onPressed: selectedTimings.length == totalTimings
                  ? null
                  : () {
                      setState(() {
                        // Select all timestamps
                        selectedTimings = List<String>.from(dateBlockTimings
                            .expand((dateBlock) => dateBlock.timestampInfos.map(
                                (timestampInfo) => timestampInfo.timestamp))
                            .toList());
                      });
                    },
              icon: Icon(
                Icons.check_box,
                color: selectedTimings.length == totalTimings
                    ? Colors.grey
                    : Colors.black,
              ),
              label: Text(
                'Select All',
                style: TextStyle(
                  color: selectedTimings.length == totalTimings
                      ? Colors.grey
                      : Colors.black,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: selectedTimings.isEmpty
                  ? null
                  : () {
                      setState(() {
                        // Unselect all timestamps
                        selectedTimings.clear();
                      });
                    },
              icon: Icon(
                Icons.check_box_outline_blank,
                color: selectedTimings.isEmpty ? Colors.grey : Colors.black,
              ),
              label: Text(
                'Unselect All',
                style: TextStyle(
                  color: selectedTimings.isEmpty ? Colors.grey : Colors.black,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                // Prompt the user for name and comment, then save selected timestamps
                promptUserName();
              },
              icon: const Icon(
                Icons.save,
                color: Colors.white,
              ),
              label: const Text(
                'Save Selected',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Represents a block of timestamps for a specific date.
class DateBlockTimings {
  final String date;
  final List<TimestampInfo> timestampInfos;
  bool isExpanded; // Indicates whether the date block is expanded in the UI.

  /// Creates a new instance of [DateBlockTimings]
  DateBlockTimings({
    required this.date,
    List<TimestampInfo>? timestampInfos,
    this.isExpanded = true,
  }) : timestampInfos = timestampInfos ?? [];
}

/// Represents information about a specific timestamp.
class TimestampInfo {
  final String timestamp;
  final String logFileName;
  String duration;

  /// Creates a new instance of [TimestampInfo]
  TimestampInfo({
    required this.timestamp,
    required this.logFileName,
    this.duration = '',
  });
}
