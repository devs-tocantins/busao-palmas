import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/frota_repo.dart';
import 'parada.dart';

/// A API de posição dos ônibus não libera o navegador: ao vivo só no app (ver docs/ARQUITETURA.md, proxy).
bool get frotaDisponivel => !kIsWeb;

/// Intervalo sugerido pela própria Mobilibus (`realtimeUpdateFreqSec`).
const intervaloFrota = Duration(seconds: 20);

final frotaRepoProvider = FutureProvider<FrotaRepo>((ref) async {
  final linhas = await ref.watch(dadosLinhasProvider.future);
  return FrotaRepo(linhas.viagens);
});

/// O usuário pode esconder os ônibus do mapa.
class MostrarOnibus extends Notifier<bool> {
  @override
  bool build() => true;

  void alternar() => state = !state;
}

final mostrarOnibusProvider = NotifierProvider<MostrarOnibus, bool>(
  MostrarOnibus.new,
);

/// Todos os ônibus rodando, atualizados a cada 20 s enquanto alguma tela os estiver mostrando.
/// (autoDispose: quando nenhuma tela olha, a consulta para.)
final frotaProvider = StreamProvider.autoDispose<List<Onibus>>((ref) async* {
  if (!frotaDisponivel) {
    yield const [];
    return;
  }
  final repo = await ref.watch(frotaRepoProvider.future);
  var ativo = true;
  ref.onDispose(() => ativo = false);
  var ultimo = const <Onibus>[];
  var primeira = true;
  while (ativo) {
    try {
      ultimo = await repo.carregar();
      primeira = false;
      if (ativo) yield ultimo;
    } catch (e) {
      // Sem internet por um momento: segue mostrando a última posição conhecida.
      if (primeira) {
        primeira = false;
        yield const [];
      }
    }
    await Future<void>.delayed(intervaloFrota);
  }
}, retry: (_, _) => null);
