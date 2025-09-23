// lib/models/pedido_model.dart
class Pedido {
  final String id;
  final String data;
  final String horario;
  final String bairro;
  final String nome;
  final String pagamento;
  final double subTotal;
  final double total;
  final String vendedor;
  final double taxaEntrega;
  final String status;
  final String entregador;
  final String rua;
  final String numero;
  final String cep;
  final String complemento;
  final String latitude;
  final String longitude;
  final String unidade;
  final String cidade;
  final String tipoEntrega;
  final String dataAgendamento;
  final String horarioAgendamento;
  final String telefone;
  final String observacao;
  final String produtos;
  final String rastreio;
  final String? nomeCupom; // Novo campo para o nome do cupom (pode ser nulo)
  final double? porcentagemCupom; // Novo campo para a porcentagem do cupom (pode ser nulo)
  final double? descontoGiftCard; // Novo campo para o desconto do gift card (pode ser nulo)

  Pedido({
    required this.id,
    required this.data,
    required this.horario,
    required this.bairro,
    required this.nome,
    required this.pagamento,
    required this.subTotal,
    required this.total,
    required this.vendedor,
    required this.taxaEntrega,
    required this.status,
    required this.entregador,
    required this.rua,
    required this.numero,
    required this.cep,
    required this.complemento,
    required this.latitude,
    required this.longitude,
    required this.unidade,
    required this.cidade,
    required this.tipoEntrega,
    required this.dataAgendamento,
    required this.horarioAgendamento,
    required this.telefone,
    required this.observacao,
    required this.produtos,
    required this.rastreio,
    this.nomeCupom,
    this.porcentagemCupom,
    this.descontoGiftCard,
  });

  factory Pedido.fromJson(Map<String, dynamic> json) {
  return Pedido(
    id: json['id'].toString(),
    data: json['data']?.toString() ?? '',
    horario: json['horario']?.toString() ?? '',
    bairro: json['bairro']?.toString() ?? '',
    nome: json['nome']?.toString() ?? '',
    pagamento: json['pagamento']?.toString() ?? '',
    subTotal: double.tryParse(json['subTotal']?.toString() ?? '0.0') ?? 0.0,
    total: double.tryParse(json['total']?.toString() ?? '0.0') ?? 0.0,
    vendedor: json['vendedor']?.toString() ?? '',
    taxaEntrega: double.tryParse(json['taxa_entrega']?.toString() ?? '0.0') ?? 0.0,
    status: json['status']?.toString() ?? '',
    entregador: json['entregador']?.toString() ?? '',
    rua: json['rua']?.toString() ?? '',
    numero: json['numero']?.toString() ?? '',
    cep: json['cep']?.toString() ?? '',
    complemento: json['complemento']?.toString() ?? '',
    latitude: json['latitude']?.toString() ?? '',
    longitude: json['longitude']?.toString() ?? '',
    unidade: json['unidade']?.toString() ?? '',
    cidade: json['cidade']?.toString() ?? '',
    tipoEntrega: json['tipo_entrega']?.toString() ?? '',
    dataAgendamento: json['data_agendamento']?.toString() ?? '',
    horarioAgendamento: json['horario_agendamento']?.toString() ?? '',
    telefone: json['telefone']?.toString() ?? '',
    observacao: json['observacao']?.toString() ?? '',
    produtos: json['produtos']?.toString() ?? '',
    rastreio: json['rastreio']?.toString() ?? '',
    nomeCupom: json['AG']?.toString(),
    porcentagemCupom: double.tryParse(json['AH']?.toString() ?? '0.0'),
    descontoGiftCard: double.tryParse(json['AI']?.toString() ?? '0.0') ?? 0.0, // Alterado para 0.0 como fallback
  );
}

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'data': data,
      'horario': horario,
      'bairro': bairro,
      'nome': nome,
      'pagamento': pagamento,
      'subTotal': subTotal,
      'total': total,
      'vendedor': vendedor,
      'taxa_entrega': taxaEntrega,
      'status': status,
      'entregador': entregador,
      'rua': rua,
      'numero': numero,
      'cep': cep,
      'complemento': complemento,
      'latitude': latitude,
      'longitude': longitude,
      'unidade': unidade,
      'cidade': cidade,
      'tipo_entrega': tipoEntrega,
      'data_agendamento': dataAgendamento,
      'horario_agendamento': horarioAgendamento,
      'telefone': telefone,
      'observacao': observacao,
      'produtos': produtos,
      'rastreio': rastreio,
      'AG': nomeCupom, // Inclui o nome do cupom no JSON
      'AH': porcentagemCupom, // Inclui a porcentagem do cupom
      'AI': descontoGiftCard, // Inclui o desconto do gift card
    };
  }

  Pedido copyWith({String? status}) {
    return Pedido(
      id: id,
      data: data,
      horario: horario,
      bairro: bairro,
      nome: nome,
      pagamento: pagamento,
      subTotal: subTotal,
      total: total,
      vendedor: vendedor,
      taxaEntrega: taxaEntrega,
      status: status ?? this.status,
      entregador: entregador,
      rua: rua,
      numero: numero,
      cep: cep,
      complemento: complemento,
      latitude: latitude,
      longitude: longitude,
      unidade: unidade,
      cidade: cidade,
      tipoEntrega: tipoEntrega,
      dataAgendamento: dataAgendamento,
      horarioAgendamento: horarioAgendamento,
      telefone: telefone,
      observacao: observacao,
      produtos: produtos,
      rastreio: rastreio,
      nomeCupom: nomeCupom,
      porcentagemCupom: porcentagemCupom,
      descontoGiftCard: descontoGiftCard,
    );
  }
}