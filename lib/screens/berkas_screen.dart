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
    final url = Uri.parse('http://10.0.2.2:8000/api/berkas');

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> berkasJson = responseData['data'];

        setState(() {
          _listBerkas = berkasJson.map((json) => Berkas.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Gagal memuat data dari server (Status: ${response.statusCode})');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Terjadi kesalahan: $e'), backgroundColor: Colors.red));
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'selesai': return Colors.teal;
      case 'diproses': return Colors.amber.shade700;
      case 'ditolak': return Colors.redAccent;
      default: return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Daftar Berkas', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _listBerkas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_off_outlined, size: 80, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('Belum ada data berkas', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _listBerkas.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  itemBuilder: (context, index) {
                    final berkas = _listBerkas[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.description_outlined, color: Colors.blue.shade800),
                        ),
                        title: Text(
                          berkas.noBerkas,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(berkas.namaPemohon, style: TextStyle(color: Colors.grey.shade600)),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getStatusColor(berkas.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            berkas.status.toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(berkas.status),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        onTap: () {
                          // Siap untuk Fase Detail Berkas nanti
                        },
                      ),
                    );
                  },
                ),
    );
  }
}