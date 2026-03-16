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

  factory Berkas.fromJson(Map<String, dynamic> json) {
    return Berkas(
      id: json['id'] ?? 0,
      // Membaca 'nomer_berkas' (sesuai DB asli Anda), jika tidak ada cari 'no_berkas'
      noBerkas: json['nomer_berkas'] ?? json['no_berkas'] ?? 'Tanpa Nomor',
      
      // Jika kolom Anda di database namanya hanya 'pemohon' tanpa 'nama_'
      namaPemohon: json['nama_pemohon'] ?? json['pemohon'] ?? 'Tanpa Nama',
      
      // Jika kolom Anda namanya hanya 'status' tanpa '_berkas'
      status: json['status_berkas'] ?? json['status'] ?? 'Tidak diketahui',
    );
  }
}