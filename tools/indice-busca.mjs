// Monta o índice de busca de lugares de Palmas (ruas, bairros/quadras, lugares) a partir do OpenStreetMap.
// Saída: data/busca.json = [{ n: nome, k: tipo, la, lo }]. A busca em si roda no app, sem servidor.
import { writeFileSync, mkdirSync } from 'node:fs';
import { baixarRuas, baixarLugares, baixarLocalidades } from './osm.mjs';

export const normalizar = (s) =>
  s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()
    .replace(/\bav\b\.?/g, 'avenida').replace(/\bq[ds]?\b\.?/g, 'quadra').replace(/\bqd\b/g, 'quadra')
    .replace(/\b(ns|lo|se|ne|so|no)[-\s]?0*(\d+)\b/g, '$1 $2')
    .replace(/[^a-z0-9]+/g, ' ').trim();

const tipoLugar = (t) =>
  t.aeroway ? 'aeroporto' : /hospital|clinic|pharmacy|doctors|dentist/.test(t.amenity ?? '') || t.healthcare ? 'saude' :
  /school|college|university|kindergarten|library/.test(t.amenity ?? '') ? 'educacao' :
  t.shop || t.amenity === 'marketplace' ? 'comercio' : t.leisure || t.tourism ? 'lazer' :
  t.amenity === 'place_of_worship' ? 'culto' : 'lugar';

export async function montarIndice() {
  const itens = [];
  // ruas: um item por nome, no ponto médio do trecho mais longo
  const porNome = new Map();
  for (const r of await baixarRuas()) {
    if (!r.geometry?.length || !r.tags?.name) continue;
    const atual = porNome.get(r.tags.name);
    if (!atual || r.geometry.length > atual.length) porNome.set(r.tags.name, r.geometry);
  }
  for (const [n, g] of porNome) { const m = g[g.length >> 1]; itens.push({ n, k: 'rua', la: m.lat, lo: m.lon }); }
  for (const e of await baixarLocalidades()) {
    const n = e.tags.name.trim(); const la = e.lat ?? e.center?.lat, lo = e.lon ?? e.center?.lon;
    if (la != null) itens.push({ n, k: 'bairro', la, lo });
  }
  for (const e of await baixarLugares()) {
    const la = e.lat ?? e.center?.lat, lo = e.lon ?? e.center?.lon;
    if (la != null && e.tags?.name) itens.push({ n: e.tags.name.trim(), k: tipoLugar(e.tags), la, lo });
  }
  // remove repetidos (mesmo nome normalizado e a menos de ~150 m)
  const vistos = new Map(), saida = [];
  for (const i of itens) {
    const chave = normalizar(i.n); const lista = vistos.get(chave) ?? [];
    if (lista.some((o) => Math.abs(o.la - i.la) < 0.0015 && Math.abs(o.lo - i.lo) < 0.0015)) continue;
    lista.push(i); vistos.set(chave, lista); saida.push({ ...i, la: +i.la.toFixed(5), lo: +i.lo.toFixed(5) });
  }
  return saida;
}

// Busca de referência (o app Flutter implementa a mesma regra): todos os termos devem iniciar uma palavra do nome.
export function buscar(indice, consulta, limite = 8, apelidos = {}) {
  const alvo = Object.entries(apelidos).find(([a]) => normalizar(a) === normalizar(consulta));
  const termos = normalizar(alvo ? alvo[1] : consulta).split(' ').filter(Boolean);
  if (!termos.length) return [];
  const pesoK = { aeroporto: 0, educacao: 1, saude: 1, lazer: 1, comercio: 2, lugar: 2, culto: 3, bairro: 1, rua: 3 };
  return indice
    .map((i) => ({ i, p: normalizar(i.n).split(' ') }))
    .filter(({ p }) => termos.every((t) => p.some((w) => w.startsWith(t))))
    .map(({ i, p }) => ({ i, s: (p[0].startsWith(termos[0]) ? 0 : 5) + (pesoK[i.k] ?? 3) + i.n.length / 100 }))
    .sort((a, b) => a.s - b.s).slice(0, limite).map((x) => x.i);
}

if (process.argv[1] && import.meta.url === `file:///${process.argv[1].replace(/\\/g, '/')}`) {
  const idx = await montarIndice();
  mkdirSync('../data/gerado', { recursive: true });
  writeFileSync('../data/gerado/busca.json', JSON.stringify(idx));
  console.log(`${idx.length} itens`, JSON.stringify(idx.reduce((c, i) => ((c[i.k] = (c[i.k] || 0) + 1), c), {})));
}
