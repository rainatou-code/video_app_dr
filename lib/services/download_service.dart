import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'database_helper.dart';

class DownloadService {
  // Configuration globale de Dio avec des Timeouts adaptés au contexte local
  final Dio _dio = Dio(
    BaseOptions(
      // Temps max pour établir la connexion (15 secondes)
      connectTimeout: const Duration(seconds: 15),
      // Temps max entre deux paquets de données (60 secondes)
      // On laisse une marge car le débit peut chuter brusquement
      receiveTimeout: const Duration(seconds: 60),
      // Temps max pour envoyer une requête
      sendTimeout: const Duration(seconds: 15),
    ),
  );

  /// Démarre le téléchargement d'une vidéo et l'enregistre en local
  Future<void> startDownload({
    required String url,
    required String fileName,
    required String cloudinaryId,
    required Function(double) onProgress,
  }) async {
    try {
      // 1. Définir l'emplacement de stockage sécurisé (Dossier App Documents)
      final directory = await getApplicationDocumentsDirectory();
      final String savePath = '${directory.path}/$fileName.mp4';

      // 2. Exécution du téléchargement avec gestion de la progression
      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            // Calcul du pourcentage (0.0 à 1.0) pour la barre de progression
            onProgress(received / total);
          }
        },
        // Très important : supprime le fichier partiel si le téléchargement échoue
        deleteOnError: true,
      );

      // 3. Vérification du fichier et enregistrement SQLite
      final File videoFile = File(savePath);
      if (await videoFile.exists()) {
        await DatabaseHelper.instance.insertVideo(
          cloudinaryId,
          fileName,
          savePath,
          taille: await videoFile.length(),
        );
      }

    } on DioException catch (e) {
      // Gestion des erreurs spécifiques à Dio (Timeouts, Réseau, etc.)
      _handleDioError(e);
      rethrow;
    } catch (e) {
      print("Erreur inattendue dans DownloadService : $e");
      rethrow;
    }
  }

  /// Logique de traitement des erreurs pour faciliter le débogage
  void _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout) {
      print("Erreur : Délai de connexion dépassé. Le serveur ne répond pas.");
    } else if (e.type == DioExceptionType.receiveTimeout) {
      print("Erreur : La connexion a été perdue pendant le téléchargement.");
    } else if (e.type == DioExceptionType.badResponse) {
      print("Erreur Serveur : ${e.response?.statusCode} - Vérifiez l'URL Cloudinary.");
    } else {
      print("Erreur Réseau : ${e.message}");
    }
  }
}