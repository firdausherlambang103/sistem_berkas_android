import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_config.dart';
import 'detail_berkas_screen.dart'; 
import '../models/berkas_model.dart'; 

class RuangKerjaScreen extends StatefulWidget {
  const RuangKerjaScreen({super.key});

  @override
  State<RuangKerjaScreen> createState() => _RuangKerjaScreenState();
}

class _RuangKerjaScreenState extends State<RuangKerjaScreen> {
  bool _isLoading = true;
  List<dynamic> _menunggu = [];
  List<dynamic> _mejaSaya = [];
  List<dynamic> _ditunda = []; // Mengganti _selesai menjadi _ditunda

  @override
  void initState() {
    super.initState();
    _fetchRuangKerja();
  }

  Future<void> _fetchRuangKerja() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    
    // Sesuaikan IP dengan IP Server/Emulator Anda
    final url = Uri.parse('${ApiConfig.baseUrl}/api/ruang-kerja'); 

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        setState(() {
          _menunggu = data['menunggu'] ?? [];
          _mejaSaya = data['meja_saya'] ?? [];
          _ditunda = data['ditunda'] ?? []; // Membaca data ditunda dari JSON
          _isLoading = false;
        });
      } else {
        throw Exception("Gagal memuat data");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e')));
    }
  }

  String _formatWaktu(String? datetime) {
    if (datetime == null || datetime.isEmpty) return 'Belum ada waktu';
    try {
      DateTime dt = DateTime.parse(datetime).toLocal();
      return "${dt.day}-${dt.month}-${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return datetime;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('Ruang Kerja', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.blue.shade900,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            isScrollable: true, // Agar tab tidak berdesakan jika teksnya panjang
            indicatorColor: Colors.white,
            indicatorWeight: 4,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(text: "Masuk (${_menunggu.length})"),
              Tab(text: "Meja Saya (${_mejaSaya.length})"),
              Tab(text: "Ditunda (${_ditunda.length})"),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildListCard(_menunggu, isMenunggu: true),
                  _buildListCard(_mejaSaya, isMenunggu: false),
                  _buildListCard(_ditunda, isMenunggu: false),
                ],
              ),
      ),
    );
  }

  Widget _buildListCard(List<dynamic> listData, {required bool isMenunggu}) {
    if (listData.isEmpty) {
      return Center(
        child: Text('Tidak ada berkas', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: listData.length,
      itemBuilder: (context, index) {
        final item = listData[index];
        String noBerkas = item['nomer_berkas'] ?? item['no_berkas'] ?? 'Tanpa Nomor';
        String pemohon = item['nama_pemohon'] ?? 'Tanpa Nama';
        // Web menggunakan updated_at untuk sorting, kita tampilkan waktu tersebut
        String waktu = item['updated_at'] ?? item['created_at'] ?? '';
        
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  noBerkas,
                  style: TextStyle(color: Colors.blue.shade700, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  pemohon,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time_filled, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(
                      _formatWaktu(waktu),
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Berkas dataBerkas = Berkas(
                        id: item['id'] ?? 0,
                        noBerkas: noBerkas,
                        namaPemohon: pemohon,
                        status: item['status'] ?? '',
                      );
                      
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailBerkasScreen(berkas: dataBerkas),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isMenunggu ? Colors.green.shade600 : Colors.blue.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      isMenunggu ? "Terima Berkas" : "Detail Berkas", // Mengubah teks tombol agar lebih sesuai web
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}