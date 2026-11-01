import { assert, assertEquals } from 'jsr:@std/assert@1';
import { CORPUS, CORPUS_VERSION } from '../ai-ask/corpus.ts';

Deno.test('corpus : références bien formées et uniques', () => {
  const vues = new Set<string>();
  for (const r of CORPUS) {
    assert(/^(C\. trav\., art\. [LRD]\d{4}(-\d+){1,2}|CGI, art\. \d+ \w+ \w)$/.test(r.ref), `référence mal formée : ${r.ref}`);
    assert(!vues.has(r.ref), `doublon : ${r.ref}`);
    vues.add(r.ref);
    assert(r.objet.length > 10);
  }
  assert(/^ctrav-\d{4}-\d{2}\.\d+$/.test(CORPUS_VERSION));
});

// En production, le déploiement exige un corpus entièrement vérifié.
Deno.test({
  name: 'corpus : vérifié par un juriste (exigé en production)',
  ignore: Deno.env.get('UNIION_ENV') !== 'production',
  fn: () => assertEquals(CORPUS.filter((r) => !r.verifie_le).map((r) => r.ref), []),
});
