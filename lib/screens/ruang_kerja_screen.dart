import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/berkas_model.dart';

class RuangKerjaScreen extends StatefulWidget {
  const RuangKerjaScreen({super.key});

  @override
  State<RuangKerjaScreen> createState() => _RuangKerjaScreenState();
}

class _RuangKerjaScreenState extends State<RuangKerjaScreen> {
  bool _isLoading = true;
  
  // Menyiapkan 3 wadah penampung data untuk masing-masing tab
  List<Berkas> _mejaSaya = [];
  List<Berkas> _menunggu = [];
  List<Berkas> _selesai = [];

  @override
  void initState() {
    super.initState();
    _fetchRuangKerja();
  }

  Future<void> _fetchRuangKerja() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/api/ruang-kerja'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        setState(() {
          // Memasukkan data dari Laravel ke masing-masing wadah (Tab)
          _mejaSaya = (data['data']['meja_saya'] as List).map((json) => Berkas.fromJson(json)).toList();
          _menunggu = (data['data']['menunggu'] as List).map((json) => Berkas.fromJson(json)).toList();
          _selesai = (data['data']['selesai'] as List).map((json) => Berkas.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Gagal memuat data (Status: ${response.statusCode})');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Terjadi kesalahan: $e')));
      }
    }
  }

  // --- WIDGET PEMBANTU UNTUK MEMBUAT DAFTAR BERKAS ---
  // Agar kita tidak perlu menulis ulang kode ListView untuk setiap Tab
  Widget _buildListBerkas(List<Berkas> listBerkas) {
    if (listBerkas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Belum ada berkas di ruangan ini', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 80), // bottom 80 agar tidak tertutup tombol
      itemCount: listBerkas.length,
      itemBuilder: (context, index) {
        final berkas = listBerkas[index];
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            leading: CircleAvatar(
              backgroundColor: Colors.purple.shade50,
              radius: 24,
              child: const Icon(Icons.description_outlined, color: Colors.purple),
            ),
            title: Text(berkas.noBerkas, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text('Pemohon: ${berkas.namaPemohon}\nStatus: ${berkas.status}', style: const TextStyle(height: 1.3)),
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            onTap: () {
              // Aksi saat berkas diklik (Membuka Detail)
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // DefaultTabController adalah KUNCI untuk membuat menu Tab yang bisa digeser (swipe)
    return DefaultTabController(
      length: 3, // Jumlah Menu Tab
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('Ruang Kerja', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.purple,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          
          // --- BAGIAN HEADER MENU TAB ---
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.amber, // Warna garis bawah saat tab aktif
            indicatorWeight: 4,
            tabs: [
              Tab(text: 'Meja Saya'),
              Tab(text: 'Menunggu'),
              Tab(text: 'Selesai'),
            ],
          ),
        ),
        
        // --- BAGIAN ISI TAB ---
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.purple))
            : TabBarView(
                children: [
                  _buildListBerkas(_mejaSaya), // Isi Tab 1
                  _buildListBerkas(_menunggu), // Isi Tab 2
                  _buildListBerkas(_selesai),  // Isi Tab 3
                ],
              ),
              
        // --- TOMBOL BUAT BERKAS BARU ---
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            // Aksi memunculkan form inputan berkas baru
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Mengarahkan ke halaman Buat Berkas...')),
            );
          },
          backgroundColor: Colors.purple,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Buat Berkas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}