// Confere se data/gerado/ segue o contrato de docs/DADOS.md. Sai com erro se algo estiver quebrado.
import { readFileSync } from 'node:fs';

const ler = (n) => JSON.parse(readFileSync(new URL(`../data/gerado/${n}.json`, import.meta.url), 'utf8'));
const meta = ler('meta'), linhas = ler('linhas'), horarios = ler('horarios'), trajetos = ler('trajetos'), paradas = ler('paradas'), busca = ler('busca');
const erros = [];
const exige = (ok, msg) => { if (!ok) erros.push(msg); };

exige(meta.versao === 1, 'meta.versao diferente de 1');
exige(meta.projetoId === 635, 'meta.projetoId não é 635');
exige(Object.entries(meta.contagens).every(([k, v]) => ({ linhas, viagens: Object.keys(trajetos), paradas, busca })[k].length === v), 'meta.contagens não confere com os arquivos');

const idsLinha = new Set(linhas.map((l) => l.id));
const idsParada = new Set(paradas.map((p) => p.id));
const hora = /^\d{2}:\d{2}$/;

for (const l of linhas) {
  exige(/^#[0-9A-Fa-f]{6}$/.test(l.cor) && /^#[0-9A-Fa-f]{6}$/.test(l.corTexto), `linha ${l.numero}: cor inválida`);
  exige(l.sentidos.length > 0, `linha ${l.numero}: sem sentidos`);
  exige(horarios[l.id]?.length > 0, `linha ${l.numero}: sem horários`);
}

const chaves = new Set();
for (const [id, t] of Object.entries(trajetos)) {
  exige(idsLinha.has(t.linha), `viagem ${id}: linha inexistente`);
  exige(t.paradas.length >= 1, `viagem ${id}: sem paradas`);
  for (const s of t.paradas) exige(idsParada.has(s), `viagem ${id}: parada ${s} inexistente`);
  const k = `${t.linha}/${t.sentido}/${t.seq}`;
  exige(!chaves.has(k), `viagem ${id}: (linha, sentido, seq) repetido ${k}`);
  chaves.add(k);
}

for (const l of linhas) for (const d of horarios[l.id] ?? []) for (const s of d.servicos) {
  exige(s.dias.length === 7, `linha ${l.numero}: 'dias' não tem 7 posições`);
  for (const [dep, arr, seq] of s.saidas) {
    exige(hora.test(dep) && hora.test(arr), `linha ${l.numero}: hora inválida ${dep}/${arr}`);
    exige(chaves.has(`${l.id}/${d.sentido}/${seq}`), `linha ${l.numero}: saída ${dep} sem viagem (sentido ${d.sentido}, seq ${seq})`);
  }
}

for (const p of paradas) {
  exige(p.lat < -9.9 && p.lat > -10.6 && p.lng < -47.7 && p.lng > -48.7, `parada ${p.id}: fora de Palmas`);
  exige(p.nome && p.linhas.length > 0, `parada ${p.id}: sem nome ou sem linhas`);
}
exige(busca.every((i) => i.n && i.k && Number.isFinite(i.la) && Number.isFinite(i.lo)), 'busca: item incompleto');

if (erros.length) { console.error(`${erros.length} problema(s):\n- ` + erros.slice(0, 30).join('\n- ')); process.exit(1); }
console.log(`OK: ${linhas.length} linhas, ${Object.keys(trajetos).length} viagens, ${paradas.length} paradas, ${busca.length} itens de busca`);
