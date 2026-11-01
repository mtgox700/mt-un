# S08 — consolidation finale A–F

31 octobre 2026. **Consolidation technique terminée pour la recette locale fictive ; clôture locale S08 proposée à l’utilisateur.** L’acceptation produit n’est pas présumée. Le lot E est finalisé dans ce périmètre. À la demande de l’utilisateur, les décisions de production sont reportées au dernier sprint, S16, avant tout pilote réel, donnée réelle ou déploiement.

## Livré

Le socle IA, les contextes autorisés, les exécutions persistantes, la conversation libre, les dossiers privés dérivés, les 37 actions métier et les sept générateurs spécialisés sont raccordés. Le catalogue est configuré côté serveur, avec versions, permissions et rôles. Les brouillons et copies de publication locale suivent les contrôles D12/D13 ; aucune diffusion externe n’est activée. Voir [le bilan E complet](../S08-E-complet/BILAN.md) et [les contrats consolidés](../../docs/S08-CONTRATS.md).

Cette consolidation corrige les parcours visibles du document spécialisé et du PV : le document généré ouvre son éditeur serveur ; le projet de PV enregistré est consultable et son accès suit les données autorisées courantes. Le bouton PV cible également la réunion réellement affichée lorsque l’identifiant de route est ancien. Les retours tardifs après navigation et doubles clics de préparation sont neutralisés.

L’aperçu Intranet ne mélange plus le contenu natif avec une date, un contact ou une durée de lecture inventés par le prototype. Le chapô des nouvelles générations reprend le premier paragraphe ; celui de la page de recette antérieure a été corrigé et sa version 3 relue. Les libellés distinguent propositions, brouillons, droits effectifs et fonctions non connectées. Les structures et styles de référence sont conservés.

## Résultats exécutés

| Vérification | Résultat | Preuve |
| --- | --- | --- |
| Python | 275 tests réussis | [journal](python-tests.log) |
| Frontend, état et contrat hôte | 237 tests réussis | [journal](frontend-tests.log) |
| Compilation / frontières | Réussies | [build](build.log), [frontières](boundaries.log) |
| Intégration transverse actuelle | 331 contrôles réussis, sept suites | [résultat](integration-consolidee.json) |
| Restauration isolée actuelle | 382 contrôles SQL/fichiers et 22 contrôles IA réussis | [acceptation](restore/acceptance.json), [journal](restore.log) |
| Installation neuve | Preuve E de 56 contrôles reconduite : 158 fichiers SQL strictement identiques | [comparaison](installation-neuve-reconduite.json) |
| Codex réel | Qualification E de 37 actions + 7 générateurs conservée ; parcours réels supplémentaires ci-dessous | [qualification E](../S08-E-complet/qualification-metier.json) |
| Intégrité et recherche de secrets connus | Voir résultat final, sans modification des anciennes preuves | [contrôle](integrite-apres.json) |

Les tests déterministes d’intégration prouvent les invariants et refus, pas la qualité du modèle. Les générations réelles E et les parcours UI complètent cette couverture. La pile neuve n’a pas été recréée dans F final : sa preuve est reconduite par comparaison exacte du SQL. Les nombres de tests, contrôles et générations ne s’additionnent pas en un nombre de parcours.

## Matrice d’acceptation locale

| Lot | Critère | Couverture finale |
| --- | --- | --- |
| A | Passerelle, configuration et refus | 18 contrôles de politique ; tests Python ; refus d’auto-attribution dans l’UI |
| B | Contextes et isolation | 47 contrôles ; sources natives E ; accès interorganisation et permissions revérifiés |
| C | Exécutions, annulation, reprise, persistance | 29 contrôles ; restauration IA ; tests de navigation et de concurrence frontend |
| D | Assistant et historique privé | 33 contrôles ; dossier depuis réponse/message ; mémoire et dépendances couvertes |
| E | Actions, générateurs, brouillons et diffusion locale | 30 + 140 + 34 contrôles ; qualification réelle 44 sorties E ; parcours complémentaires F |
| F | Non-régression, restauration, fidélité et transmission | Suites ci-dessus, captures et archive consolidée vérifiée |

## Recette visuelle

Parcours complémentaires réellement actionnés : message sélectionné → génération → dossier privé ; refus d’auto-attribution de rôle ; brief document → Codex → document enregistré et ouvert ; brief Intranet → Codex → page enregistrée, aperçu corrigé et chapô relu après retour ; question de sondage → deux options Codex ; consultation du projet de PV persistant. Voir [la matrice détaillée](RECETTE-UI.md).

Captures supplémentaires bureau 1440×1000, PV mobile 360×800 et tablette 1024×768. Le panneau est lisible et défilable ; les commandes restent accessibles. Les preuves E en 390×844 et 768×1024 restent conservées. Il ne s’agit pas d’une recette exhaustive de tous les écrans des futurs modules. Les thèmes, barres et navigation de référence sont maintenus ; seules les informations trompeuses et les raccordements ont été corrigés. La validation esthétique finale appartient à l’utilisateur.

## Réserves et transmission

[Le registre des réserves](RESERVES.md) distingue les limites opérationnelles locales, les fonctionnalités des sprints suivants et les décisions explicitement différées à S16. Aucune limite n’est considérée résolue par ce report.

L’archive `planification/UNIION-S08-CLOTURE-LOCALE.zip` réunit les sources actuelles, migrations, tests, scripts, documentation et preuves S08. Le manifeste donne leurs empreintes. Elle exclut les comptes, clés, sessions, registres privés et sauvegardes. Elle est un dossier de transmission technique, pas un déploiement autonome ; dépendances, services et secrets locaux doivent être préparés séparément.

**État final : consolidation F terminée, lot E finalisé localement, S08 techniquement clôturable dans le périmètre fictif autorisé. Aucun blocage technique restant constaté dans cette recette ; acceptation produit distincte et production non autorisée.**
