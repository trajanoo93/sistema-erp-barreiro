import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:erp_painel/services/criar_pedido_service.dart';

class ProductSelectionDialog extends StatefulWidget {
  const ProductSelectionDialog({Key? key}) : super(key: key);

  @override
  State<ProductSelectionDialog> createState() => _ProductSelectionDialogState();
}

class _ProductSelectionDialogState extends State<ProductSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = false;
  final primaryColor = const Color(0xFFF28C38);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    if (query.length >= 3) {
      _fetchProducts(query);
    } else {
      setState(() {
        _products = [];
      });
    }
  }

  Future<void> _fetchProducts(String query) async {
    setState(() => _isLoading = true);
    try {
      final products = await CriarPedidoService().fetchProducts(query);
      setState(() => _products = products);
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao buscar produtos: $error'), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<Map<String, dynamic>?> _showVariationDialog(Map<String, dynamic> product) async {
    final attributes = await CriarPedidoService().fetchProductAttributes(product['id']);
    final variations = await CriarPedidoService().fetchProductVariations(product['id']);
    Map<String, String> selectedAttributes = {};
    for (var attr in attributes) {
      selectedAttributes[attr['name']] = attr['options'].first;
    }

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            List<Map<String, dynamic>> availableVariations = variations.where((variation) {
              bool isMatch = true;
              for (var attr in variation['attributes']) {
                final attrName = attr['name'];
                final attrOption = attr['option'];
                if (selectedAttributes[attrName] != attrOption) {
                  isMatch = false;
                  break;
                }
              }
              return isMatch;
            }).toList();

            return AlertDialog(
              title: Text(
                'Selecione as Variações',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...attributes.map((attr) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: DropdownButtonFormField<String>(
                          value: selectedAttributes[attr['name']],
                          decoration: InputDecoration(
                            labelText: attr['name'],
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
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                          items: (attr['options'] as List<dynamic>).map((option) {
                            return DropdownMenuItem<String>(
                              value: option.toString(),
                              child: Text(option.toString(), style: GoogleFonts.poppins(fontSize: 14)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedAttributes[attr['name']] = value!;
                            });
                          },
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 16),
                    if (availableVariations.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Variação Selecionada:',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...availableVariations.map((variation) {
                            final isInStock = variation['stock_status'] == 'instock';
                            return Opacity(
                              opacity: isInStock ? 1.0 : 0.5,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'R\$ ${variation['price'].toStringAsFixed(2)}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Icon(
                                          isInStock ? Icons.check_circle : Icons.cancel,
                                          color: isInStock ? Colors.green.shade600 : Colors.redAccent,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isInStock ? 'Em Estoque' : 'Fora de Estoque',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: isInStock ? Colors.green.shade600 : Colors.redAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      )
                    else
                      Text(
                        'Nenhuma variação disponível para os atributos selecionados.',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Map<String, dynamic>? selectedVariation;
                    for (var variation in variations) {
                      bool isMatch = true;
                      for (var attr in variation['attributes']) {
                        final attrName = attr['name'];
                        final attrOption = attr['option'];
                        if (selectedAttributes[attrName] != attrOption) {
                          isMatch = false;
                          break;
                        }
                      }
                      if (isMatch) {
                        selectedVariation = variation;
                        break;
                      }
                    }
                    if (selectedVariation != null) {
                      final isInStock = selectedVariation['stock_status'] == 'instock';
                      if (!isInStock) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Esta variação está fora de estoque e não pode ser adicionada.'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        return;
                      }
                      final variationAttributes = selectedAttributes.entries.map((entry) {
                        return {'name': entry.key, 'option': entry.value};
                      }).toList();
                      Navigator.of(context).pop({
                        'id': selectedVariation['id'],
                        'attributes': variationAttributes,
                        'price': selectedVariation['price'],
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Nenhuma variação correspondente encontrada'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      Navigator.of(context).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    'Confirmar',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _selectProduct(Map<String, dynamic> product) async {
    final isInStock = product['stock_status'] == 'instock';
    if (!isInStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este produto está fora de estoque e não pode ser adicionada.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (product['type'] == 'variable') {
      final variation = await _showVariationDialog(product);
      if (variation != null) {
        Navigator.of(context).pop({
          'id': product['id'],
          'name': product['name'],
          'price': variation['price'],
          'variation_id': variation['id'],
          'variation_attributes': variation['attributes'],
          'image': product['image'],
        });
      }
    } else {
      Navigator.of(context).pop({
        'id': product['id'],
        'name': product['name'],
        'price': product['price'],
        'variation_id': null,
        'variation_attributes': null,
        'image': product['image'],
      });
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Selecionar Produto',
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar Produto (mín. 3 caracteres)',
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
                prefixIcon: Icon(Icons.search, color: primaryColor),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryColor))
            else if (_products.isEmpty && _searchController.text.length >= 3)
              Text(
                'Nenhum produto encontrado',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              )
            else
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    final isInStock = product['stock_status'] == 'instock';
                    return Opacity(
                      opacity: isInStock ? 1.0 : 0.5,
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: product['image'] != null
                              ? Image.network(
                                  product['image'],
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey.shade600,
                                    size: 50,
                                  ),
                                )
                              : Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey.shade600,
                                  size: 50,
                                ),
                          title: Text(
                            product['name'],
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'R\$ ${product['price'].toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    isInStock ? Icons.check_circle : Icons.cancel,
                                    color: isInStock ? Colors.green.shade600 : Colors.redAccent,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isInStock ? 'Em Estoque' : 'Fora de Estoque',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isInStock ? Colors.green.shade600 : Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: isInStock ? () => _selectProduct(product) : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancelar',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.redAccent,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}