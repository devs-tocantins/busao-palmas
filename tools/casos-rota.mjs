// Roda data/casos_rota.json no planejador (OTP) de Palmas. Formato e uso: docs/CASOS_ROTA.md
// Uso: node casos-rota.mjs [id-do-caso]
import { readFileSync } from 'node:fs';

const ler = (p) => JSON.parse(readFileSync(new URL(p, import.meta.url), 'utf8'));
const meta = ler('../data/gerado/meta.json');
const linhas = new Set(ler('../data/gerado/linhas.json').map((l) => l.numero));
const casos = ler('../data/casos_rota.json').filter((c) => !process.argv[2] || c.id === process.argv[2]);

const DIAS = ['dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sab'];
// Próxima data (a partir de hoje, horário de Palmas, UTC-3) que cai no dia da semana pedido.
function proximaData(dia, hora) {
  const agora = new Date(Date.now() - 3 * 3600_000);
  const d = new Date(agora);
  const p2 = (n) => String(n).padStart(2, '0');
  const passou = `${p2(agora.getUTCHours())}:${p2(agora.getUTCMinutes())}` >= hora;
  if (DIAS[d.getUTCDay()] === dia && passou) d.setUTCDate(d.getUTCDate() + 1);
  while (DIAS[d.getUTCDay()] !== dia) d.setUTCDate(d.getUTCDate() + 1);
  const p = (n) => String(n).padStart(2, '0');
  return { otp: `${p(d.getUTCMonth() + 1)}-${p(d.getUTCDate())}-${d.getUTCFullYear()}`, br: `${p(d.getUTCDate())}/${p(d.getUTCMonth() + 1)}` };
}

const min = (s) => Math.round(s / 60);
function resumo(it) {
  const partes = it.legs.map((l) => (l.mode === 'WALK' ? `a pé ${min(l.duration)}` : l.routeShortName ?? '?'));
  return `${partes.join(' › ')}  |  ${min(it.duration)} min, ${it.transfers} troca(s)`;
}

let falhas = 0, avisos = 0;
for (const c of casos) {
  const data = proximaData(c.quando.dia, c.quando.hora);
  const url = `${meta.otpUri}/otp/routers/default/plan?` + new URLSearchParams({
    fromPlace: `${c.origem.lat},${c.origem.lng}`, toPlace: `${c.destino.lat},${c.destino.lng}`,
    date: data.otp, time: c.quando.hora, mode: 'TRANSIT,WALK', numItineraries: '5', maxWalkDistance: '1500',
  });
  console.log(`\n# ${c.id}: ${c.nome}  (${c.quando.dia} ${data.br} ${c.quando.hora})`);
  let plano;
  try { const r = await fetch(url, { headers: { 'User-Agent': 'BusaoPalmas/0.1 (comunidade Devs Tocantins)' } }); plano = await r.json(); }
  catch (e) { console.log(`  FALHA: ${e.message}`); falhas++; continue; }

  const its = plano.plan?.itineraries ?? [];
  if (!its.length) {
    const msg = plano.error?.msg ?? 'sem itinerários';
    if (c.semRotaOk) console.log(`  sem rota (conhecido): ${msg}${c.nota ? `\n  nota: ${c.nota}` : ''}`);
    else { console.log(`  FALHA: sem rota — ${msg}`); falhas++; }
    continue;
  }
  its.forEach((it, i) => console.log(`  ${i + 1}. ${resumo(it)}`));
  if (c.semRotaOk) { console.log('  aviso: este caso era "sem rota" e agora tem rota; revise a nota e o caso'); avisos++; }

  const problemas = [], alertas = [];
  const desconhecidas = new Set(its.flatMap((it) => it.legs.filter((l) => l.mode === 'BUS' && !linhas.has(l.routeShortName)).map((l) => l.routeShortName)));
  if (desconhecidas.size) problemas.push(`linha(s) fora dos nossos dados: ${[...desconhecidas].join(', ')}`);
  if (its.some((it) => it.legs.some((l) => l.mode === 'BUS' && !l.legGeometry?.points))) problemas.push('trecho de ônibus sem traçado');
  const melhor = its[0], andar = melhor.legs.filter((l) => l.mode === 'WALK').reduce((s, l) => s + l.distance, 0);
  if (andar > 2500) alertas.push(`melhor opção manda andar ${Math.round(andar)} m`);
  if (melhor.duration > 150 * 60) alertas.push(`melhor opção leva ${min(melhor.duration)} min`);
  if (melhor.transfers > 2) alertas.push(`melhor opção tem ${melhor.transfers} trocas`);

  if (c.esperado?.linhas && !its.some((it) => c.esperado.linhas.every((n) => it.legs.some((l) => l.routeShortName === n))))
    problemas.push(`esperava uma opção usando as linhas ${c.esperado.linhas.join(' e ')}`);
  if (c.esperado?.maxMinutos && min(melhor.duration) > c.esperado.maxMinutos) problemas.push(`melhor opção passa de ${c.esperado.maxMinutos} min`);

  problemas.forEach((p) => console.log(`  FALHA: ${p}`)); alertas.forEach((a) => console.log(`  aviso: ${a}`));
  falhas += problemas.length; avisos += alertas.length;
}
console.log(`\n${casos.length} caso(s), ${falhas} falha(s), ${avisos} aviso(s)`);
process.exit(falhas ? 1 : 0);
