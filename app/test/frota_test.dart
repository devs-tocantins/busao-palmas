import 'package:busao_palmas/data/frota_repo.dart';
import 'package:busao_palmas/domain/models.dart';
import 'package:busao_palmas/domain/seu_onibus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

// 16:53:30 em Palmas = 19:53:30 UTC.
final _agora = DateTime.utc(2026, 10, 24, 19, 53, 30);

const _v090 = ViagemRef(tripId: '8494967', linha: '090', sentido: 1);
const _v620 = ViagemRef(tripId: '8495024', linha: '620', sentido: 1);

// Resposta real de /vehicles (2026-10-24).
const _resp = [
  {
    'vehicleId': '26022',
    'positionTime': '16:53:11',
    'lat': -10.26393977,
    'lng': -48.33324923,
    'percTravelled': 48,
    'heading': 180,
    'startTime': '16:30',
    'delay': -368,
    'seq': 22,
  },
  {
    'vehicleId': '26024',
    'positionTime': '16:52:52',
    'lat': -10.22128991,
    'lng': -48.33359127,
    'percTravelled': 26,
    'heading': 180,
    'startTime': '16:40',
    'delay': 120,
    'seq': 12,
  },
];

void main() {
  group('interpretarVeiculos', () {
    test('lê posição, rumo, atraso e hora do GPS (relógio de Palmas)', () {
      final r = interpretarVeiculos([(_v090, _resp)], agora: _agora);
      expect(r.map((o) => o.id), ['26022', '26024']);
      final o = r.first;
      expect(o.linha, '090');
      expect(o.sentido, 1);
      expect(o.pos.latitude, closeTo(-10.2639, 0.0001));
      expect(o.rumo, 180);
      expect(o.atrasoSeg, -368);
      expect(o.hora, DateTime.utc(2026, 10, 24, 19, 53, 11));
      expect(o.desatualizado(_agora), isFalse);
    });

    test(
      'o mesmo ônibus em duas viagens fica uma vez, com a posição mais nova',
      () {
        final velho = [
          {..._resp[0], 'positionTime': '16:40:00', 'lat': -10.30},
        ];
        final r = interpretarVeiculos([
          (_v090, velho),
          (_v620, _resp),
        ], agora: _agora);
        expect(r.where((o) => o.id == '26022').length, 1);
        expect(
          r.firstWhere((o) => o.id == '26022').pos.latitude,
          closeTo(-10.2639, 0.0001),
        );
      },
    );

    test('sem sinal há mais de 3 min fica marcado como desatualizado', () {
      final r = interpretarVeiculos([
        (
          _v090,
          [
            {..._resp[0], 'positionTime': '16:48:00'},
          ],
        ),
      ], agora: _agora);
      expect(r.single.desatualizado(_agora), isTrue);
    });

    test('posição "do futuro" (virada da meia-noite) é da véspera', () {
      // 00:01 em Palmas; o GPS diz 23:59:50.
      final meiaNoite = DateTime.utc(2026, 10, 25, 3, 1);
      final r = interpretarVeiculos([
        (
          _v090,
          [
            {..._resp[0], 'positionTime': '23:59:50'},
          ],
        ),
      ], agora: meiaNoite);
      expect(r.single.hora, DateTime.utc(2026, 10, 25, 2, 59, 50));
    });

    test('dados quebrados são ignorados sem derrubar a lista', () {
      final r = interpretarVeiculos([
        (
          _v090,
          [
            {'vehicleId': '1'},
            {'lat': -10.2, 'lng': -48.3, 'positionTime': '16:00:00'},
            'lixo',
            ..._resp,
          ],
        ),
      ], agora: _agora);
      expect(r.length, 2);
    });

    test('resposta vazia vira lista vazia', () {
      expect(interpretarVeiculos([(_v090, const [])], agora: _agora), isEmpty);
    });
  });

  group('escolherChegada: qual é o seu ônibus', () {
    Chegada c(int min, {String? veiculo}) => Chegada(
      horario: _agora.add(Duration(minutes: min)),
      aoVivo: veiculo != null,
      veiculo: veiculo,
    );
    final saidas = [
      SaidasLinha(
        linha: '090',
        destino: 'UFT',
        chegadas: [
          c(3, veiculo: '1'),
          c(23),
          c(43),
        ],
      ),
      SaidasLinha(
        linha: '090',
        destino: 'Eixão',
        chegadas: [c(1, veiculo: '9')],
      ),
      SaidasLinha(linha: '620', destino: 'Corujão', chegadas: [c(60)]),
    ];

    test(
      'pega a passagem mais perto do horário previsto, no sentido certo',
      () {
        final r = escolherChegada(
          saidas,
          linha: '090',
          destino: 'UFT',
          previsto: _agora.add(const Duration(minutes: 24)),
          agora: _agora,
        );
        expect(r?.horario, _agora.add(const Duration(minutes: 23)));
      },
    );

    test('sentido desconhecido: olha todas as passagens da linha', () {
      final r = escolherChegada(
        saidas,
        linha: '090',
        destino: 'outro',
        previsto: _agora.add(const Duration(minutes: 1)),
        agora: _agora,
      );
      expect(r?.veiculo, '9');
    });

    test('longe de tudo, fica com a próxima que ainda não passou', () {
      final r = escolherChegada(
        saidas,
        linha: '090',
        destino: 'UFT',
        previsto: _agora.add(const Duration(hours: 5)),
        agora: _agora,
      );
      expect(r?.veiculo, '1');
    });

    test('linha que não passa ali, ou só passagens antigas, dá null', () {
      expect(
        escolherChegada(
          saidas,
          linha: '999',
          destino: null,
          previsto: _agora,
          agora: _agora,
        ),
        isNull,
      );
      final passadas = [
        SaidasLinha(linha: '090', destino: 'UFT', chegadas: [c(-20)]),
      ];
      expect(
        escolherChegada(
          passadas,
          linha: '090',
          destino: 'UFT',
          previsto: _agora,
          agora: _agora,
        ),
        isNull,
      );
    });
  });

  test('interpretarDepartures guarda o número do ônibus (vehicleId)', () {
    // Coberto em saidas_test; aqui só a distância até a parada.
    final o = interpretarVeiculos([(_v090, _resp)], agora: _agora).first;
    final parada = const LatLng(-10.2639, -48.3332);
    expect(metrosAte(o, parada), lessThan(10));
  });
}
