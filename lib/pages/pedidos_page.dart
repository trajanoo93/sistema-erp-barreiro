// lib/pages/pedidos_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../models/pedido_model.dart';
import '../services/pedido_service.dart';
import 'pedido_detail_dialog.dart';

class LtrTextField extends StatelessWidget {
  final String labelText;
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String) onChanged;
  final List<TextInputFormatter> inputFormatters;

  const LtrTextField({
    super.key,
    required this.labelText,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFFF28C38);

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        hintText: labelText,
        prefixIcon: Icon(Icons.search_rounded, color: primary),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                tooltip: 'Limpar',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: primary, width: 1.2),
        ),
      ),
      textAlign: TextAlign.left,
      inputFormatters: inputFormatters,
      keyboardType: TextInputType.text,
      onChanged: onChanged,
      onEditingComplete: () {
        if (!focusNode.hasFocus) {
          FocusScope.of(context).requestFocus(focusNode);
        }
      },
    );
  }
}

class PedidosPage extends StatefulWidget {
  const PedidosPage({Key? key}) : super(key: key);

  @override
  State<PedidosPage> createState() => PedidosPageState();
}

class PedidosPageState extends State<PedidosPage> {
  final Color primaryColor = const Color(0xFFF28C38);

  List<Pedido> _allPedidos = [];
  List<Pedido> _filteredPedidos = [];
  List<String> _previousPedidoIds = [];
  List<String> _printedPedidoIds = [];
  List<Pedido> _problematicPedidos = []; // Lista para pedidos com problemas

  String _searchText = '';
  DateTime? _startDate;
  DateTime? _endDate;

  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String _selectedStatus = 'Todos';
  bool _hideCompleted = false;
  bool _isInitialLoading = true;

  Timer? _debounceTimer;
  Timer? _fetchTimer;

  final List<String> _statusOptions = ['Todos', 'Registrado', 'Saiu pra Entrega', 'Concluído', 'Cancelado'];

  final List<String> _orderStatusOptions = [
    '-',
    'Registrado',
    'Agendado',
    'Saiu pra Entrega',
    'Concluído',
    'Cancelado',
  ];

  bool _isFetching = false;
  final Set<String> _printingNow = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    _startDateController.text = DateFormat('dd/MM/yyyy').format(_startDate!);
    _endDateController.text = DateFormat('dd/MM/yyyy').format(_endDate!);
    _searchController.text = _searchText;

    _searchController.addListener(() {
      if (_searchController.text != _searchText) {
        setState(() => _searchText = _searchController.text);
        _filterPedidos();
      }
    });

    _loadPreviousPedidoIds().then((_) async {
      await _loadPrintedPedidoIds();
      await _fetchPedidosSilently();
      if (mounted) setState(() => _isInitialLoading = false);
    });

    _fetchTimer = Timer.periodic(const Duration(minutes: 1), (_) => _fetchPedidosSilently());
  }

