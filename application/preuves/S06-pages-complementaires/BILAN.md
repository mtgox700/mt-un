# S06 — Pages complémentaires des documents

30 octobre 2026 — décision utilisateur : « Ajouter des pages complémentaires avec la même charte ». Skill uniion appliqué, travail limité à l’application locale.

## Réalisé

Le même plan de pages est désormais utilisé par l’aperçu et le PDF serveur. La page graphique conserve sa composition. Les blocs absents ou partiellement repris sont ajoutés après elle, dans l’ordre du document, avec la charte de l’organisation : logo, couleurs, polices, en-tête et pied de page selon les options du document.

Les textes simples sont regroupés pour éviter une page par petit bloc. Les longs paragraphes sont répartis sans troncature. Les tableaux et blocs d’extension restent entiers et bénéficient du contrôle de débordement. Les occurrences répétées d’un même texte sont comptées ; une seule occurrence rendue ne couvre pas deux blocs sources.

Un bloc partiellement repris peut apparaître partiellement sur la première page puis intégralement dans le complément : cette répétition conserve la première composition et évite toute omission. Aucun contenu source n’est réécrit. Les sauts de page explicites sont conservés. Les droits de lecture, téléchargement et publication sont inchangés.

## Tests

- 146 tests Python et 117 tests frontaux réussis ; compilation et contrôle des frontières réussis.
- 32 contrôles réels du cycle Documents et des accès autorisés/refusés réussis sur Supabase local.
- Matrice de 12 styles × 3 formats : 23 exports réussis, contre 15 avant cette correction ; les 8 anciens cas d’omission passent désormais avec les compléments. Les 13 cas de débordement de la composition graphique restent refusés.
- Trois documents multipages supplémentaires en A4, A5 et paysage : texte long, image et bloc d’extension conservés.
- Première page du témoin Affiche choc A4 identique pixel pour pixel au PDF de référence S03. La page complémentaire a été rendue puis inspectée.
- Aperçu et téléchargement testés dans l’interface en 1440 × 1000, 768 × 1024 et 390 × 844. Les trois téléchargements sont identiques, comportent deux pages et contiennent le complément attendu en page 2. Il s’agit de viewports, pas d’appareils physiques.
- 834 empreintes de référence inchangées : prototype et S00 préservés.

## Limites et clôture

L’ajout de compléments règle les blocs non repris. Il ne redimensionne pas les premières pages graphiques trop chargées et ne découpe pas arbitrairement un tableau ou une extension trop grande. Ces cas restent bloqués par le contrôle géométrique ; aucune perte silencieuse n’est acceptée.

S06 n’est pas encore déclaré clôturé : il reste le traitement des débordements de première page et l’arbitrage séparé sur la déconnexion avec un brouillon non sauvegardé. Cette dernière adaptation n’a pas été incluse dans l’accord sur les pages complémentaires.

## Preuves

- `matrix.json` : résultats des 36 combinaisons.
- `first-page-comparison.json` : comparaison pixel de la page témoin.
- `browser-exports.json` : nombre de pages, contenu et empreintes des téléchargements.
- `integration.json`, `frontend-tests.log`, `unit-tests.log` : résultats techniques.
- `desktop-apercu.png`, `tablette-apercu.png`, `mobile-apercu.png` : captures de la recette.
