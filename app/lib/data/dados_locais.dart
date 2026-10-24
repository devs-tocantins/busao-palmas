import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

class ParadaLocal {
  const ParadaLocal(this.id, this.nome, this.pos);
  final int id;
  final String nome;
  final LatLng pos;
}

class LinhaLocal {
  const LinhaLocal(this.numero, this.nome, this.cor, this.corTexto);
  final String numero;
  final String nome;
  final Color cor;
  final Color corTexto;
}

Color _cor(String hex) => Color(int.parse('FF${hex.substring(1)}', radix: 16));

/// Dados do snapshot (docs/DADOS.md) embutidos no app: nomes das paradas e cores das linhas.
class DadosLocais {
  DadosLocais(this.paradas, this.linhas);

  final List<ParadaLocal> paradas;
  final Map<String, LinhaLocal> linhas;

  static Future<DadosLocais> carregar() async {
    final p = jsonDecode(
      await rootBundle.loadString('assets/data/paradas.json'),
    ) as List;
    final l = jsonDecode(
      await rootBundle.loadString('assets/data/linhas.json'),
    ) as List;
    return DadosLocais(
      [
        for (final x in p)
          ParadaLocal(
            x['id'] as int,
            x['nome'] as String,
            LatLng((x['lat'] as num).toDouble(), (x['lng'] as num).toDouble()),
          ),
      ],
      {
        for (final x in l)
          x['numero'] as String: LinhaLocal(
            x['numero'] as String,
            x['nome'] as String,
            _cor(x['cor'] as String),
            _cor(x['corTexto'] as String),
          ),
      },
    );
  }

  /// Parada do snapshot mais próxima de [p], se estiver a até [maxM] metros.
  ParadaLocal? paradaPerto(LatLng p, {double maxM = 30}) {
    ParadaLocal? melhor;
    var menor = double.infinity;
    final kx = 111320 * math.cos(p.latitude * math.pi / 180), ky = 110574.0;
    for (final s in paradas) {
      final dx = (s.pos.longitude - p.longitude) * kx,
          dy = (s.pos.latitude - p.latitude) * ky;
      final d = dx * dx + dy * dy;
      if (d < menor) {
        menor = d;
        melhor = s;
      }
    }
    return menor <= maxM * maxM ? melhor : null;
  }

  /// Até [max] paradas a no máximo [raioM] metros de [p], da mais perto para a mais longe.
  /// Calculado no aparelho com as 1.210 paradas do snapshot: não precisa de rede.
  List<({ParadaLocal parada, double metros})> paradasPerto(
    LatLng p, {
    int max = 3,
    double raioM = 600,
  }) {
    final kx = 111320 * math.cos(p.latitude * math.pi / 180), ky = 110574.0;
    final perto = <({ParadaLocal parada, double metros})>[];
    for (final s in paradas) {
      final dx = (s.pos.longitude - p.longitude) * kx,
          dy = (s.pos.latitude - p.latitude) * ky;
      final m = math.sqrt(dx * dx + dy * dy);
      if (m <= raioM) perto.add((parada: s, metros: m));
    }
    perto.sort((a, b) => a.metros.compareTo(b.metros));
    return perto.take(max).toList();
  }

  /// Nome legível da parada em [p]. O OTP às vezes só devolve o código numérico.
  String nomeParada(LatLng p, {String? nomeOtp}) {
    final local = paradaPerto(p);
    if (local != null && !local.nome.startsWith('Parada ')) return local.nome;
    final limpo = nomeOtp == null ? null : _limpar(nomeOtp);
    if (limpo != null &&
        limpo.isNotEmpty &&
        !RegExp(r'^\d+$').hasMatch(limpo)) {
      return limpo;
    }
    return local?.nome ?? 'Parada';
  }

  static String _limpar(String n) => n
      .replaceAll(
        RegExp(r'\s*Palmas\s*-\s*Tocantins.*$', caseSensitive: false),
        '',
      )
      .replaceAll(RegExp(r'\s*\d{5}-?\d{3}.*$'), '')
      .replaceAll(RegExp(r'\s*Brasil$', caseSensitive: false), '')
      .trim();
}