@override
  void dispose() {
    _fetchTimer?.cancel(); // Corrigido para usar apenas cancel()
    _debounceTimer?.cancel();
    _startDateController.dispose();
    _endDateController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  String _canonicalId(String raw) {
    var s = raw.trim();
    if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
    s = s.replaceAll(RegExp(r'[^0-9A-Za-z\-]'), '');
    return s;
  }

  Future<void> _openPedidoSideSheet(Pedido pedido) async {
    final produtosParsed = parseProdutos(pedido.produtos);
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar',
      barrierColor: Colors.black.withOpacity(0.25),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim, secondaryAnim) {
        final w = MediaQuery.of(context).size.width;
        final sheetWidth = (w * 0.40).clamp(360.0, 640.0);

        return Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: sheetWidth,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: Material(
                color: Colors.white,
                elevation: 16,
                child: PedidoDetailDialog(
                  pedido: pedido.toJson(),
                  produtosParsed: produtosParsed,
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim, _, child) {
        final slide = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOutCubic))
            .animate(anim);
        final fade = CurvedAnimation(parent: anim, curve: Curves.easeOut);
        return SlideTransition(position: slide, child: FadeTransition(opacity: fade, child: child));
      },
    );
  }

  Future<void> _loadPreviousPedidoIds() async {
    _previousPedidoIds = await PedidoService.loadPreviousPedidoIds();
  }

  Future<void> _loadPrintedPedidoIds() async {
    _printedPedidoIds = await PedidoService.loadPrintedPedidoIds();
  }

  Future<void> _savePreviousPedidoIds() async {
    await PedidoService.savePreviousPedidoIds(_previousPedidoIds);
  }

  Future<void> _savePrintedPedidoIds() async {
    await PedidoService.savePrintedPedidoIds(_printedPedidoIds);
  }

  Future<File> _getLogFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final logDir = Directory('${directory.path}/CDBarreiro');
    if (!logDir.existsSync()) logDir.createSync(recursive: true);
    final logFile = File('${logDir.path}/fetch_logs.txt');
    if (!await logFile.exists()) {
      await logFile.create();
    }
    return logFile;
  }

  IOSink? logSink; // Declaração movida para fora do try, usando IOSink em vez de FileOutputStream

  Future<void> _fetchPedidosSilently() async {
    if (_isFetching) {
      debugPrint('Fetch já em execução; pulando ciclo.');
      return;
    }
    _isFetching = true;
    try {
      final List<Pedido> newPedidos = await PedidoService.fetchPedidos();
      final logFile = await _getLogFile();
      logSink = logFile.openWrite(mode: FileMode.append);

      final List<Pedido> problematic = [];
      for (var pedido in newPedidos) {
        final logLine = 'Pedido ${pedido.id}: descontoGiftCard=${pedido.descontoGiftCard}, JSON=${jsonEncode(pedido.toJson())}\n';
        logSink!.write(logLine);
        if (DateTime.tryParse(pedido.dataAgendamento) == null) {
          problematic.add(pedido);
          logSink!.write('ERRO: Pedido ${pedido.id} tem data_agendamento inválida: ${pedido.dataAgendamento}\n');
        }
      }
      logSink!.write('Pedidos retornados: ${newPedidos.length}, Problemáticos: ${problematic.length}\n');

      if (newPedidos.isNotEmpty) {
        final seen = <String>{};
        final deduped = <Pedido>[];
        for (final p in newPedidos) {
          final key = _canonicalId(p.id);
          if (seen.add(key)) deduped.add(p);
        }

        final merged = <String, Pedido>{};
        for (final p in _allPedidos) {
          merged[_canonicalId(p.id)] = p;
        }
        for (final p in deduped) {
          merged[_canonicalId(p.id)] = p;
        }

        final updatedPedidos = merged.values.toList()..sort(_compareAgendamento);
        final List<String> newIdsCanonical = deduped.map<String>((p) => _canonicalId(p.id)).toList();

        if (mounted) {
          setState(() {
            _allPedidos = updatedPedidos;
            _filteredPedidos = List<Pedido>.from(_allPedidos);
            _previousPedidoIds = newIdsCanonical;
            _problematicPedidos = problematic;
            if (problematic.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${problematic.length} pedido(s) com data inválida. Verifique a seção de problemas.'),
                  duration: const Duration(seconds: 5),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          });
          await _filterPedidos();
          await _processNewPedidos(deduped);
        }
      } else {
        logSink!.write('Nenhum novo pedido retornado\n');
      }
    } catch (e) {
      debugPrint('Erro ao buscar pedidos: $e');
      logSink?.write('Erro ao buscar pedidos: $e\n');
    } finally {
      await logSink?.close();
      _isFetching = false;
      await _savePreviousPedidoIds();
    }
  }

  Future<void> _processNewPedidos(List<Pedido> newPedidos) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var pedido in newPedidos) {
      final key = _canonicalId(pedido.id);
      if (_printedPedidoIds.contains(key) || _printingNow.contains(key)) continue;

      final dataAgendamento = _parseDateRobust(pedido.dataAgendamento);
      if (dataAgendamento == null) {
        await PedidoService.writeLog(
            'Pedido ${pedido.id} ignorado para impressão: data_agendamento inválida (${pedido.dataAgendamento}).',
            context);
        continue;
      }
      final agendamentoDate = DateTime(dataAgendamento.year, dataAgendamento.month, dataAgendamento.day);

      if (agendamentoDate == today) {
        _printingNow.add(key);
        bool printedSuccessfully = false;
        for (int attempt = 1; attempt <= 3; attempt++) {
          try {
            final produtosParsed = parseProdutos(pedido.produtos);
            final dialog = PedidoDetailDialog(pedido: pedido.toJson(), produtosParsed: produtosParsed);
            await dialog.printDirectly(
              context,
              pedido.toJson(),
              produtosParsed,
              markSheets: true,
            );

            setState(() => _printedPedidoIds.add(key));
            await _savePrintedPedidoIds();
            await PedidoService.writeLog(
                'Pedido ${pedido.id} impresso com sucesso na tentativa $attempt.', context);

            printedSuccessfully = true;
            break;
          } catch (e) {
            await PedidoService.writeLog(
                'Erro ao imprimir pedido ${pedido.id} na tentativa $attempt: $e', context);
            if (attempt == 3 && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erro ao imprimir pedido #${pedido.id} após 3 tentativas: $e')),
              );
            }
            await Future.delayed(const Duration(seconds: 2));
          }
        }
        _printingNow.remove(key);
        if (!printedSuccessfully) {
          await PedidoService.writeLog(
              'Pedido ${pedido.id} não foi impresso após todas as tentativas.', context);
        }
      }
    }
  }

  Future<void> _filterPedidos() async {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      List<Pedido> tempList = List<Pedido>.from(_allPedidos);

      if (_searchText.isNotEmpty) {
        final searchLower = _searchText.toLowerCase();
        tempList = tempList.where((pedido) {
          final idStr = pedido.id.toLowerCase();
          final nome = pedido.nome.toLowerCase();
          return idStr.contains(searchLower) || nome.contains(searchLower);
        }).toList();
      } else if (_startDate != null && _endDate != null) {
        tempList = tempList.where((pedido) {
          final dataStr = pedido.dataAgendamento;
          if (dataStr.isEmpty) return true; // Inclui pedidos sem data
          final dt = _parseDateRobust(dataStr);
          if (dt == null) return true; // Inclui pedidos com data inválida
          return dt.isAfter(_startDate!.subtract(const Duration(seconds: 1))) &&
              dt.isBefore(_endDate!.add(const Duration(seconds: 1)));
        }).toList();
      }

      if (_selectedStatus != 'Todos') {
        tempList = tempList
            .where((pedido) => pedido.status.toLowerCase() == _selectedStatus.toLowerCase())
            .toList();
      }

      // Filtra pedidos concluídos se _hideCompleted for true
        if (_hideCompleted) {
          tempList = tempList.where((pedido) => pedido.status.toLowerCase() != 'concluído').toList();
        }

      tempList.sort(_compareAgendamento);
      if (mounted) {
        setState(() => _filteredPedidos = tempList);
      }
    });
  }

  // Função para parsing robusto de datas
  DateTime? _parseDateRobust(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      // Tenta ISO 8601 (com ou sem milissegundos, UTC ou não)
      return DateTime.tryParse(dateStr)?.toLocal();
    } catch (_) {
      try {
        // Tenta formato DD/MM/YYYY
        if (dateStr.contains('/')) {
          final parts = dateStr.split('/');
          if (parts.length == 3) {
            return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
          }
        }
      } catch (_) {
        try {
          // Tenta formato MMMM dd, yyyy
          return DateFormat('MMMM dd, yyyy').parse(dateStr, true).toLocal();
        } catch (_) {
          return null;
        }
      }
      return null;
    }
  }

  DateTime? _parseAgendamentoToDateTime(String dataAgendamento, String horarioAgendamento) {
    try {
      if (dataAgendamento.isEmpty || horarioAgendamento.isEmpty) return null;
      final date = _parseDateRobust(dataAgendamento);
      if (date == null) return null;
      final horarioParts = horarioAgendamento.split(' - ');
      if (horarioParts.isEmpty || horarioParts[0].isEmpty) return null;
      final timeFormat = DateFormat('HH:mm');
      final time = timeFormat.parse(horarioParts[0].trim());
      return DateTime(date.year, date.month, date.day, time.hour, time.minute);
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseHorarioCriacao(String horario) {
    try {
      if (horario.isEmpty) return null;
      final timeFormat = DateFormat('HH:mm');
      return timeFormat.parse(horario);
    } catch (_) {
      return null;
    }
  }

  int _compareAgendamento(Pedido a, Pedido b) {
    final dataAgendamentoA = a.dataAgendamento.isNotEmpty ? a.dataAgendamento : a.data;
    final horarioAgendamentoA = a.horarioAgendamento;
    final horarioA = a.horario;
    final dataAgendamentoB = b.dataAgendamento.isNotEmpty ? b.dataAgendamento : b.data;
    final horarioAgendamentoB = b.horarioAgendamento;
    final horarioB = b.horario;

    final dateTimeAgendamentoA = _parseAgendamentoToDateTime(dataAgendamentoA, horarioAgendamentoA);
    final dateTimeAgendamentoB = _parseAgendamentoToDateTime(dataAgendamentoB, horarioAgendamentoB);
    final dateTimeCriacaoA = _parseHorarioCriacao(horarioA);
    final dateTimeCriacaoB = _parseHorarioCriacao(horarioB);

    // Prioriza pedidos com data válida
    if (dateTimeAgendamentoA == null && dateTimeAgendamentoB == null) return 0;
    if (dateTimeAgendamentoA == null) return 1;
    if (dateTimeAgendamentoB == null) return -1;
    final compareAgendamento = dateTimeAgendamentoA.compareTo(dateTimeAgendamentoB);
    if (compareAgendamento != 0) return compareAgendamento;

    if (dateTimeCriacaoA == null && dateTimeCriacaoB == null) return 0;
    if (dateTimeCriacaoA == null) return 1;
    if (dateTimeCriacaoB == null) return -1;
    return dateTimeCriacaoA.compareTo(dateTimeCriacaoB);
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      _startDate = DateTime(picked.year, picked.month, picked.day, 0, 0, 0);
      _startDateController.text = DateFormat('dd/MM/yyyy').format(_startDate!);
      await _filterPedidos();
      if (mounted) setState(() {});
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      _endDateController.text = DateFormat('dd/MM/yyyy').format(_endDate!);
      await _filterPedidos();
      if (mounted) setState(() {});
    }
  }

  String _formatHorario(String raw) {
    final reg = RegExp(r'(\d{2}):(\d{2}):(\d{2})');
    final match = reg.firstMatch(raw);
    if (match != null) {
      final hh = match.group(1);
      final mm = match.group(2);
      if (hh != null && mm != null) {
        return '$hh:$mm';
      }
    }
    return raw;
  }

  String _formatoDataAgendamento(String iso) {
    if (iso.isEmpty) return 'Data não informada';
    final dt = _parseDateRobust(iso);
    if (dt != null) {
      return DateFormat('dd/MM/yyyy').format(dt);
    }
    return 'Data inválida: $iso';
  }

  List<Map<String, String>> parseProdutos(String produtosRaw) {
    final List<Map<String, String>> produtos = [];
    final List<String> items = produtosRaw.split('*\n').where((item) => item.trim().isNotEmpty).toList();

    for (String item in items) {
      final cleanItem = item.trim().endsWith('*') ? item.substring(0, item.length - 1).trim() : item.trim();
      final qtdMatch = RegExp(r'\(Qtd:\s*(\d+)\)').firstMatch(cleanItem);
      if (qtdMatch != null) {
        final qtd = qtdMatch.group(1)!;
        final nomePart = cleanItem.split('(Qtd:')[0].trim();
        final afterQtd = cleanItem.split('(Qtd:')[1];
        final variationsAndPeso = afterQtd.substring(qtd.length + 1).trim();
        String displayString = nomePart;
        if (variationsAndPeso.isNotEmpty) {
          displayString += ' $variationsAndPeso';
        }
        produtos.add({'nome': displayString.trim(), 'qtd': qtd});
      }
    }
    return produtos;
  }

  void _showProblematicPedidosDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pedidos com Problemas'),
        content: _problematicPedidos.isEmpty
            ? const Text('Nenhum pedido com problemas detectado.')
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _problematicPedidos.length,
                  itemBuilder: (context, index) {
                    final pedido = _problematicPedidos[index];
                    return ListTile(
                      leading: const Icon(Icons.warning_rounded, color: Colors.redAccent),
                      title: Text('Pedido #${pedido.id}'),
                      subtitle: Text('Data inválida: ${pedido.dataAgendamento}'),
                      onTap: () => _openPedidoSideSheet(pedido),
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 6))],
              border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.15))),
            ),
            child: FilterPanel(
              searchText: _searchText,
              searchController: _searchController,
              startDateController: _startDateController,
              endDateController: _endDateController,
              selectedStatus: _selectedStatus,
              hideCompleted: _hideCompleted,
              filteredCount: _filteredPedidos.length,
              statusOptions: _statusOptions,
              searchFocusNode: _searchFocusNode,
              onSearchChanged: (value) {},
              onPickStartDate: _pickStartDate,
              onPickEndDate: _pickEndDate,
              onStatusChanged: (value) {
                if (value != null) {
                  setState(() => _selectedStatus = value);
                  _filterPedidos();
                }
              },
              onHideCompletedChanged: (value) {
                setState(() => _hideCompleted = value);
                _filterPedidos();
              },
            ),
          ),

          if (_problematicPedidos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: _showProblematicPedidosDialog,
                icon: const Icon(Icons.warning_rounded, color: Colors.white),
                label: Text(
                  '${_problematicPedidos.length} Pedido(s) com Problemas',
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

          if (_isInitialLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator(color: Color(0xFFF28C38))),
            ),

          Expanded(
            child: _isInitialLoading
                ? const SizedBox.shrink()
                : _filteredPedidos.isEmpty
                    ? const Center(
                        child: Text('Nenhum pedido encontrado.', style: TextStyle(color: Colors.grey, fontSize: 16)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _filteredPedidos.length,
                        itemBuilder: (context, index) {
                          final pedido = _filteredPedidos[index];
                          return PedidoCard(
                            pedido: pedido,
                            orderStatusOptions: _orderStatusOptions,
                            formatHorario: _formatHorario,
                            formatDataAgendamento: _formatoDataAgendamento,
                            onStatusChanged: (newStatus) {
                              PedidoService.updateStatusPedidoBarreiro(pedido, newStatus, context).then((success) {
                                if (success && mounted) {
                                  setState(() {
                                    final updatedPedidos = _allPedidos.map<Pedido>((p) {
                                      return p.id == pedido.id
                                          ? Pedido(
                                              id: p.id,
                                              data: p.data,
                                              horario: p.horario,
                                              bairro: p.bairro,
                                              nome: p.nome,
                                              pagamento: p.pagamento,
                                              subTotal: p.subTotal,
                                              total: p.total,
                                              vendedor: p.vendedor,
                                              taxaEntrega: p.taxaEntrega,
                                              status: newStatus,
                                              entregador: p.entregador,
                                              rua: p.rua,
                                              numero: p.numero,
                                              cep: p.cep,
                                              complemento: p.complemento,
                                              latitude: p.latitude,
                                              longitude: p.longitude,
                                              unidade: p.unidade,
                                              cidade: p.cidade,
                                              tipoEntrega: p.tipoEntrega,
                                              dataAgendamento: p.dataAgendamento,
                                              horarioAgendamento: p.horarioAgendamento,
                                              telefone: p.telefone,
                                              observacao: p.observacao,
                                              produtos: p.produtos,
                                              rastreio: p.rastreio,
                                              nomeCupom: p.nomeCupom,
                                              porcentagemCupom: p.porcentagemCupom,
                                              descontoGiftCard: p.descontoGiftCard,
                                            )
                                          : p;
                                    }).toList();
                                    _allPedidos = List<Pedido>.from(updatedPedidos);
                                    _filteredPedidos = List<Pedido>.from(_allPedidos);
                                  });
                                }
                              });
                            },
                            onTap: () => _openPedidoSideSheet(pedido),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class FilterPanel extends StatelessWidget {
    final String searchText;
    final TextEditingController searchController;
    final TextEditingController startDateController;
    final TextEditingController endDateController;
    final String selectedStatus;
    final bool hideCompleted; // Alterado de showCompleted para hideCompleted
    final int filteredCount;
    final List<String> statusOptions;
    final Function(String) onSearchChanged;
    final VoidCallback onPickStartDate;
    final VoidCallback onPickEndDate;
    final Function(String?) onStatusChanged;
    final Function(bool) onHideCompletedChanged; // Alterado de onShowCompletedChanged
    final FocusNode searchFocusNode;

    const FilterPanel({
      super.key,
      required this.searchText,
      required this.searchController,
      required this.startDateController,
      required this.endDateController,
      required this.selectedStatus,
      required this.hideCompleted,
      required this.filteredCount,
      required this.statusOptions,
      required this.onSearchChanged,
      required this.onPickStartDate,
      required this.onPickEndDate,
      required this.onStatusChanged,
      required this.onHideCompletedChanged,
      required this.searchFocusNode,
    });

  @override
    Widget build(BuildContext context) {
      final primary = const Color(0xFFF28C38);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: LtrTextField(
                  labelText: 'Buscar ID ou Nome',
                  controller: searchController,
                  focusNode: searchFocusNode,
                  onChanged: onSearchChanged,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s]'))],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.inbox_rounded, size: 16, color: primary),
                    const SizedBox(width: 6),
                    Text(
                      '$filteredCount pedido${filteredCount != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _DateField(
                label: 'Data inicial',
                controller: startDateController,
                onTap: onPickStartDate,
              ),
              _DateField(
                label: 'Data final',
                controller: endDateController,
                onTap: onPickEndDate,
              ),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  shrinkWrap: true,
                  scrollDirection: Axis.horizontal,
                  itemCount: statusOptions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final s = statusOptions[i];
                    final selected = s == selectedStatus;
                    return ChoiceChip(
                      label: Text(s),
                      selected: selected,
                      onSelected: (_) => onStatusChanged(s),
                      pressElevation: 0,
                      selectedColor: primary.withOpacity(0.15),
                      labelStyle: TextStyle(
                        color: selected ? primary : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: selected ? primary.withOpacity(0.4) : Colors.grey.withOpacity(0.25),
                        ),
                      ),
                      backgroundColor: Colors.white,
                    );
                  },
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Ocultar concluídos', style: TextStyle(fontWeight: FontWeight.w500)), // Alterado o rótulo
                  const SizedBox(width: 6),
                  Switch(
                    value: hideCompleted,
                    onChanged: onHideCompletedChanged,
                    activeColor: primary,
                    activeTrackColor: primary.withOpacity(0.4),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
    }
  }

class _DateField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFFF28C38);
    return SizedBox(
      width: 220,
      child: TextField(
        controller: controller,
        readOnly: true,
        onTap: onTap,
        decoration: InputDecoration(
          hintText: label,
          prefixIcon: Icon(Icons.calendar_today_rounded, color: primary),
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: primary, width: 1.2),
          ),
        ),
      ),
    );
  }
}

