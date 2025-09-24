import 'dart:io';
import 'package:flutter/material.dart';

class InfoScreen extends StatefulWidget {
  static const routeName = '/info-screen';

  final logFile;

  InfoScreen({required this.logFile});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  @override
  Widget build(BuildContext context) {
    const double fontSize = 20;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Information'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // TITLE
                const Text(
                  'Bienvenue sur Cortify !',
                  style: TextStyle(
                    fontSize: 24.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40.0),

                const Text(
                    'Notre application est conçue pour vous permettre d\'écouter vos contenus audiovisuels préférés tout en enregistrant votre activité cérébrale.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: fontSize,
                    )),
                const SizedBox(height: 20.0),
                const Text(
                    'Les informations récoltées nous aideront à mieux comprendre l\'impact de différents stimuli sur le fonctionnement du cerveau humain.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: fontSize,
                    )),
                const SizedBox(height: 30.0),

                // CORTIFY ICON
                ClipOval(
                  child: Image.asset(
                    'assets/images/icons/Cortify.png',
                    height: 300.0,
                    width: 300.0,
                  ),
                ),
                const SizedBox(height: 30.0),

                const Text(
                    'Toutes les données collectées seront anonymisées et ne seront utilisées qu\'à des fins de recherche.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: fontSize,
                    )),
                const SizedBox(height: 20.0),
                const Text(
                    'Si vous avez des questions ou des préoccupations, n\'hésitez pas à nous en parler !',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: fontSize,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



// Bienvenue sur Cortify ! 
// Notre application est conçue pour vous permettre d'écouter votre contenu 
// audiovisuel préféré pendant que nous enregistrons votre activité cérébrale. 
// Les informations collectées nous aideront à mieux comprendre l'impact de 
// différents stimuli sur le fonctionnement du cerveau humain. 
// Soyez assuré·e que les données collectées ne seront utilisées qu'à des fins 
// de recherche et resteront strictement confidentielles. 
// Si vous avez des questions ou des préoccupations, n'hésitez pas à nous en parler !")