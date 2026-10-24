import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum TipoTrecho { andar, onibus }

class Lugar {
  const Lugar({
    required this.nome,
    required this.pos,
    this.detalhe,
    this.ehParada = false,
    this.minhaLocalizacao = false,
  });

  final String nome;
  final String? detalhe;
  final LatLng pos;
  final bool ehParada;
  final bool minhaLocalizacao;

  /// Para guardar no aparelho. "Minha localização" nunca é guardada (muda a cada uso).
  Map<String, dynamic> toJson() => {
    'nome': nome,
    if (detalhe != null) 'detalhe': detalhe,
    'lat': pos.latitude,
    'lng': pos.longitude,
    if (ehParada) 'parada': true,
  };

  factory Lugar.fromJson(Map<String, dynamic> j) => Lugar(
    nome: j['nome'] as String,
    detalhe: j['detalhe'] as String?,
    pos: LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
    ehParada: j['parada'] == true,
  );
}

/// Um trecho da rota: a pé ou de ônibus.
class Trecho {
  const Trecho({
    required this.tipo,
    required this.inicio,
    required this.fim,
    required this.distanciaM,
    required this.de,
    required this.para,
    required this.nomeDe,
    required this.nomePara,
    required this.caminho,
    this.linha,
    this.destino,
    this.nomeLinha,
    this.numParadas,
    this.aoVivo = false,
    this.codigoDe,
    this.codigoPara,
    this.cor,
    this.corTexto,
  });

  final TipoTrecho tipo;
  final DateTime inicio;
  final DateTime fim;
  final double distanciaM;
  final LatLng de;
  final LatLng para;
  final String nomeDe;
  final String nomePara;
  final List<LatLng> caminho;

  // Só para ônibus.
  final String? linha;
  final String? destino;
  final String? nomeLinha;
  final int? numParadas;
  final bool aoVivo;
  final String? codigoDe;
  final String? codigoPara;
  final Color? cor;
  final Color? corTexto;

  Duration get duracao => fim.difference(inicio);
}

/// Uma opção de rota devolvida pelo planejador.
class Opcao {
  const Opcao({
    required this.inicio,
    required this.fim,
    required this.duracao,
    required this.trocas,
    required this.trechos,
  });

  final DateTime inicio;
  final DateTime fim;
  final Duration duracao;
  final int trocas;
  final List<Trecho> trechos;

  List<Trecho> get onibus =>
      trechos.where((t) => t.tipo == TipoTrecho.onibus).toList();

  double get andarM => trechos
      .where((t) => t.tipo == TipoTrecho.andar)
      .fold(0.0, (s, t) => s + t.distanciaM);

  /// Embarca e desce nas mesmas paradas = mesma viagem para quem usa; só a linha ou o horário mudam.
  String get chave =>
      onibus.map((t) => '${t.codigoDe}>${t.codigoPara}').join('|');
}

/// Opções equivalentes agrupadas: mesmas paradas de embarque e desembarque.
class GrupoOpcoes {
  GrupoOpcoes(this.principal, this.alternativas);

  final Opcao principal;
  final List<Opcao> alternativas;

  List<Opcao> get todas => [principal, ...alternativas];

  /// Linhas que servem o trecho de ônibus [i], sem repetir, na ordem em que aparecem.
  List<String> linhasDoTrecho(int i) {
    final r = <String>[];
    for (final o in todas) {
      final b = o.onibus;
      if (i < b.length && b[i].linha != null && !r.contains(b[i].linha)) {
        r.add(b[i].linha!);
      }
    }
    return r;
  }

  /// Horários de saída das outras opções (depois da principal), sem repetir.
  List<DateTime> get outrasSaidas {
    final r =
        alternativas
            .map((o) => o.inicio)
            .where((t) => t.isAfter(principal.inicio))
            .toList()
          ..sort();
    return r;
  }
}

List<GrupoOpcoes> agruparOpcoes(List<Opcao> opcoes) {
  final porChave = <String, List<Opcao>>{};
  for (final o in opcoes) {
    porChave.putIfAbsent(o.chave, () => []).add(o);
  }
  final grupos = porChave.values.map((lista) {
    lista.sort((a, b) => a.fim.compareTo(b.fim));
    return GrupoOpcoes(lista.first, lista.skip(1).toList());
  }).toList()..sort((a, b) => a.principal.fim.compareTo(b.principal.fim));
  return grupos;
}

/// Uma parada que se quer consultar: o nome para mostrar e o ponto no mapa.
class ParadaRef {
  const ParadaRef({required this.nome, required this.pos});

  final String nome;
  final LatLng pos;

  Map<String, dynamic> toJson() => {
    'nome': nome,
    'lat': pos.latitude,
    'lng': pos.longitude,
  };

  factory ParadaRef.fromJson(Map<String, dynamic> j) => ParadaRef(
    nome: j['nome'] as String,
    pos: LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
  );

  @override
  bool operator ==(Object other) =>
      other is ParadaRef &&
      other.nome == nome &&
      other.pos.latitude.toStringAsFixed(5) ==
          pos.latitude.toStringAsFixed(5) &&
      other.pos.longitude.toStringAsFixed(5) ==
          pos.longitude.toStringAsFixed(5);

  @override
  int get hashCode => Object.hash(
    nome,
    pos.latitude.toStringAsFixed(5),
    pos.longitude.toStringAsFixed(5),
  );
}

/// Uma passagem de ônibus numa parada.
class Chegada {
  const Chegada({
    required this.horario,
    this.aoVivo = false,
    this.atrasoSeg,
    this.veiculo,
  });

  final DateTime horario;

  /// true quando há um ônibus real a caminho (posição de GPS); false é horário programado.
  final bool aoVivo;
  final int? atrasoSeg;

  /// Número do ônibus que vai fazer esta passagem (`vehicleId` da API), quando já há GPS.
  final String? veiculo;

  Duration quantoFalta([DateTime? agora]) =>
      horario.difference(agora ?? DateTime.now());
}

/// As próximas passagens de uma linha, num sentido, numa parada.
class SaidasLinha {
  const SaidasLinha({
    required this.linha,
    required this.destino,
    required this.chegadas,
  });

  final String linha;
  final String? destino;
  final List<Chegada> chegadas;

  Chegada get proxima => chegadas.first;
}
