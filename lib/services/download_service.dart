import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import pour l'ID utilisateur
import 'database_helper.dart';

class DownloadService {
  // Configuration globale de Dio avec des Timeouts adaptés
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
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
      // 1. Définir l'emplacement de stockage sécurisé
      final directory = await getApplicationDocumentsDirectory();
      final String savePath = '${directory.path}/$fileName.mp4';

      // 2. Exécution du téléchargement avec gestion de la progression
      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total);
          }
        },
        deleteOnError: true,
      );

      // 3. Récupération de l'ID utilisateur et enregistrement SQLite
      final File videoFile = File(savePath);
      final String? userId = FirebaseAuth.instance.currentUser?.uid; //

      if (await videoFile.exists() && userId != null) {
        // On passe désormais le userId à la fonction insertVideo
        await DatabaseHelper.instance.insertVideo(
          userId, // ID de l'utilisateur connecté
          cloudinaryId,
          fileName,
          savePath,
          taille: await videoFile.length(),
        );
      } else if (userId == null) {
        throw Exception("Utilisateur non connecté. Impossible d'enregistrer la vidéo.");
      }

    } on DioException catch (e) {
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
      print("Erreur : Délai de connexion dépassé.");
    } else if (e.type == DioExceptionType.receiveTimeout) {
      print("Erreur : La connexion a été perdue pendant le téléchargement.");
    } else if (e.type == DioExceptionType.badResponse) {
      print("Erreur Serveur : ${e.response?.statusCode} - Vérifiez l'URL.");
    } else {
      print("Erreur Réseau : ${e.message}");
    }
  }
}