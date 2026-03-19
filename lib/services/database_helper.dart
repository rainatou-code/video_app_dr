import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';


class DatabaseHelper {
  // Instance unique et privée (Singleton)
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // Getter pour accéder à la base de données
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('video_app_uts.db');
    return _database!;
  }

  // Initialisation et ouverture de la base
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  // Création de la table
  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE downloaded_videos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cloudinary_id TEXT NOT NULL,
        titre TEXT NOT NULL,
        chemin_local TEXT NOT NULL,
        chemin_miniature TEXT,
        taille_fichier INTEGER,
        date_telechargement TEXT
      )
    ''');
  }

  // --- FONCTION D'INSERTION ---
  Future<int> insertVideo(
      String cloudinaryId,
      String titre,
      String cheminLocal,
      {String? cheminMiniature, int? taille}
      ) async {
    // 1. On récupère l'accès à la base de données
    final db = await instance.database;

    // 2. On prépare les données sous forme de Map (clé: valeur)
    final data = {
      'cloudinary_id': cloudinaryId,
      'titre': titre,
      'chemin_local': cheminLocal,
      'chemin_miniature': cheminMiniature,
      'taille_fichier': taille,
      'date_telechargement': DateTime.now().toIso8601String(),
    };

    // 3. On insère dans la table 'downloaded_videos'
    return await db.insert(
      'downloaded_videos',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Récupérer toutes les vidéos de la base de données
  Future<List<Map<String, dynamic>>> getDownloadedVideos() async {
    // 1. Accéder à la base
    final db = await instance.database;

    // 2. Faire la requête (trié par date la plus récente en premier)
    final result = await db.query('downloaded_videos', orderBy: 'date_telechargement DESC');

    // 3. Retourner le résultat sous forme de liste
    return result;
  }

  // Fermer la base de données
  Future close() async {
    final db = await instance.database;
    db.close();
  }


  Future<void> deleteVideo(int id, String cheminLocal) async {
    // 1. On récupère l'accès à la base de données
    final db = await instance.database;

    // 2. On supprime la ligne dans SQLite
    await db.delete(
      'downloaded_videos',
      where: 'id = ?',
      whereArgs: [id],
    );

    // 3. On supprime le fichier physique du téléphone
    try {
      final file = File(cheminLocal);
      if (await file.exists()) {
        await file.delete();
        print("Fichier vidéo supprimé du stockage.");
      }
    } catch (e) {
      print("Erreur lors de la suppression du fichier : $e");
    }
  }
}




