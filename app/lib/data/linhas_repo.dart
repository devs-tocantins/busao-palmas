import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'package:latlong2/latlong.dart';

import '../core/config.dart';
import 'frota_repo.dart' show ViagemRef;
import 'dados_locais.dart';

/// Horários de um tipo de dia (dias úteis, sábados ou domingos).
class ServicoLinha {
  const ServicoLinha({
    required this.nome,
    required this.dias,
    required this.saidas,
  });

  final String nome;

  /// Sete valores na ordem [dom, seg, ter, qua, qui, sex, sáb].
  final List<bool> dias;

  /// Partidas "HH:MM" no relógio de Palmas, em ordem.
  final List<String> saidas;

  bool vale(int diaDaSemana) => dias[diaDaSemana];
}

/// Um sentido da linha: horários, traçado e a sequência de paradas.
class SentidoLinha {
  const SentidoLinha({
    required this.id,
    required this.nome,
    required this.destino,
    required this.servicos,
    required this.caminho,
    required this.paradas,
  });

  final int id;
  final String nome;
  final String destino;
  final List<ServicoLinha> servicos;
  final List<LatLng> caminho;
  final List<ParadaLocal> paradas;

  /// A parada deste sentido mais perto de [p]: posição na lista e distância em metros. null se não há paradas.
  ({int indice, double metros})? maisPerto(LatLng p) {
    const dist = Distance();
    int? melhor;
    var menor = double.infinity;
    for (var i = 0; i < paradas.length; i++) {
      final m = dist.as(LengthUnit.Meter, p, paradas[i].pos);
      if (m < menor) {
        menor = m;
        melhor = i;
      }
    }
    return melhor == null ? null : (indice: melhor, metros: menor);
  }
}

class DetalheLinha {
  const DetalheLinha({required this.linha, required this.sentidos});

  final LinhaLocal linha;
  final List<SentidoLinha> sentidos;
}

/// Horários, traçados e paradas de cada linha, do snapshot embutido (docs/DADOS.md). Sem rede.
class DadosLinhas {
  const DadosLinhas(this.porNumero, [this.viagens = const []]);

  final Map<String, DetalheLinha> porNumero;

  /// Todas as viagens (id, linha e sentido), para perguntar à API onde estão os ônibus.
  final List<ViagemRef> viagens;

  /// Linhas em ordem de número.
  List<DetalheLinha> get todas =>
      (porNumero.values.toList()
        ..sort((a, b) => a.linha.numero.compareTo(b.linha.numero)));

  static Future<DadosLinhas> carregar(DadosLocais dados) async {
    Future<Object?> ler(String nome) async =>
        jsonDecode(await rootBundle.loadString('assets/data/$nome.json'));
    final r = await Future.wait([
      ler('linhas'),
      ler('horarios'),
      ler('trajetos'),
    ]);
    return montar(
      linhas: r[0] as List,
      horarios: r[1] as Map,
      trajetos: r[2] as Map,
      dados: dados,
    );
  }

  /// Separado de [carregar] para poder ser testado com os arquivos de assets/data.
  static DadosLinhas montar({
    required List linhas,
    required Map horarios,
    required Map trajetos,
    required DadosLocais dados,
  }) {
    final paradas = {for (final p in dados.paradas) p.id: p};
    // Por linha e sentido, a viagem com mais paradas: é a que mostra o percurso inteiro.
    final viagens = <String, Map>{};
    for (final v in trajetos.values) {
      final chave = '${v['linha']}|${v['sentido']}';
      final atual = viagens[chave];
      if (atual == null ||
          (v['paradas'] as List).length > (atual['paradas'] as List).length) {
        viagens[chave] = v as Map;
      }
    }

    final r = <String, DetalheLinha>{};
    for (final l in linhas) {
      final numero = l['numero'] as String;
      final info = dados.linhas[numero];
      if (info == null) continue;
      final deHorarios = {
        for (final h in (horarios['${l['id']}'] as List? ?? const []))
          h['sentido'] as int: h['servicos'] as List,
      };
      r[numero] = DetalheLinha(
        linha: info,
        sentidos: [
          for (final s in l['sentidos'] as List)
            () {
              final id = s['id'] as int;
              final v = viagens['${l['id']}|$id'];
              final shape = v?['shape'] as String?;
              return SentidoLinha(
                id: id,
                nome: s['nome'] as String,
                destino: s['destino'] as String,
                servicos: [
                  for (final sv in deHorarios[id] ?? const [])
                    ServicoLinha(
                      nome: sv['nome'] as String,
                      dias: [for (final d in sv['dias'] as List) d == true],
                      saidas: [
                        for (final x in sv['saidas'] as List)
                          (x as List)[0] as String,
                      ]..sort(),
                    ),
                ],
                caminho: shape == null
                    ? const []
                    : [
                        for (final c in decodePolyline(shape))
                          LatLng(c[0].toDouble(), c[1].toDouble()),
                      ],
                paradas: [
                  for (final p in (v?['paradas'] as List? ?? const []))
                    if (paradas[p] != null) paradas[p]!,
                ],
              );
            }(),
        ],
      );
    }
    final numeroPorId = {
      for (final l in linhas) l['id']: l['numero'] as String,
    };
    return DadosLinhas(r, [
      for (final e in trajetos.entries)
        if (numeroPorId[(e.value as Map)['linha']] != null)
          ViagemRef(
            tripId: e.key as String,
            linha: numeroPorId[(e.value as Map)['linha']]!,
            sentido: ((e.value as Map)['sentido'] as num).toInt(),
          ),
    ]);
  }

  /// Dia da semana de agora em Palmas, no formato [dom=0 … sáb=6].
  static int hoje([DateTime? agora]) =>
      (agora ?? DateTime.now()).toUtc().add(Config.fusoPalmas).weekday % 7;
}
