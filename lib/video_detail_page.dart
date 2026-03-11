import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/services.dart';

class VideoDetailPage extends StatefulWidget {
  final String videoUrl;
  final String title;

  const VideoDetailPage({
    super.key,
    required this.videoUrl,
    required this.title,
  });

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    // 1. Configuration du contrôleur de base
    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));

    try {
      await _videoPlayerController.initialize();

      // 2. Configuration de Chewie pour les contrôles et la rotation
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController.value.aspectRatio,

        // --- OPTIONS DE ROTATION ET PLEIN ÉCRAN ---
        allowFullScreen: true,
        // Bascule en paysage lors du passage en plein écran
        deviceOrientationsOnEnterFullScreen: [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        // Revient en portrait à la sortie du plein écran
        deviceOrientationsAfterFullScreen: [
          DeviceOrientation.portraitUp,
        ],

        // --- STYLE DES CONTRÔLES (PLAY/PAUSE INCLUS) ---
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.blue,
          handleColor: Colors.blueAccent,
          backgroundColor: Colors.grey.withOpacity(0.5),
          bufferedColor: Colors.white.withOpacity(0.5),
        ),

        placeholder: const Center(child: CircularProgressIndicator()),
        autoInitialize: true,
      );

      setState(() {});
    } catch (e) {
      print("Erreur initialisation vidéo: $e");
    }
  }

  @override
  void dispose() {
    // Libération des ressources pour éviter les fuites de mémoire
    _videoPlayerController.dispose();
    _chewieController?.dispose();

    // Forcer le retour en mode portrait en quittant la page
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Ambiance cinéma
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black.withOpacity(0.5),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: _chewieController != null &&
            _chewieController!.videoPlayerController.value.isInitialized
            ? Chewie(controller: _chewieController!)
            : const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            Text(
              "Chargement de la vidéo...",
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}