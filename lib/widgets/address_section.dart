import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:erp_painel/models/pedido_state.dart';

class AddressSection extends StatefulWidget {
  final TextEditingController cepController;
  final TextEditingController addressController;
  final TextEditingController numberController;
  final TextEditingController complementController;
  final TextEditingController neighborhoodController;
  final TextEditingController cityController;
  final Function(String) onChanged;
  final Function(double) onShippingCostUpdated;
  final Function(String, String) onStoreUpdated;
  final double externalShippingCost;
  final String shippingMethod;
  final VoidCallback? setStateCallback;
  final Future<void> Function()? checkStoreByCep;
  final PedidoState? pedido;
  final VoidCallback? onReset;

  const AddressSection({
    Key? key,
    required this.cepController,
    required this.addressController,
    required this.numberController,
    required this.complementController,
    required this.neighborhoodController,
    required this.cityController,
    required this.onChanged,
    required this.onShippingCostUpdated,
    required this.onStoreUpdated,
    required this.externalShippingCost,
    required this.shippingMethod,
    this.setStateCallback,
    this.checkStoreByCep,
    this.pedido,
    this.onReset,
  }) : super(key: key);

  @override
  State<AddressSection> createState() => _AddressSectionState();
}

class _AddressSectionState extends State<AddressSection> {
  bool _isFetchingStore = false;
  String? _storeIndication;
  final primaryColor = const Color(0xFFF28C38);

  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;

  final _cepMaskFormatter = MaskTextInputFormatter(
    mask: '#####-###',
    filter: {'#': RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  @override
  void initState() {
    super.initState();
    widget.cepController.addListener(_onCepChanged);
    widget.addressController.addListener(_onFieldChanged);
    widget.numberController.addListener(_onFieldChanged);
    widget.complementController.addListener(_onFieldChanged);
    widget.neighborhoodController.addListener(_onFieldChanged);
    widget.cityController.addListener(_onFieldChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.shippingMethod == 'pickup' && widget.pedido?.cepController.text.isNotEmpty == true) {
        resetSection();
      }
    });
  }

  @override
  void dispose() {
    widget.cepController.removeListener(_onCepChanged);
    widget.addressController.removeListener(_onFieldChanged);
    widget.numberController.removeListener(_onFieldChanged);
    widget.complementController.removeListener(_onFieldChanged);
    widget.neighborhoodController.removeListener(_onFieldChanged);
    widget.cityController.removeListener(_onFieldChanged);
    super.dispose();
  }

  void _onFieldChanged() {
    widget.onChanged('');
    widget.setStateCallback?.call();
  }

  void _onCepChanged() {
    widget.onChanged(widget.cepController.text);
    widget.setStateCallback?.call();
    if (widget.shippingMethod == 'pickup') {
      if (mounted) {
        setState(() {
          _storeIndication = 'Retirada na loja: Unidade Barreiro';
        });
      }
      widget.onShippingCostUpdated(0.0);
      widget.onStoreUpdated('Unidade Barreiro', '110727');
      if (widget.pedido != null) {
        widget.pedido!.shippingCost = 0.0;
        widget.pedido!.shippingCostController.text = '0.00';
        widget.pedido!.storeFinal = 'Unidade Barreiro';
        widget.pedido!.pickupStoreId = '110727';
      }
    } else {
      if (mounted) {
        setState(() => _storeIndication = null);
      }
      widget.onShippingCostUpdated(0.0);
      widget.onStoreUpdated('', '');
      if (widget.pedido != null) {
        widget.pedido!.shippingCost = 0.0;
        widget.pedido!.shippingCostController.text = '0.00';
        widget.pedido!.storeFinal = '';
        widget.pedido!.pickupStoreId = '';
      }
    }
  }

