import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerWidget({super.key, required this.videoUrl});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Initialisation du contrôleur avec l'URL réseau de Firebase
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        // Une fois initialisé, on rafraîchit l'affichage et on lance la vidéo
        setState(() {
          _isInitialized = true;
        });
        _controller.play();
        _controller.setLooping(true); // La vidéo tourne en boucle
      }).catchError((error) {
        debugPrint("Erreur d'initialisation vidéo: $error");
      });
  }

  @override
  void dispose() {
    // ÉTAPE CRUCIALE: On ferme le contrôleur pour libérer les ressources du téléphone
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          VideoPlayer(_controller),
          // Barre de progression de lecture en bas de la vidéo
          VideoProgressIndicator(
            _controller,
            allowScrubbing: true,
            colors: const VideoProgressColors(
              playedColor: Colors.red,
              bufferedColor: Colors.grey,
              backgroundColor: Colors.black26,
            ),
          ),
        ],
      ),
    );
  }
}