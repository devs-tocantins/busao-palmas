import 'package:latlong2/latlong.dart';

import '../data/frota_repo.dart';
import 'models.dart';

/// Das passagens da linha na parada de embarque, qual é a que a pessoa vai pegar: a mais perto do horário
/// que o planejador previu para sair ([previsto]). Se nenhuma estiver a menos de [tolerancia] dele
/// (por exemplo, o planejador usou um horário de amanhã), fica a primeira que ainda não passou.
Chegada? escolherChegada(
  List<SaidasLinha> saidas, {
  required String linha,
  required String? destino,
  required DateTime previsto,
  Duration tolerancia = const Duration(minutes: 10),
  DateTime? agora,
}) {
  final agr = agora ?? DateTime.now();
  final daLinha = saidas.where((s) => s.linha == linha).toList();
  if (daLinha.isEmpty) return null;
  // Mesmo sentido, se der para saber; senão, todas da linha.
  final mesmoSentido = daLinha.where((s) => s.destino == destino).toList();
  final candidatas = [
    for (final s in (mesmoSentido.isEmpty ? daLinha : mesmoSentido))
      ...s.chegadas,
  ].where((c) => c.horario.isAfter(agr.subtract(const Duration(seconds: 30))));
  if (candidatas.isEmpty) return null;
  final ordenadas = candidatas.toList()
    ..sort(
      (a, b) => a.horario
          .difference(previsto)
          .abs()
          .compareTo(b.horario.difference(previsto).abs()),
    );
  final melhor = ordenadas.first;
  if (melhor.horario.difference(previsto).abs() <= tolerancia) return melhor;
  final porHora = candidatas.toList()
    ..sort((a, b) => a.horario.compareTo(b.horario));
  return porHora.first;
}

/// Distância em linha reta, em metros, entre o ônibus e [ponto].
double metrosAte(Onibus o, LatLng ponto) =>
    const Distance().as(LengthUnit.Meter, o.pos, ponto);
