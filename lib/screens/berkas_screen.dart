import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/berkas_model.dart';
import 'detail_berkas_screen.dart'; // Import halaman detail

class BerkasScreen extends StatefulWidget {
  const BerkasScreen({super.key});

  @override
  State<BerkasScreen> createState() => _BerkasScreenState();
}

class _BerkasScreenState extends State<BerkasScreen> {
  bool _isLoading = true;
  List<Berkas> _listBerkas = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchDaftarBerkas();
  }

  Future<void> _fetchDaftarBerkas() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    // Sesuaikan IP dengan server/emulator (10.0.2.2 untuk emulator Android)
    final url = Uri.parse('http://10.0.2.2:8000/api/berkas');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        // Menyesuaikan dengan standar response Laravel yang membungkus data dalam array 'data'
        final List<dynamic> data = jsonResponse['data'] ?? jsonResponse;

        setState(() {
          // Mapping data JSON ke dalam List object Berkas
          _listBerkas = data.map((item) {
            // Jika di model Berkas.dart sudah ada factory Berkas.fromJson(json),
            // Anda bisa menggunakan: return Berkas.fromJson(item);
            
            // Jika belum ada, mapping manual seperti ini:
            return Berkas(
              id: item['id'],
              noBerkas: item['nomer_berkas'] ?? '-',
              namaPemohon: item['nama_pemohon'] ?? '-',
              status: item['status'] ?? 'pending',
            );
          }).toList();
          
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Gagal memuat data (Status: ${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Terjadi kesalahan koneksi: $e';
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'selesai': return Colors.teal;
      case 'diproses': return Colors.amber.shade700;
      case 'ditolak': return Colors.redAccent;
      case 'menunggu': return Colors.blue.shade600;
      case 'pending': return Colors.orange;
      default: return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Daftar Berkas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Kondisi 1: Sedang Loading
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Kondisi 2: Terjadi Error (Koneksi mati, API salah, dsb)
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(_errorMessage, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = '';
                  });
                  _fetchDaftarBerkas();
                },
                icon: const Icon(Icons.refresh),
                label: const Text("Coba Lagi"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900),
              )
            ],
          ),
        ),
      );
    }

    // Kondisi 3: Data Kosong
    if (_listBerkas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Belum ada data berkas', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          ],
        ),
      );
    }

    // Kondisi 4: Menampilkan Daftar Data Berkas
    return RefreshIndicator(
      onRefresh: _fetchDaftarBerkas,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _listBerkas.length,
        itemBuilder: (context, index) {
          final berkas = _listBerkas[index];
          
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                // Navigasi ke Halaman DetailBerkasScreen dengan membawa object 'berkas'
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailBerkasScreen(berkas: berkas),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.blue.shade50,
                      child: Icon(Icons.folder_copy_rounded, color: Colors.blue.shade900),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            berkas.noBerkas,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade900),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Pemohon: ${berkas.namaPemohon}",
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(berkas.status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              berkas.status.toUpperCase(),
                              style: TextStyle(
                                color: _getStatusColor(berkas.status),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}