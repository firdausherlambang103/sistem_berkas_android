import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> login() async {
    setState(() => _isLoading = true);
    const String apiUrl = 'http://10.0.2.2:8000/api/login';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text,
          'password': _passwordController.text,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', responseData['token']);
        await prefs.setString('user_name', responseData['user']['name']);

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
          (Route<dynamic> route) => false,
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'] ?? 'Login Gagal'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error Koneksi: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo & Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade900,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
                  ),
                  child: const Icon(Icons.maps_home_work_rounded, size: 60, color: Colors.white),
                ),
                const SizedBox(height: 24),
                Text('SISTEM BERKAS', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue.shade900, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                const Text('Manajemen Administrasi Pertanahan', style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 40),

                // Form Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email_outlined, color: Colors.blue.shade900),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline, color: Colors.blue.shade900),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton(
                                onPressed: login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade900,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 5,
                                ),
                                child: const Text('MASUK', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}