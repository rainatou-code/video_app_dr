import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import 'dart:io';
// Assure-toi que le chemin d'importation vers ton dossier screens est correct
import 'video_detail_page.dart';

class DownloadedVideosScreen extends StatefulWidget {
  const DownloadedVideosScreen({super.key});

  @override
  _DownloadedVideosScreenState createState() => _DownloadedVideosScreenState();
}

class _DownloadedVideosScreenState extends State<DownloadedVideosScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mes Vidéos Hors-ligne"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseHelper.instance.getDownloadedVideos(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.video_off_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("Aucune vidéo téléchargée."),
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
                  onPressed: () async {
                    bool? confirm = await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Supprimer localement ?"),
                        content: Text("Voulez-vous supprimer '${video['titre']}' de votre téléphone ?"),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text("Annuler")
                          ),
                          TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text("Supprimer", style: TextStyle(color: Colors.red))
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await DatabaseHelper.instance.deleteVideo(
                          video['id'],
                          video['chemin_local']
                      );

                      setState(() {});

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Fichier supprimé pour libérer de l'espace."))
                        );
                      }
                    }
                  },
                ),
                // MISE À JOUR : On passe maintenant le chemin ET le titre
                onTap: () => _lireVideo(video['chemin_local'], video['titre']),
              );
            },
          );
        },
      ),
    );
  }

  // MISE À JOUR : La fonction reçoit maintenant le titre pour l'afficher dans le lecteur
  void _lireVideo(String path, String titre) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoDetailPage(
          videoUrl: path,  // Chemin local (/data/user/0/...)
          title: titre,    // Titre de la vidéo
          isLocal: true,   // Active le mode lecture de fichier
        ),
      ),
    );
  }
}