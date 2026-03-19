import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'video_detail_page.dart';
import 'add_video_page.dart';
import 'services/download_service.dart';
import 'services/database_helper.dart'; // Import nécessaire pour la vérification locale

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String searchQuery = "";
  late Stream<QuerySnapshot> _videoStream;

  // --- 1. VARIABLES D'ÉTAT (TÉLÉCHARGEMENT & BADGES) ---
  bool _isDownloading = false;
  double _progress = 0.0;
  String _currentDownloadId = "";
  List<String> _downloadedIds = []; // Stocke les IDs des vidéos déjà présentes en local

  @override
  void initState() {
    super.initState();
    _videoStream = FirebaseFirestore.instance
        .collection('videos')
        .orderBy('createdAt', descending: true)
        .snapshots();

    // Charger la liste des vidéos déjà téléchargées au démarrage
    _refreshDownloadedList();
  }

  // --- FONCTION POUR METTRE À JOUR LA LISTE DES BADGES ---
  Future<void> _refreshDownloadedList() async {
    final localVideos = await DatabaseHelper.instance.getDownloadedVideos();
    if (mounted) {
      setState(() {
        _downloadedIds = localVideos.map((v) => v['cloudinary_id'] as String).toList();
      });
    }
  }

  // --- 2. FONCTION DE TÉLÉCHARGEMENT MISE À JOUR ---
  void _executetelechargement(String url, String title, String id) async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _currentDownloadId = id;
    });

    try {
      final downloadService = DownloadService();
      await downloadService.startDownload(
        url: url,
        fileName: title,
        cloudinaryId: id,
        onProgress: (p) {
          setState(() => _progress = p);
        },
      );

      // Mise à jour de la liste des badges après succès
      await _refreshDownloadedList();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("'$title' ajouté à vos vidéos hors-ligne"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur de téléchargement : $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _currentDownloadId = "";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Mon Catalogue Vidéo"),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: "Rechercher...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _videoStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Aucune vidéo"));

          final filteredDocs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return (data['titre'] ?? "").toString().toLowerCase().contains(searchQuery);
          }).toList();

          return ListView.builder(
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              final doc = filteredDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              final String videoId = doc.id;
              final String videoUrl = data['url'] ?? "";
              final String videoTitle = data['titre'] ?? "Sans titre";

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => VideoDetailPage(videoUrl: videoUrl, title: videoTitle))),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                            child: Image.network(
                              data['thumbnailUrl'] ?? videoUrl.replaceAll(RegExp(r'\.(mp4|mov|avi|wmv)$'), '.jpg'),
                              height: 200, width: double.infinity, fit: BoxFit.cover,
                            ),
                          ),
                          const Icon(Icons.play_circle_outline, color: Colors.white, size: 60),
                        ],
                      ),
                    ),
                    ListTile(
                      title: Text(videoTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Par ${data['createur'] ?? 'Anonyme'}"),

                      // --- 3. LOGIQUE D'AFFICHAGE DU BADGE OU DE LA PROGRESSION ---
                      trailing: _downloadedIds.contains(videoId)
                          ? const Icon(Icons.check_circle, color: Colors.green, size: 30) // Déjà téléchargé
                          : (_isDownloading && _currentDownloadId == videoId)
                          ? SizedBox(
                        width: 50,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            LinearProgressIndicator(value: _progress, color: Colors.blue),
                            const SizedBox(height: 4),
                            Text("${(_progress * 100).toInt()}%", style: const TextStyle(fontSize: 10)),
                          ],
                        ),
                      )
                          : IconButton(
                        icon: const Icon(Icons.cloud_download_outlined, color: Colors.blueAccent),
                        onPressed: () => _executetelechargement(videoUrl, videoTitle, videoId),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddVideoPage())),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}