import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // Pour kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:video_compress/video_compress.dart';

class AddVideoPage extends StatefulWidget {
  const AddVideoPage({super.key});

  @override
  State<AddVideoPage> createState() => _AddVideoPageState();
}

class _AddVideoPageState extends State<AddVideoPage> {
  final TextEditingController _titleController = TextEditingController();
  XFile? _videoFile;
  bool _isProcessing = false; // Pour la compression
  bool _isUploading = false;   // Pour l'envoi Cloudinary
  double _compressionProgress = 0.0;
  final ImagePicker _picker = ImagePicker();

  // VARIABLE POUR L'ABONNEMENT (Correctif page blanche)
  dynamic _subscription;

  @override
  void initState() {
    super.initState();
    _initCompressionListener();
  }

  // Initialisation propre de l'écouteur de progression
  void _initCompressionListener() {
    if (!kIsWeb) {
      // On annule l'ancien s'il existe par sécurité
      _subscription?.unsubscribe();

      _subscription = VideoCompress.compressProgress$.subscribe((progress) {
        if (mounted) { // TRÈS IMPORTANT : vérifie si le widget est encore affiché
          setState(() {
            _compressionProgress = progress;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    // NETTOYAGE CRUCIAL (Correctif page blanche)
    if (!kIsWeb) {
      _subscription?.unsubscribe(); // On coupe l'écoute du flux
      VideoCompress.cancelCompression(); // On stoppe toute compression en cours
      VideoCompress.deleteAllCache(); // On vide le cache temporaire
    }
    _titleController.dispose();
    super.dispose();
  }

  // --- ÉTAPE 1 : CHOISIR ET COMPRESSER (AVEC VÉRIFICATION DE TAILLE) ---
  Future<void> _pickAndCompressVideo() async {
    if (_isProcessing) return;

    final XFile? pickedFile = await _picker.pickVideo(source: ImageSource.gallery);

    if (pickedFile != null) {
      // Reset de l'état pour une nouvelle sélection
      setState(() {
        _compressionProgress = 0.0;
        _videoFile = null;
      });

      if (kIsWeb) {
        setState(() => _videoFile = pickedFile);
        _showSnackBar("Web : Vidéo sélectionnée", Colors.orange);
        return;
      }

      // LOGIQUE MOBILE : Vérification de la taille avant compression
      File originalFile = File(pickedFile.path);
      int originalSizeInBytes = await originalFile.length();
      double originalSizeMB = originalSizeInBytes / (1024 * 1024);

      // Si moins de 5 MB, on ne compresse pas
      if (originalSizeMB < 5.0) {
        setState(() => _videoFile = pickedFile);
        _showSnackBar("Fichier léger (${originalSizeMB.toStringAsFixed(1)}MB). Pas de compression.", Colors.blue);
        return;
      }

      setState(() => _isProcessing = true);

      try {
        await VideoCompress.deleteAllCache();

        MediaInfo? mediaInfo = await VideoCompress.compressVideo(
          pickedFile.path,
          quality: VideoQuality.MediumQuality,
          deleteOrigin: false,
          includeAudio: true,
        );

        if (mediaInfo != null && mediaInfo.file != null) {
          int compressedSizeInBytes = await mediaInfo.file!.length();

          // Comparaison pour éviter d'alourdir le fichier
          if (compressedSizeInBytes >= originalSizeInBytes) {
            setState(() => _videoFile = pickedFile);
            _showSnackBar("Original conservé (plus léger que la compression).", Colors.orange);
          } else {
            setState(() => _videoFile = XFile(mediaInfo.file!.path));
            double newSize = compressedSizeInBytes / (1024 * 1024);
            _showSnackBar("Réduit : ${originalSizeMB.toStringAsFixed(1)}MB -> ${newSize.toStringAsFixed(1)}MB", Colors.green);
          }
        }
      } catch (e) {
        _showSnackBar("Erreur : $e", Colors.red);
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  // --- ÉTAPE 2 : ENVOYER VERS CLOUDINARY ---
  Future<void> _uploadVideo() async {
    if (_videoFile == null || _titleController.text.trim().isEmpty) {
      _showSnackBar("Titre et vidéo requis", Colors.orange);
      return;
    }

    setState(() => _isUploading = true);

    try {
      String cloudName = "dazaouhna";
      String uploadPreset = "video-app-preset";

      var uri = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/video/upload");
      var request = http.MultipartRequest("POST", uri);

      var bytes = await _videoFile!.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: _videoFile!.name));
      request.fields['upload_preset'] = uploadPreset;
      request.fields['resource_type'] = "video";

      var response = await request.send();
      var responseData = await response.stream.toBytes();
      var responseString = String.fromCharCodes(responseData);
      var jsonResponse = jsonDecode(responseString);

      if (response.statusCode == 200) {
        String videoUrl = jsonResponse['secure_url'];
        String thumbnailUrl = videoUrl.replaceAll(RegExp(r'\.(mp4|mov|avi|wmv)$'), '.jpg');

        await FirebaseFirestore.instance.collection('videos').add({
          'titre': _titleController.text.trim(),
          'url': videoUrl,
          'thumbnailUrl': thumbnailUrl,
          'createdAt': FieldValue.serverTimestamp(),
          'createur': FirebaseAuth.instance.currentUser?.email ?? "Anonyme",
        });

        if (!kIsWeb) await VideoCompress.deleteAllCache();
        if (mounted) Navigator.pop(context);
      } else {
        _showSnackBar("Erreur Cloudinary : ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Erreur upload : $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Publier une vidéo")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: "Titre", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 30),

            if (_isProcessing)
              Column(
                children: [
                  LinearProgressIndicator(value: _compressionProgress / 100),
                  const SizedBox(height: 10),
                  Text("Traitement : ${_compressionProgress.toInt()}%"),
                ],
              )
            else
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(15)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.video_file, size: 50, color: _videoFile == null ? Colors.grey : Colors.blue),
                    Text(_videoFile == null ? "Aucun fichier choisi" : "Vidéo prête"),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _isProcessing || _isUploading ? null : _pickAndCompressVideo,
              icon: const Icon(Icons.add_a_photo),
              label: const Text("CHOISIR UNE VIDÉO"),
            ),

            const SizedBox(height: 50),

            if (_isUploading)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text("Envoi au Cloud..."),
                ],
              )
            else
              ElevatedButton(
                onPressed: _videoFile != null ? _uploadVideo : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  minimumSize: const Size.fromHeight(55),
                ),
                child: const Text("PUBLIER MAINTENANT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }
}