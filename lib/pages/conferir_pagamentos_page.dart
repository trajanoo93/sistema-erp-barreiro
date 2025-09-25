import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class ConferirPagamentosPage extends StatefulWidget {
  const ConferirPagamentosPage({Key? key}) : super(key: key);

  @override
  State<ConferirPagamentosPage> createState() => _ConferirPagamentosPageState();
}

class _ConferirPagamentosPageState extends State<ConferirPagamentosPage> {
  String _paymentMethod = 'pix';
  String _statusFilter = 'todos';
  String _nameFilter = '';
  int _currentPage = 1;
  bool _isLoading = false;
  List<dynamic> _payments = [];
  bool _hasMore = true;
  final TextEditingController _nameFilterController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchPayments();
  }

  Future<void> logToFile(String message) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/sistema-erp-barreiro/app_logs.txt');
      await file.writeAsString('[${DateTime.now()}] $message\n', mode: FileMode.append);
    } catch (e) {
      debugPrint('Falha ao escrever log: $e');
    }
  }

  Future<void> _fetchPayments({bool append = false}) async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final startDate = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 90)));
      final endDate = DateFormat('yyyy-MM-dd').format(now);

      final url = _paymentMethod == 'pix'
          ? 'https://aogosto.com.br/proxy/consulta-pagarme.php?page=$_currentPage&size=10&unidade=Unidade%20Barreiro&start_date=$startDate&end_date=$endDate'
          : 'https://aogosto.com.br/proxy/consulta-stripe.php?unidade=Unidade%20Barreiro&start_date=$startDate&end_date=$endDate';

      await logToFile('Requisição ao proxy de pagamentos: $url');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200 || response.body.startsWith('<!DOCTYPE') || response.body.contains('<html')) {
        throw Exception('Erro ao buscar pagamentos: status ${response.statusCode}, body ${response.body}');
      }

      final data = jsonDecode(response.body);
      final List<dynamic> newPayments = data['data'] ?? [];
      final bool hasMore = data['has_more'] ?? (newPayments.length == 10);

      setState(() {
        if (append) {
          _payments.addAll(newPayments);
        } else {
          _payments = newPayments;
        }
        _hasMore = hasMore;
        logToFile('Pagamentos carregados: ${newPayments.length}, hasMore: $_hasMore');
      });
    } catch (error) {
      await logToFile('Erro ao buscar pagamentos: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao buscar pagamentos: $error', style: GoogleFonts.poppins(fontSize: 14)),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _loadMore() {
    if (!_hasMore || _isLoading) return;
    setState(() => _currentPage++);
    _fetchPayments(append: true);
  }

  void _refreshPayments() {
    setState(() {
      _currentPage = 1;
      _hasMore = true;
      _payments.clear();
      _nameFilter = '';
      _nameFilterController.clear();
    });
    _fetchPayments();
  }

  List<dynamic> get _filteredPayments {
    List<dynamic> filtered = _payments;

    if (_statusFilter != 'todos') {
      filtered = filtered.where((payment) {
        final status = payment['status'];
        return status == (_statusFilter == 'pendente' ? 'pending' : 'paid');
      }).toList();
    }

    if (_nameFilter.isNotEmpty) {
      filtered = filtered.where((payment) {
        final nomeCliente = _paymentMethod == 'pix'
            ? (payment['customer']?['name']?.toString() ?? 'N/A')
            : (payment['customer']?['name']?.toString() ?? payment['description']?.toString() ?? 'N/A');
        return nomeCliente.toLowerCase().contains(_nameFilter.toLowerCase());
      }).toList();
    }

    return filtered;
  }

  @override
  void dispose() {
    _nameFilterController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFFF28C38);
    final successColor = Colors.green.shade600;
    final errorColor = Colors.redAccent;

    return Scaffold(
      appBar: null, // No AppBar, consistent with criar_pedido_page.dart
      body: Column(
        children: [
          if (_isLoading)
            LinearProgressIndicator(
              backgroundColor: primaryColor.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              minHeight: 4,
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryColor,
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.payment,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Pagamentos da Unidade Barreiro',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Filtre e consulte os pagamentos realizados:',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: _paymentMethod,
                          decoration: InputDecoration(
                            labelText: 'Método de Pagamento',
                            labelStyle: GoogleFonts.poppins(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: primaryColor, width: 2),
                            ),
                            prefixIcon: Icon(Icons.payment, color: primaryColor, size: 28),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                          items: const [
                            DropdownMenuItem(value: 'pix', child: Text('Pix (Pagar.me)')),
                            DropdownMenuItem(value: 'credit_card', child: Text('Cartão de Crédito (Stripe)')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _paymentMethod = value!;
                              _currentPage = 1;
                              _hasMore = true;
                              _payments.clear();
                              _nameFilter = '';
                              _nameFilterController.clear();
                            });
                            _fetchPayments();
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _nameFilterController,
                                decoration: InputDecoration(
                                  labelText: 'Filtrar por Nome',
                                  labelStyle: GoogleFonts.poppins(
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: primaryColor, width: 2),
                                  ),
                                  prefixIcon: Icon(Icons.search, color: primaryColor, size: 28),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  suffixIcon: _nameFilter.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(Icons.clear, color: Colors.grey.shade600),
                                          onPressed: () {
                                            _nameFilterController.clear();
                                            setState(() => _nameFilter = '');
                                          },
                                        )
                                      : null,
                                ),
                                style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                                onChanged: (value) {
                                  _debounce?.cancel();
                                  _debounce = Timer(const Duration(milliseconds: 500), () {
                                    setState(() => _nameFilter = value);
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _statusFilter,
                                decoration: InputDecoration(
                                  labelText: 'Filtrar por Status',
                                  labelStyle: GoogleFonts.poppins(
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: primaryColor, width: 2),
                                  ),
                                  prefixIcon: Icon(Icons.filter_list, color: primaryColor, size: 28),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                                items: const [
                                  DropdownMenuItem(value: 'todos', child: Text('Todos')),
                                  DropdownMenuItem(value: 'pendente', child: Text('Pendente')),
                                  DropdownMenuItem(value: 'pago', child: Text('Pago')),
                                ],
                                onChanged: (value) => setState(() => _statusFilter = value!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                if (!_isLoading)
                                  BoxShadow(
                                    color: primaryColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _refreshPayments,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Text(
                                      'Atualizar',
                                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_filteredPayments.isEmpty && !_isLoading)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.grey.shade600,
                            size: 48,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Nenhum pagamento encontrado.',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredPayments.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _filteredPayments.length) {
                          return _hasMore
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          if (!_isLoading)
                                            BoxShadow(
                                              color: primaryColor.withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _loadMore,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          elevation: 0,
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                              )
                                            : Text(
                                                'Carregar Mais',
                                                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                                              ),
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink();
                        }

                        final payment = _filteredPayments[index];
                        final nomeCliente = _paymentMethod == 'pix'
                            ? (payment['customer']?['name']?.toString() ?? 'N/A')
                            : (payment['customer']?['name']?.toString() ?? payment['description']?.toString() ?? 'N/A');
                        final truncatedNomeCliente =
                            nomeCliente.length > 20 ? '${nomeCliente.substring(0, 20)}...' : nomeCliente;
                        final valorReais = (payment['amount'] / 100).toStringAsFixed(2);
                        final status = payment['status'];
                        final dataCriacao =
                            DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(payment['created_at']).toLocal());

                        return AnimatedOpacity(
                          opacity: 1.0,
                          duration: const Duration(milliseconds: 300),
                          child: Card(
                            elevation: 0,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    // Optional: Add tap interaction (e.g., show details)
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: status == 'pending' || status == 'unpaid' || status == 'failed'
                                                ? errorColor.withOpacity(0.1)
                                                : successColor.withOpacity(0.1),
                                          ),
                                          child: Icon(
                                            status == 'pending' || status == 'unpaid' || status == 'failed'
                                                ? Icons.warning_rounded
                                                : Icons.check_circle_rounded,
                                            color: status == 'pending' || status == 'unpaid' || status == 'failed'
                                                ? errorColor
                                                : successColor,
                                            size: 28,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                truncatedNomeCliente,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Valor: R\$ $valorReais',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  color: Colors.grey.shade600,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              Text(
                                                'Data: $dataCriacao',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  color: Colors.grey.shade600,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Chip(
                                          label: Text(
                                            status == 'pending' || status == 'unpaid' || status == 'failed' ? 'Pendente' : 'Pago',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          backgroundColor: status == 'pending' || status == 'unpaid' || status == 'failed'
                                              ? errorColor
                                              : successColor,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}