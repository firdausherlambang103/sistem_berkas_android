class Berkas {
  final int id;
  final String noBerkas;
  final String namaPemohon;
  final String status;

  Berkas({
    required this.id,
    required this.noBerkas,
    required this.namaPemohon,
    required this.status,
  });

  // Mengubah data JSON dari Laravel menjadi Objek Dart
  factory Berkas.fromJson(Map<String, dynamic> json) {
    return Berkas(
      id: json['id'],
      noBerkas: json['no_berkas'] ?? 'Tanpa Nomor',
      namaPemohon: json['nama_pemohon'] ?? 'Tanpa Nama',
      status: json['status_berkas'] ?? 'Tidak diketahui',
    );
  }
}