class PedidoCard extends StatelessWidget {
  final Pedido pedido;
  final List<String> orderStatusOptions;
  final String Function(String) formatHorario;
  final String Function(String) formatDataAgendamento;
  final Function(String) onStatusChanged;
  final VoidCallback onTap;

  const PedidoCard({
    super.key,
    required this.pedido,
    required this.orderStatusOptions,
    required this.formatHorario,
    required this.formatDataAgendamento,
    required this.onStatusChanged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFFF28C38);

    Color statusBackground;
    Color statusText;
    switch (pedido.status.toLowerCase()) {
      case 'registrado':
        statusBackground = const Color(0xFFE0F2FE);
        statusText = const Color(0xFF0369A1);
        break;
      case 'saiu pra entrega':
        statusBackground = const Color(0xFFFEF3C7);
        statusText = const Color(0xFF92400E);
        break;
      case 'concluído':
        statusBackground = const Color(0xFFDCFCE7);
        statusText = const Color(0xFF166534);
        break;
      case 'cancelado':
        statusBackground = const Color(0xFFfee2e2);
        statusText = const Color(0xFF991B1B);
        break;
      case 'agendado':
        statusBackground = const Color(0xFFE0F2FE);
        statusText = const Color(0xFF0369A1);
        break;
      default:
        statusBackground = Colors.grey[100]!;
        statusText = Colors.grey[800]!;
    }

    Color deliveryBackground;
    Color deliveryText;
    IconData deliveryIcon;
    switch (pedido.tipoEntrega.toLowerCase()) {
      case 'delivery':
        deliveryBackground = const Color(0xFFDCFCE7);
        deliveryText = const Color(0xFF166534);
        deliveryIcon = Icons.local_shipping_rounded;
        break;
      case 'pickup':
        deliveryBackground = const Color(0xFFDBEAFE);
        deliveryText = const Color(0xFF1E40AF);
        deliveryIcon = Icons.store_mall_directory_rounded;
        break;
      default:
        deliveryBackground = const Color(0xFFE5E7EB);
        deliveryText = const Color(0xFF4B5563);
        deliveryIcon = Icons.help_outline_rounded;
    }

    final agendamentoDate = formatDataAgendamento(pedido.dataAgendamento.isNotEmpty ? pedido.dataAgendamento : pedido.data);
    final agendamentoHorario = pedido.horarioAgendamento.isNotEmpty ? pedido.horarioAgendamento : '';
    final isDateInvalid = agendamentoDate.startsWith('Data inválida');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDateInvalid ? Colors.redAccent.withOpacity(0.5) : Colors.black12.withOpacity(0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: primaryColor.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        '#${pedido.id}',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      if (isDateInvalid) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.warning_rounded, color: Colors.white, size: 16),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: deliveryBackground,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(deliveryIcon, size: 16, color: deliveryText),
                      const SizedBox(width: 6),
                      Text(
                        pedido.tipoEntrega == 'delivery'
                            ? 'Delivery'
                            : pedido.tipoEntrega == 'pickup'
                                ? 'Retirada'
                                : 'Indefinido',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: deliveryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(pedido.nome, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(pedido.bairro, style: TextStyle(fontSize: 13.5, color: Colors.grey[700])),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: statusBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusText.withOpacity(0.15)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: pedido.status,
                      isDense: true,
                      icon: Icon(Icons.arrow_drop_down_rounded, size: 20, color: statusText),
                      dropdownColor: statusBackground,
                      style: TextStyle(fontSize: 14, color: statusText, fontWeight: FontWeight.w600),
                      items: orderStatusOptions
                          .map((s) => DropdownMenuItem<String>(
                                value: s,
                                child: Text(s, style: TextStyle(fontSize: 14, color: statusText)),
                              ))
                          .toList(),
                      onChanged: (newValue) {
                        if (newValue != null && newValue != pedido.status) {
                          onStatusChanged(newValue);
                        }
                      },
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(
                      isDateInvalid ? Icons.warning_rounded : Icons.calendar_today_rounded,
                      size: 16,
                      color: isDateInvalid ? Colors.redAccent : Colors.grey[700],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      agendamentoDate,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDateInvalid ? Colors.redAccent : Colors.grey[800],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.access_time_filled_rounded, size: 16, color: Colors.grey[700]),
                    const SizedBox(width: 6),
                    Text(
                      agendamentoHorario,
                      style: TextStyle(fontSize: 12.5, color: Colors.grey[800], fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}