// lib/models/video.dart

class Video {
  final String id;
  final String title;
  final String videoUrl;
  final String thumbnailUrl;
  final String userId;

  Video({
    required this.id,
    required this.title,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.userId,
  });

  // Pour transformer les données venant de Firestore en objet Video
  factory Video.fromMap(Map<String, dynamic> data, String documentId) {
    return Video(
      id: documentId,
      title: data['title'] ?? '',
      videoUrl: data['videoUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      userId: data['userId'] ?? '',
    );
  }
}