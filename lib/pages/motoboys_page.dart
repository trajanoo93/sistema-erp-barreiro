import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para copiar texto
import 'package:url_launcher/url_launcher.dart'; // Para abrir links

class MotoboysPage extends StatelessWidget {
  const MotoboysPage({Key? key}) : super(key: key);

  // Função para abrir links
  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Não foi possível abrir o link: $url';
    }
  }

  // Função para copiar texto
  void _copyToClipboard(String text, BuildContext context) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copiado para a área de transferência!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFF28C38);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título
                Text(
                  'Portal de Motoboys',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 16),

                // Instruções com credenciais
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Color(0xFFF28C38),
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Credenciais de Acesso',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Email: pedidos@aogosto.com.br',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, color: Color(0xFFF28C38)),
                              onPressed: () => _copyToClipboard('pedidos@aogosto.com.br', context),
                              tooltip: 'Copiar email',
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Senha: AoGosto!100',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, color: Color(0xFFF28C38)),
                              onPressed: () => _copyToClipboard('AoGosto!100', context),
                              tooltip: 'Copiar senha',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Cards dos serviços
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: [
                    _buildServiceCard(
                      context: context,
                      title: 'Uber Direct',
                      icon: Icons.local_shipping,
                      url: 'https://direct.uber.com/accounts/215113b2-9455-4964-b9dc-cb07d98a614c/new-delivery?locationUuid=fcc60703-65a0-5c4f-b204-bd68312b9e27&searchSelectId=SEARCH_OPTION_EXTERNAL_ORDER_ID&searchSelectedStatuses=SEARCH_ORDER_STATUS_SCHEDULED%2CSEARCH_ORDER_STATUS_PENDING%2CSEARCH_ORDER_STATUS_PICKING_UP%2CSEARCH_ORDER_STATUS_ARRIVED_AT_PICKUP%2CSEARCH_ORDER_STATUS_DROPPING_OFF%2CSEARCH_ORDER_STATUS_ARRIVED_AT_DROPOFF%2CSEARCH_ORDER_STATUS_COMPLETED%2CSEARCH_ORDER_STATUS_CANCELED%2CSEARCH_ORDER_STATUS_RETURNING%2CSEARCH_ORDER_STATUS_RETURN_COMPLETED%2CSEARCH_ORDER_STATUS_RETURN_CANCELED&searchCurrentPage=1&searchPageSize=50&searchSelectedLocations=&searchStartTime=2025-03-25T03%3A00%3A00.000Z&searchEndTime=2025-04-26T02%3A59%3A59.999Z',
                      color: primaryColor,
                    ),
                    _buildServiceCard(
                      context: context,
                      title: 'Lalamove',
                      icon: Icons.motorcycle,
                      url: 'https://web.lalamove.com/',
                      color: primaryColor,
                    ),
                    _buildServiceCard(
                      context: context,
                      title: 'Loggi',
                      icon: Icons.directions_bike,
                      url: 'https://www.loggi.com/corp/app/novo-pedido',
                      color: primaryColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required String url,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () => _launchUrl(url),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.white,
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      color,
                      color.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Acessar Portal',
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}