import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/berkas_model.dart';

class BerkasScreen extends StatefulWidget {
  const BerkasScreen({super.key});

  @override
  State<BerkasScreen> createState() => _BerkasScreenState();
}

class _BerkasScreenState extends State<BerkasScreen> {
  List<Berkas> _listBerkas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBerkas();
  }

  Future<void> _fetchBerkas() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    // Ingat ganti IP jika pakai device asli! (10.0.2.2 untuk emulator)
    final url = Uri.parse('http://10.0.2.2:8000/api/berkas');

    try {
      final response = await http.get(
        url,
        // INI KUNCINYA: Mengirimkan Bearer Token
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> berkasJson = responseData['data'];

        setState(() {
          _listBerkas = berkasJson.map((json) => Berkas.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Gagal memuat data');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: $e')),
      );
    }
  }

  // Fungsi pembantu untuk memberi warna berbeda pada status berkas
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'selesai': return Colors.green;
      case 'diproses': return Colors.orange;
      case 'ditolak': return Colors.red;
      default: return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Berkas'),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _listBerkas.isEmpty
              ? const Center(child: Text('Belum ada data berkas.'))
              : ListView.builder(
                  itemCount: _listBerkas.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (context, index) {
                    final berkas = _listBerkas[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.folder),
                        ),
                        title: Text(
                          berkas.noBerkas,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(berkas.namaPemohon),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(berkas.status).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _getStatusColor(berkas.status)),
                          ),
                          child: Text(
                            berkas.status,
                            style: TextStyle(
                              color: _getStatusColor(berkas.status),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}