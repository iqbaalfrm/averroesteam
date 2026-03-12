class AhliSyariahModel {
  AhliSyariahModel({
    required this.id,
    required this.nama,
    required this.spesialis,
    required this.kategoriId,
    required this.rating,
    required this.totalReview,
    required this.pengalamanTahun,
    required this.fotoUrl,
    required this.noWhatsapp,
    required this.isOnline,
    required this.isVerified,
    required this.hargaPerSesi,
  });

  factory AhliSyariahModel.fromJson(Map<String, dynamic> json) {
    return AhliSyariahModel(
      id: json['_id'] ?? '',
      nama: json['nama'] ?? '',
      spesialis: json['spesialis'] ?? '',
      kategoriId: json['kategori_id'] ?? '',
      rating: (json['rating'] ?? 0.0).toDouble(),
      totalReview: json['total_review'] ?? 0,
      pengalamanTahun: json['pengalaman_tahun'] ?? 0,
      fotoUrl: json['foto_url'] ?? '',
      noWhatsapp: json['no_whatsapp'] ?? '',
      isOnline: json['is_online'] ?? false,
      isVerified: json['is_verified'] ?? false,
      hargaPerSesi: json['harga_per_sesi'] ?? 0,
    );
  }

  final String id;
  final String nama;
  final String spesialis;
  final String kategoriId;
  final double rating;
  final int totalReview;
  final int pengalamanTahun;
  final String fotoUrl;
  final String noWhatsapp;
  final bool isOnline;
  final bool isVerified;
  final int hargaPerSesi;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      '_id': id,
      'nama': nama,
      'spesialis': spesialis,
      'kategori_id': kategoriId,
      'rating': rating,
      'total_review': totalReview,
      'pengalaman_tahun': pengalamanTahun,
      'foto_url': fotoUrl,
      'no_whatsapp': noWhatsapp,
      'is_online': isOnline,
      'is_verified': isVerified,
      'harga_per_sesi': hargaPerSesi,
    };
  }
}
