import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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
  bool _isProcessing = false;
  bool _isUploading = false;
  double _compressionProgress = 0.0;
  final ImagePicker _picker = ImagePicker();
  dynamic _subscription;

  @override
  void initState() {
    super.initState();
    _initCompressionListener();
  }

  void _initCompressionListener() {
    if (!kIsWeb) {
      _subscription?.unsubscribe();
      _subscription = VideoCompress.compressProgress$.subscribe((progress) {
        if (mounted) {
          setState(() {
            _compressionProgress = progress;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      _subscription?.unsubscribe();
      VideoCompress.cancelCompression();
      VideoCompress.deleteAllCache();
    }
    _titleController.dispose();
    super.dispose();
  }

  Future<double> _getFileSizeMB(XFile file) async {
    int bytes = await file.length();
    return bytes / (1024 * 1024);
  }

  // --- ÉTAPE 1 : CHOISIR ET COMPRESSER ---
  Future<void> _pickAndCompressVideo() async {
    if (_isProcessing) return;

    final XFile? pickedFile = await _picker.pickVideo(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _compressionProgress = 0.0;
        _videoFile = null;
      });

      double originalSizeMB = await _getFileSizeMB(pickedFile);

      if (kIsWeb) {
        setState(() => _videoFile = pickedFile);
        _showSnackBar("Web : Original (${originalSizeMB.toStringAsFixed(1)} Mo)", Colors.orange);
        return;
      }

      setState(() => _isProcessing = true);

      try {
        await VideoCompress.deleteAllCache();

        MediaInfo? mediaInfo = await VideoCompress.compressVideo(
          pickedFile.path,
          quality: VideoQuality.DefaultQuality,
          deleteOrigin: false,
          includeAudio: true,
          frameRate: 30,
        );

        if (mediaInfo != null && mediaInfo.file != null) {
          double compressedSizeMB = await mediaInfo.file!.length() / (1024 * 1024);

          if (compressedSizeMB >= originalSizeMB) {
            setState(() => _videoFile = pickedFile);
            _showSnackBar("Déjà optimisée (${originalSizeMB.toStringAsFixed(1)} Mo)", Colors.blue);
          } else {
            setState(() => _videoFile = XFile(mediaInfo.file!.path));
            _showSnackBar(
                "✅ Compressée : ${originalSizeMB.toStringAsFixed(1)} Mo ➡️ ${compressedSizeMB.toStringAsFixed(1)} Mo",
                Colors.green
            );
          }
        }
      } catch (e) {
        _showSnackBar("Erreur de compression : $e", Colors.red);
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  // --- ÉTAPE 2 : ENVOYER VERS CLOUDINARY ---
  Future<void> _uploadVideo() async {
    if (_videoFile == null || _titleController.text.trim().isEmpty) {
      _showSnackBar("Titre vide ou aucune vidéo choisie.", Colors.orange);
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
      var responseString = utf8.decode(responseData);
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
      _showSnackBar("Échec de l'envoi : $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: color)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Publication Vidéo")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: "Titre de la vidéo",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 30),

            if (_isProcessing)
              Column(
                children: [
                  const Text("Compression haute qualité...", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: _compressionProgress / 100),
                  const SizedBox(height: 10),
                  Text("${_compressionProgress.toInt()}% effectué"),
                ],
              )
            else
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey[300]!)
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                        _videoFile == null ? Icons.video_file_outlined : Icons.check_circle,
                        size: 60,
                        color: _videoFile == null ? Colors.grey : Colors.green
                    ),
                    const SizedBox(height: 10),
                    Text(_videoFile == null ? "Aucune vidéo" : "Vidéo sélectionnée"),
                  ],
                ),
              ),

            const SizedBox(height: 25),

            ElevatedButton.icon(
              onPressed: _isProcessing || _isUploading ? null : _pickAndCompressVideo,
              icon: const Icon(Icons.add_a_photo),
              label: const Text("CHOISIR UNE VIDÉO"),
              style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
            ),

            const SizedBox(height: 40),

            if (_isUploading)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _videoFile != null ? _uploadVideo : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  minimumSize: const Size.fromHeight(60),
                ),
                child: const Text("PUBLIER", style: TextStyle(color: Colors.white)),
              ),
          ],
        ),
      ),
    );
  }
}