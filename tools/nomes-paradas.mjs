// Dá nome legível às paradas: "Av. NS 10 × Av. Teotônio Segurado" ou "Av. X · perto de Y".
import { baixarRuas, baixarLugares, baixarLocalidades } from './osm.mjs';

const R = 6371000, rad = Math.PI / 180;
const LAT0 = -10.2, kx = R * rad * Math.cos(LAT0 * rad), ky = R * rad; // projeção plana local, em metros
const xy = (lat, lng) => [lng * kx, lat * ky];

function distSeg(p, a, b) {
  const dx = b[0] - a[0], dy = b[1] - a[1];
  const t = dx || dy ? Math.max(0, Math.min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / (dx * dx + dy * dy))) : 0;
  return Math.hypot(p[0] - (a[0] + t * dx), p[1] - (a[1] + t * dy));
}

const ABREV = [[/^Avenida /i, 'Av. '], [/^Rodovia /i, 'Rod. '], [/^Alameda /i, 'Al. '], [/^Travessa /i, 'Tv. ']];
const nomeRua = (n) => ABREV.reduce((s, [re, t]) => s.replace(re, t), n).replace(/\b([A-Z]{2})-0?(\d+)\b/g, '$1 $2');
const chaveRua = (n) => n.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, '');

// Distância de edição; grafias como 'Jucelino' e 'Juscelino' contam como a mesma rua.
function editar(a, b) {
  const d = Array.from({ length: a.length + 1 }, (_, i) => [i, ...Array(b.length).fill(0)]);
  for (let j = 1; j <= b.length; j++) d[0][j] = j;
  for (let i = 1; i <= a.length; i++) for (let j = 1; j <= b.length; j++)
    d[i][j] = Math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
  return d[a.length][b.length];
}
const mesmaRua = (a, b) => a === b || editar(a, b) <= 2 || a.includes(b) || b.includes(a);

// Lugares que servem de referência para quem espera o ônibus, do mais ao menos útil.
const PESO = { hospital: 9, university: 9, college: 8, school: 7, marketplace: 8, supermarket: 7, mall: 9, place_of_worship: 6, bank: 5, park: 6, pharmacy: 4, fuel: 4, townhall: 8, police: 5, library: 5 };
const pesoLugar = (t) => PESO[t.amenity] ?? PESO[t.shop] ?? PESO[t.leisure] ?? (t.aeroway ? 9 : t.tourism ? 5 : 0);

export async function criarNomeador() {
  const ruas = (await baixarRuas()).filter((r) => r.geometry && r.tags?.name)
    .map((r) => ({ nome: nomeRua(r.tags.name), chave: chaveRua(nomeRua(r.tags.name)), pts: r.geometry.map((g) => xy(g.lat, g.lon)) }));
  const lugares = (await baixarLugares())
    .map((e) => ({ nome: e.tags.name, peso: pesoLugar(e.tags), p: xy(e.lat ?? e.center?.lat, e.lon ?? e.center?.lon) }))
    .filter((l) => l.peso > 0 && !Number.isNaN(l.p[0]));
  const localidades = (await baixarLocalidades())
    .map((e) => ({ nome: e.tags.name.replace(/\s*\(.*?\)\s*/g, '').trim(), p: xy(e.lat ?? e.center?.lat, e.lon ?? e.center?.lon) }));

  const menor = (lista, p, f) => lista.reduce((m, x) => { const d = f(x, p); return d < m.d ? { x, d } : m; }, { x: null, d: Infinity });

  return function nomear(lat, lng) {
    const p = xy(lat, lng);
    // ruas ordenadas por distância (mínima por nome)
    const porRua = new Map();
    for (const r of ruas) {
      let d = Infinity;
      for (let i = 0; i < r.pts.length - 1; i++) d = Math.min(d, distSeg(p, r.pts[i], r.pts[i + 1]));
      if (d < 150 && d < (porRua.get(r.chave)?.d ?? Infinity)) porRua.set(r.chave, { nome: r.nome, chave: r.chave, d });
    }
    const perto = [...porRua.values()].sort((a, b) => a.d - b.d);
    const rua = perto[0] && perto[0].d <= 80 ? perto[0] : null;
    const cruza = rua ? perto.slice(1).find((r) => r.d <= 120 && !mesmaRua(rua.chave, r.chave)) : null;

    const pontos = lugares.filter((l) => Math.hypot(l.p[0] - p[0], l.p[1] - p[1]) <= 150)
      .sort((a, b) => b.peso - a.peso || Math.hypot(a.p[0] - p[0], a.p[1] - p[1]) - Math.hypot(b.p[0] - p[0], b.p[1] - p[1]));
    const ref = pontos[0]?.nome ?? null;
    const loc = menor(localidades, p, (x, q) => Math.hypot(x.p[0] - q[0], x.p[1] - q[1]));

    let nome = null, tipo = null;
    if (rua && cruza) { nome = `${rua.nome} × ${cruza.nome}`; tipo = 'cruzamento'; }
    else if (rua && ref) { nome = `${rua.nome} · perto de ${ref}`; tipo = 'rua+lugar'; }
    else if (rua) { nome = rua.nome; tipo = 'rua'; }
    else if (ref) { nome = `Perto de ${ref}`; tipo = 'lugar'; }
    else if (loc.x && loc.d < 8000) { nome = `Região ${loc.x.nome}`; tipo = 'localidade'; }
    return { nome, tipo, ref, rua: rua?.nome ?? null, cruza: cruza?.nome ?? null, localidade: loc.x?.nome ?? null };
  };
}