  Future<void> _fetchAddressByCep() async {
    final cleanCep = widget.cepController.text.replaceAll(RegExp(r'\D'), '').trim();
    if (cleanCep.length != 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CEP inválido. Deve ter 8 dígitos.'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (mounted) setState(() => _isFetchingStore = true);
    try {
      final response = await http.get(Uri.parse('https://viacep.com.br/ws/$cleanCep/json/'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['erro'] == true) {
          throw Exception('CEP não encontrado');
        }
        if (mounted) {
          setState(() {
            widget.addressController.text = data['logradouro'] ?? '';
            widget.neighborhoodController.text = data['bairro'] ?? '';
            widget.cityController.text = data['localidade'] ?? '';
          });
          widget.onChanged(''); // Notifica mudança nos campos
        }
      } else {
        throw Exception('Erro ao consultar ViaCEP: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao consultar endereço: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isFetchingStore = false);
    }
  }

  void resetSection() {
    if (!mounted) return;
    setState(() {
      _storeIndication = null;
    });
    widget.cepController.clear();
    widget.addressController.clear();
    widget.numberController.clear();
    widget.complementController.clear();
    widget.neighborhoodController.clear();
    widget.cityController.clear();
    widget.onShippingCostUpdated(0.0);
    widget.onStoreUpdated('', '');
    if (widget.pedido != null) {
      widget.pedido!.cepController.clear();
      widget.pedido!.addressController.clear();
      widget.pedido!.numberController.clear();
      widget.pedido!.complementController.clear();
      widget.pedido!.neighborhoodController.clear();
      widget.pedido!.cityController.clear();
      widget.pedido!.shippingCost = 0.0;
      widget.pedido!.shippingCostController.text = '0.00';
      widget.pedido!.storeFinal = widget.shippingMethod == 'pickup' ? 'Unidade Barreiro' : '';
      widget.pedido!.pickupStoreId = widget.shippingMethod == 'pickup' ? '110727' : '';
    }
    widget.onReset?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CEP com Botão
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: widget.cepController,
                  decoration: InputDecoration(
                    labelText: 'CEP',
                    labelStyle: GoogleFonts.poppins(
                      color: isDarkMode ? Colors.white70 : Colors.black54,
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
                    prefixIcon: Icon(Icons.location_on, color: primaryColor),
                    suffixIcon: _isFetchingStore
                        ? Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [_cepMaskFormatter],
                  onChanged: (value) => _onCepChanged(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: widget.shippingMethod == 'pickup'
                    ? null
                    : () async {
                        await _fetchAddressByCep(); // Primeiro preenche endereço
                        if (widget.checkStoreByCep != null) {
                          await widget.checkStoreByCep!(); // Depois calcula store/taxa
                        }
                        // Atualiza storeIndication após ambos
                        if (mounted) {
                          setState(() {
                            final storeFinal = widget.shippingMethod == 'pickup'
                                ? 'Unidade Barreiro'
                                : (widget.pedido?.storeFinal ?? '');
                            _storeIndication = storeFinal.isNotEmpty && widget.shippingMethod == 'delivery'
                                ? 'Este pedido será enviado pela $storeFinal.'
                                : widget.shippingMethod == 'pickup'
                                    ? 'Retirada na loja: Unidade Barreiro'
                                    : null;
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Consultar CEP',
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          if (_storeIndication != null || (widget.shippingMethod == 'delivery' && widget.externalShippingCost > 0)) ...[
            const SizedBox(height: 8),
            if (widget.shippingMethod == 'delivery' && widget.externalShippingCost > 0) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: primaryColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_shipping, color: primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Taxa de Entrega: R\$ ${widget.externalShippingCost.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_storeIndication != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border(left: BorderSide(color: primaryColor, width: 4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.store, color: primaryColor, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _storeIndication!,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.orange[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: 20),
          // Endereço + Número
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: widget.addressController,
                  decoration: InputDecoration(
                    labelText: 'Endereço',
                    labelStyle: GoogleFonts.poppins(
                      color: isDarkMode ? Colors.white70 : Colors.black54,
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
                    prefixIcon: Icon(Icons.home, color: primaryColor),
                    filled: true,
                    fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
                  ),
                  onChanged: widget.onChanged,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: widget.numberController,
                  decoration: InputDecoration(
                    labelText: 'Número',
                    labelStyle: GoogleFonts.poppins(
                      color: isDarkMode ? Colors.white70 : Colors.black54,
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
                    filled: true,
                    fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: widget.onChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Complemento
          TextFormField(
            controller: widget.complementController,
            decoration: InputDecoration(
              labelText: 'Complemento (opcional)',
              labelStyle: GoogleFonts.poppins(
                color: isDarkMode ? Colors.white70 : Colors.black54,
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
              prefixIcon: Icon(Icons.edit, color: primaryColor),
              filled: true,
              fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
            ),
            onChanged: widget.onChanged,
          ),
          const SizedBox(height: 20),
          // Bairro
          TextFormField(
            controller: widget.neighborhoodController,
            decoration: InputDecoration(
              labelText: 'Bairro',
              labelStyle: GoogleFonts.poppins(
                color: isDarkMode ? Colors.white70 : Colors.black54,
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
              prefixIcon: Icon(Icons.location_city, color: primaryColor),
              filled: true,
              fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
            ),
            onChanged: widget.onChanged,
            validator: null,
          ),
          const SizedBox(height: 20),
          // Cidade
          TextFormField(
            controller: widget.cityController,
            decoration: InputDecoration(
              labelText: 'Cidade',
              labelStyle: GoogleFonts.poppins(
                color: isDarkMode ? Colors.white70 : Colors.black54,
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
              prefixIcon: Icon(Icons.location_city, color: primaryColor),
              filled: true,
              fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
            ),
            onChanged: widget.onChanged,
            validator: null,
          ),
        ],
      ),
    );
  }
}