import 'dart:convert';
import 'dart:io';

import 'package:busao_palmas/core/formato.dart';
import 'package:busao_palmas/data/saidas.dart';
import 'package:flutter_test/flutter_test.dart';

// Instante em que as respostas de test/fixtures foram gravadas: 01:08 em Palmas (04:08 UTC).
final _agora = DateTime.fromMillisecondsSinceEpoch(1792814886787, isUtc: true);

void main() {
  testesRepetidas();
  final departures = jsonDecode(
    File('test/fixtures/departures.json').readAsStringSync(),
  ) as Map;
  final stoptimes = jsonDecode(
    File('test/fixtures/stoptimes.json').readAsStringSync(),
  ) as List;

  group('API departures (Mobilibus)', () {
    test(
      'Corujão: 01:36 e 03:36 de hoje, e o de amanhã não vira o próximo',
      () {
        final r = interpretarDepartures(departures, agora: _agora);
        final coruja = r.firstWhere((s) => s.linha == '620');
        expect(horaPalmas(coruja.proxima.horario), '01:36');
        expect(
          coruja.proxima.quantoFalta(_agora).inMinutes,
          inInclusiveRange(27, 29),
        );
        expect(coruja.chegadas.map((c) => horaPalmas(c.horario)), [
          '01:36',
          '03:36',
          '01:36',
          '03:36',
        ]);
        expect(
          coruja.chegadas[2].horario
              .difference(coruja.chegadas.first.horario)
              .inHours,
          24,
          reason: 'o 01:36 de amanhã tem nextDay=true',
        );
        expect(coruja.destino, 'Sol Nascente - Corujão');
      },
    );

    test(
      'ordenado do mais próximo para o mais distante, no máximo 5 por linha',
      () {
        final r = interpretarDepartures(departures, agora: _agora);
        for (var i = 1; i < r.length; i++) {
          expect(
            r[i].proxima.horario.isBefore(r[i - 1].proxima.horario),
            isFalse,
          );
        }
        expect(r.every((s) => s.chegadas.length <= 5), isTrue);
      },
    );

    test('descarta o que já passou', () {
      final depois = _agora.add(
        const Duration(hours: 1),
      ); // 02:08: o 01:36 já passou
      final coruja = interpretarDepartures(
        departures,
        agora: depois,
      ).firstWhere((s) => s.linha == '620');
      expect(horaPalmas(coruja.proxima.horario), '03:36');
    });

    test('ônibus com vehicleId é ao vivo e guarda o atraso', () {
      final vivo = {
        'trips': [
          {
            'shortName': '090',
            'headsign': 'Estação Apinajé / UFT',
            'departures': [
              {
                'time': '01:20:00',
                'nextDay': false,
                'vehicleId': '26036',
                'delay': 120,
              },
              {'time': '01:40:00', 'nextDay': false},
            ],
          },
        ],
      };
      final s = interpretarDepartures(vivo, agora: _agora).single;
      expect(s.chegadas.first.aoVivo, isTrue);
      expect(s.chegadas.first.atrasoSeg, 120);
      expect(s.chegadas.first.veiculo, '26036');
      expect(s.chegadas.last.veiculo, isNull);
      expect(s.chegadas.last.aoVivo, isFalse);
    });

    test('resposta vazia vira lista vazia', () {
      expect(interpretarDepartures({'trips': []}, agora: _agora), isEmpty);
      expect(interpretarDepartures({}, agora: _agora), isEmpty);
    });
  });

  group('OTP stoptimes', () {
    test(
      'serviceDay vem com o sinal trocado e mesmo assim dá o horário certo',
      () {
        final r = interpretarStoptimes(stoptimes, agora: _agora);
        expect(r, isNotEmpty);
        for (final s in r) {
          for (final c in s.chegadas) {
            // todas no futuro próximo (até ~24 h), nunca em 1913
            expect(c.horario.year, 2026);
            expect(c.quantoFalta(_agora).inHours, lessThan(30));
          }
        }
      },
    );

    test('tudo é horário programado (o OTP de Palmas não traz tempo real)', () {
      final r = interpretarStoptimes(stoptimes, agora: _agora);
      expect(r.expand((s) => s.chegadas).any((c) => c.aoVivo), isFalse);
    });

    test('dois padrões da mesma linha e destino viram uma linha só', () {
      final r = interpretarStoptimes(stoptimes, agora: _agora);
      final chaves = r.map((s) => '${s.linha}|${s.destino}').toList();
      expect(chaves.toSet().length, chaves.length);
    });
  });

  test('mesclar: vale a API para as linhas que ela trouxe e o OTP completa o resto', () {
    final api = interpretarDepartures(departures, agora: _agora);
    final otp = interpretarStoptimes(stoptimes, agora: _agora);
    final m = mesclarSaidas(api, otp);
    final linhasApi = api.map((s) => s.linha).toSet();
    for (final l in linhasApi) {
      expect(
        m.where((s) => s.linha == l).length,
        api.where((s) => s.linha == l).length,
      );
    }
    expect(m.map((s) => s.linha).toSet(), containsAll(otp.map((s) => s.linha)));
  });
}

void testesRepetidas() {
  test('a mesma passagem listada em dois padrões aparece uma vez só', () {
    final json = [
      for (var i = 0; i < 2; i++) // dois padrões com a mesma viagem
        {
          'pattern': {
            'route': {'shortName': '140'},
          },
          'times': [
            {
              'serviceDay': -1792810800,
              'scheduledDeparture': 19800,
              'headsign': 'Apinajé/ Sonho meu',
              'realtime': false,
            },
            {
              'serviceDay': -1792810800,
              'scheduledDeparture': 41400,
              'headsign': 'Apinajé/ Sonho meu',
              'realtime': false,
            },
          ],
        },
    ];
    final r = interpretarStoptimes(json, agora: _agora).single;
    expect(r.chegadas.map((c) => horaPalmas(c.horario)), ['05:30', '11:30']);
  });
}
