import '../core/config.dart';
import '../domain/models.dart';

const _maxPorLinha = 5;

/// Ordena e tira as passagens repetidas (o OTP lista a mesma viagem em mais de um padrão).
/// Se a mesma hora vem ao vivo e programada, fica a ao vivo.
List<Chegada> _semRepetidas(List<Chegada> lista) {
  final ordenada = [...lista]..sort((a, b) => a.horario.compareTo(b.horario));
  final r = <Chegada>[];
  for (final c in ordenada) {
    if (r.isNotEmpty &&
        r.last.horario.difference(c.horario).inSeconds.abs() < 60) {
      if (c.aoVivo && !r.last.aoVivo) r[r.length - 1] = c;
      continue;
    }
    r.add(c);
  }
  return r;
}

/// Agrupa por (linha, destino), ordena, descarta o que já passou e limita a [_maxPorLinha] por linha.
/// A linha com o ônibus mais próximo vem primeiro.
List<SaidasLinha> _agrupar(
  Iterable<({String linha, String? destino, Chegada chegada})> itens,
  DateTime agora,
) {
  final corte = agora.subtract(const Duration(seconds: 30));
  final grupos = <String, List<Chegada>>{};
  final info = <String, ({String linha, String? destino})>{};
  for (final i in itens) {
    if (i.chegada.horario.isBefore(corte)) continue;
    final k = '${i.linha}|${i.destino ?? ''}';
    grupos.putIfAbsent(k, () => []).add(i.chegada);
    info[k] = (linha: i.linha, destino: i.destino);
  }
  final r = [
    for (final e in grupos.entries)
      SaidasLinha(
        linha: info[e.key]!.linha,
        destino: info[e.key]!.destino,
        chegadas: _semRepetidas(e.value).take(_maxPorLinha).toList(),
      ),
  ]..sort((a, b) => a.proxima.horario.compareTo(b.proxima.horario));
  return r;
}

/// Resposta de `index/stops/{id}/stoptimes` do planejador (OTP). Só traz horário programado.
///
/// Atenção: `serviceDay` vem com o sinal trocado (ex.: -1792810800). O valor absoluto é a meia-noite de Palmas
/// do dia do serviço, então o horário real é `|serviceDay| + saída`.
List<SaidasLinha> interpretarStoptimes(List json, {DateTime? agora}) {
  final agr = agora ?? DateTime.now();
  final itens = <({String linha, String? destino, Chegada chegada})>[];
  for (final p in json) {
    final linha = (p['pattern']['route']['shortName'] as String?) ?? '?';
    for (final t in (p['times'] as List)) {
      final vivo = t['realtime'] == true;
      final seg =
          (vivo ? t['realtimeDeparture'] : t['scheduledDeparture']) as num;
      final abs = (t['serviceDay'] as num).abs() + seg;
      itens.add((
        linha: linha,
        destino: t['headsign'] as String?,
        chegada: Chegada(
          horario: DateTime.fromMillisecondsSinceEpoch(
            abs.toInt() * 1000,
            isUtc: true,
          ),
          aoVivo: vivo,
          atrasoSeg: (t['departureDelay'] as num?)?.toInt(),
        ),
      ));
    }
  }
  return _agrupar(itens, agr);
}

/// Resposta de `departures?stop_id=…` da API da Mobilibus. Traz ônibus ao vivo (`vehicleId`) e programados.
/// Os horários vêm como "HH:mm:ss" do relógio de Palmas, com `nextDay` quando já é o dia seguinte.
List<SaidasLinha> interpretarDepartures(Map json, {DateTime? agora}) {
  final agr = agora ?? DateTime.now();
  final palmas = agr.toUtc().add(Config.fusoPalmas);
  final meiaNoite = DateTime.utc(palmas.year, palmas.month, palmas.day);
  final itens = <({String linha, String? destino, Chegada chegada})>[];
  for (final trip in (json['trips'] as List? ?? const [])) {
    final linha = (trip['shortName'] as String?) ?? '?';
    for (final d in (trip['departures'] as List? ?? const [])) {
      final p = (d['time'] as String).split(':').map(int.parse).toList();
      var parede = meiaNoite.add(
        Duration(hours: p[0], minutes: p[1], seconds: p.length > 2 ? p[2] : 0),
      );
      if (d['nextDay'] == true) parede = parede.add(const Duration(days: 1));
      itens.add((
        linha: linha,
        destino: trip['headsign'] as String?,
        chegada: Chegada(
          horario: parede.subtract(
            Config.fusoPalmas,
          ), // de relógio de Palmas para instante UTC
          aoVivo: d['vehicleId'] != null,
          atrasoSeg: (d['delay'] as num?)?.toInt(),
          veiculo: d['vehicleId']?.toString(),
        ),
      ));
    }
  }
  return _agrupar(itens, agr);
}

/// Junta as duas fontes. Para uma linha que a API trouxe, vale a API (tem o ao vivo); as demais vêm do OTP.
List<SaidasLinha> mesclarSaidas(List<SaidasLinha> api, List<SaidasLinha> otp) {
  final linhasApi = {for (final s in api) s.linha};
  final r = [...api, ...otp.where((s) => !linhasApi.contains(s.linha))]
    ..sort((a, b) => a.proxima.horario.compareTo(b.proxima.horario));
  return r;
}
