import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Importation de kIsWeb pour détecter la plateforme
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/database_helper.dart';
import '../video_detail_page.dart';

class DownloadedVideosScreen extends StatefulWidget {
  const DownloadedVideosScreen({super.key});

  @override
  State<DownloadedVideosScreen> createState() => _DownloadedVideosScreenState();
}

class _DownloadedVideosScreenState extends State<DownloadedVideosScreen> {
  // On récupère l'ID de l'utilisateur actuel
  final String? userId = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mes Vidéos Hors-ligne"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // ÉTAPE 1 : Vérification si on est sur le Web
    if (kIsWeb) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.computer, size: 80, color: Colors.orange),
            SizedBox(height: 20),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 30),
              child: Text(
                "Le mode hors-ligne est disponible uniquement sur l'application mobile (Android).",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    // ÉTAPE 2 : Vérification de la connexion
    if (userId == null) {
      return const Center(child: Text("Veuillez vous connecter pour voir vos téléchargements."));
    }

    // ÉTAPE 3 : Logique Mobile (Android)
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper.instance.getDownloadedVideosByUser(userId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam_off, size: 80, color: Colors.grey),
                SizedBox(height: 10),
                Text("Vous n'avez aucun téléchargement."),
              ],
            ),
          );
        }

        final videos = snapshot.data!;

        return ListView.builder(
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final video = videos[index];

            return ListTile(
              leading: const Icon(Icons.play_circle_fill, color: Colors.blue, size: 40),
              title: Text(video['titre'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Téléchargée le : ${video['date_telechargement'].substring(0, 10)}"),
              trailing: IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                onPressed: () => _confirmDelete(video),
              ),
              onTap: () => _lireVideo(video['chemin_local'], video['titre']),
            );
          },
        );
      },
    );
  }

  // Fonction de suppression (Mobile uniquement)
  Future<void> _confirmDelete(Map<String, dynamic> video) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Supprimer ?"),
        content: Text("Supprimer '${video['titre']}' de ce téléphone ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Supprimer", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteVideo(video['id'], video['chemin_local']);
      setState(() {}); // Rafraîchir la liste après suppression
    }
  }

  void _lireVideo(String path, String titre) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoDetailPage(
          videoUrl: path,
          title: titre,
          isLocal: true,
        ),
      ),
    );
  }
}