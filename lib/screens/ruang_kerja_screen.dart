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
  List<Berkas> _tugasAktif = [];
  bool _isLoading = true;

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
        final List<dynamic> berkasJson = data['data'];
        setState(() {
          _tugasAktif = berkasJson.map((json) => Berkas.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Ruang Kerja', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.purple,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Colors.purple))
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: Colors.purple,
                child: Text('Ada ${_tugasAktif.length} tugas yang perlu perhatian Anda', 
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
              ),
              Expanded(
                child: _tugasAktif.isEmpty
                  ? Center(child: Text('Hore! Tidak ada tugas menumpuk.', style: TextStyle(color: Colors.grey.shade600)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _tugasAktif.length,
                      itemBuilder: (context, index) {
                        final tugas = _tugasAktif[index];
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.purple.shade50, shape: BoxShape.circle),
                              child: const Icon(Icons.warning_amber_rounded, color: Colors.purple),
                            ),
                            title: Text(tugas.noBerkas, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Pemohon: ${tugas.namaPemohon}\nStatus: ${tugas.status}'),
                            isThreeLine: true,
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
    );
  }
}