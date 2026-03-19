import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
// Importation cruciale pour détecter le Web
import 'package:flutter/foundation.dart' show kIsWeb;

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database?> get database async {
    // Si on est sur le Web, on ne cherche même pas à ouvrir la base de données
    if (kIsWeb) return null;

    if (_database != null) return _database!;
    _database = await _initDB('video_app_uts.db');
    return _database;
  }

  Future<Database?> _initDB(String filePath) async {
    // Sécurité supplémentaire pour le Web
    if (kIsWeb) return null;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE downloaded_videos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        cloudinary_id TEXT NOT NULL,
        titre TEXT NOT NULL,
        chemin_local TEXT NOT NULL,
        chemin_miniature TEXT,
        taille_fichier INTEGER,
        date_telechargement TEXT
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE downloaded_videos ADD COLUMN user_id TEXT DEFAULT 'anonyme'");
    }
  }

  Future<int> insertVideo(
      String userId,
      String cloudinaryId,
      String titre,
      String cheminLocal,
      {String? cheminMiniature, int? taille}
      ) async {
    // Sur le Web, on simule une insertion réussie (ou on ne fait rien)
    if (kIsWeb) return 0;

    final db = await instance.database;
    if (db == null) return 0;

    final data = {
      'user_id': userId,
      'cloudinary_id': cloudinaryId,
      'titre': titre,
      'chemin_local': cheminLocal,
      'chemin_miniature': cheminMiniature,
      'taille_fichier': taille,
      'date_telechargement': DateTime.now().toIso8601String(),
    };

    return await db.insert(
      'downloaded_videos',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getDownloadedVideosByUser(String userId) async {
    // Sur le Web, on renvoie simplement une liste vide sans faire crash l'app
    if (kIsWeb) return [];

    final db = await instance.database;
    if (db == null) return [];

    return await db.query(
      'downloaded_videos',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'date_telechargement DESC',
    );
  }

  Future<void> deleteVideo(int id, String cheminLocal) async {
    if (kIsWeb) return;

    final db = await instance.database;
    if (db == null) return;

    await db.delete(
      'downloaded_videos',
      where: 'id = ?',
      whereArgs: [id],
    );

    try {
      final file = File(cheminLocal);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print("Erreur suppression fichier : $e");
    }
  }
}