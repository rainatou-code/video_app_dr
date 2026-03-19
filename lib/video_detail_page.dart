import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/services.dart';
import 'dart:io'; // INDISPENSABLE pour utiliser File()
import '../services/download_service.dart';

class VideoDetailPage extends StatefulWidget {
  final String videoUrl; // Chemin local si isLocal est vrai, sinon URL Cloudinary
  final String title;
  final String? videoId;
  final bool isLocal; // AJOUT : Pour distinguer le mode lecture

  const VideoDetailPage({
    super.key,
    required this.videoUrl,
    required this.title,
    this.videoId,
    this.isLocal = false, // Par défaut, on charge depuis le réseau
  });

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;

  double _downloadProgress = 0;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    // MODIFICATION : Choix du contrôleur selon la source
    if (widget.isLocal) {
      _videoPlayerController = VideoPlayerController.file(File(widget.videoUrl));
    } else {
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    }

    try {
      await _videoPlayerController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        allowFullScreen: true,
        deviceOrientationsOnEnterFullScreen: [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        deviceOrientationsAfterFullScreen: [
          DeviceOrientation.portraitUp,
        ],
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

  Future<void> _handleDownload() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    try {
      await DownloadService().startDownload(
        url: widget.videoUrl,
        fileName: widget.title,
        cloudinaryId: widget.videoId ?? widget.title,
        onProgress: (p) {
          setState(() => _downloadProgress = p);
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vidéo enregistrée pour le mode hors-ligne !")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur de téléchargement : $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black.withOpacity(0.5),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _chewieController != null &&
                _chewieController!.videoPlayerController.value.isInitialized
                ? Chewie(controller: _chewieController!)
                : const Center(child: CircularProgressIndicator(color: Colors.white)),
          ),

          // N'afficher la zone de téléchargement QUE si la vidéo n'est pas déjà locale
          if (!widget.isLocal)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  if (_isDownloading) ...[
                    LinearProgressIndicator(
                      value: _downloadProgress,
                      backgroundColor: Colors.grey[800],
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "${(_downloadProgress * 100).toStringAsFixed(0)} %",
                      style: const TextStyle(color: Colors.white),
                    ),
                  ] else
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      icon: const Icon(Icons.download_for_offline),
                      label: const Text("TÉLÉCHARGER POUR HORS-LIGNE"),
                      onPressed: _handleDownload,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}