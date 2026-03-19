import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'video_detail_page.dart';
import 'add_video_page.dart';
import 'services/download_service.dart';
import 'services/database_helper.dart';
import 'screens/downloaded_videos_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String searchQuery = "";
  late Stream<QuerySnapshot> _videoStream;

  bool _isDownloading = false;
  double _progress = 0.0;
  String _currentDownloadId = "";
  List<String> _downloadedIds = [];

  @override
  void initState() {
    super.initState();
    _videoStream = FirebaseFirestore.instance
        .collection('videos')
        .orderBy('createdAt', descending: true)
        .snapshots();

    _refreshDownloadedList();
  }

  Future<void> _refreshDownloadedList() async {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId != null) {
      final localVideos = await DatabaseHelper.instance.getDownloadedVideosByUser(userId);
      if (mounted) {
        setState(() {
          _downloadedIds = localVideos.map((v) => v['cloudinary_id'] as String).toList();
        });
      }
    }
  }

  // Fonction pour optimiser l'URL de l'image (réduit le poids pour éviter les Timeouts)
  String _getOptimizedUrl(String originalUrl) {
    if (originalUrl.contains("cloudinary.com")) {
      // On force la qualité automatique et une largeur de 400px pour économiser la data
      return originalUrl.replaceAll("/upload/", "/upload/c_scale,w_400,q_auto,f_auto/");
    }
    return originalUrl;
  }

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

      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(FirebaseAuth.instance.currentUser?.displayName ?? "Utilisateur"),
              accountEmail: Text(FirebaseAuth.instance.currentUser?.email ?? ""),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: Colors.blue, size: 40),
              ),
              decoration: const BoxDecoration(color: Colors.blue),
            ),
            ListTile(
              leading: const Icon(Icons.home, color: Colors.blue),
              title: const Text('Accueil'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.download_for_offline, color: Colors.blue),
              title: const Text('Mes Téléchargements'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DownloadedVideosScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Déconnexion'),
              onTap: () => FirebaseAuth.instance.signOut(),
            ),
          ],
        ),
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

              // Génération de l'URL de la miniature optimisée
              String thumbUrl = data['thumbnailUrl'] ?? videoUrl.replaceAll(RegExp(r'\.(mp4|mov|avi|wmv)$'), '.jpg');

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
                              _getOptimizedUrl(thumbUrl), // Utilisation de l'URL compressée
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              // --- CORRECTION : Gestion des erreurs de connexion ---
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 200,
                                  width: double.infinity,
                                  color: Colors.grey[300],
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.broken_image, color: Colors.grey, size: 50),
                                      SizedBox(height: 8),
                                      Text("Erreur réseau", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const Icon(Icons.play_circle_outline, color: Colors.white, size: 60),
                        ],
                      ),
                    ),
                    ListTile(
                      title: Text(videoTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Par ${data['createur'] ?? 'Anonyme'}"),
                      trailing: _downloadedIds.contains(videoId)
                          ? const Icon(Icons.check_circle, color: Colors.green, size: 30)
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