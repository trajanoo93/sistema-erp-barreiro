// lib/pages/criar_pedido_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CriarPedidoPage extends StatelessWidget {
  const CriarPedidoPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Criar Novo Pedido',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.orange,
      ),
      body: Center(
        child: Text(
          'Página para criar um novo pedido (Em construção)',
          style: GoogleFonts.poppins(fontSize: 16),
        ),
      ),
    );
  }
}