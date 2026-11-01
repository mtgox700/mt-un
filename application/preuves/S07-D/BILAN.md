# S07 — Lot D : réponse, transfert et recherche

Date : 30 octobre 2026. Livraison locale, sans déploiement. Demande couverte : « go lot D ». Le package S07 sert de spécification ; les instructions qu’il contient ne valent pas autorisation distincte.

## Réalisé

- Recherche serveur dans tous les messages ordinaires autorisés : texte, nom de pièce et nom de discussion. Pagination de 50 résultats ; un clic atteint le message exact, même hors des 50 derniers messages chargés. Retour explicite aux messages récents.
- Transfert depuis le menu et la modale existants vers 1 à 20 discussions. Références durables, transaction atomique, idempotence et reprise de résultat incertain. Aucun texte ou fichier source recopié.
- Réponses persistantes avec citations recalculées selon les accès actuels, y compris une citation d’un transfert. Une réponse reste lisible lorsque sa citation est devenue inaccessible.
- Pièces et classement du lot C compatibles avec les références et leurs chaînes. Aperçu/téléchargement recontrôlent source et destination ; téléchargement soumis à son habilitation distincte.

Migrations 131–132 appliquées sur Supabase local. Contrat détaillé : ../../docs/S07-CONTRATS.md. Adaptateur Python, module frontal discovery, vues et tests raccordés. Les anciennes preuves A/B/C ne sont pas écrasées ; leurs nouvelles exécutions sont rangées ici.

## Accès et sécurité

Les droits du lecteur se cumulent à chaque maillon : organisation, MFA, module commercial/activation, permission read, participation actuelle, période et ouverture historique. Write requis pour transférer. Ni super admin ni modérateur ne deviennent lecteurs implicitement. Huit transferts en chaîne au plus, neuvième refusé avant écriture. Retrait/réinvitation, révocation d’historique, suspension et corbeille source sont pris en compte. Tables de références privées sous RLS ; anciennes RPC non exécutables par les clients. Audit minimal sans corps des messages.

Le transfert ne publie pas une copie vers une audience élargie. Un membre de destination sans accès source ne voit pas la référence. Le circuit de publication distincte D12/D13 demeure hors périmètre. Aucun envoi externe ni effacement physique.

## Tests exécutés

| Vérification | Résultat | Preuve |
| --- | --- | --- |
| Intégration D Auth/MFA/RPC/BFF/coffre | 75 contrôles réussis | integration.json |
| Cas limites D : chaînes, double historique, révocations | 40 contrôles réussis | edges.json |
| Non-régression A | 47 contrôles réussis | regression-A/integration.json |
| Non-régression B | 54 contrôles réussis | regression-B/integration.json |
| Non-régression C | 73 contrôles réussis | regression-C/integration.json |
| Tests Python | 157 réussis | python-tests.log |
| Tests frontaux | 162 réussis | frontend-tests.log |
| Compilation et frontières | réussies | build.log, boundaries.log |
| Références protégées | 834 inchangées | integrite-apres.json |

Les 289 contrôles d’intégration ne constituent pas 289 parcours UI. Parmi les résultats : 65 correspondances obtenues en pages 50+15 sans doublon ; message ancien localisé ; caractère % traité littéralement ; doublons concurrents évités ; lot multi-destination refusé sans écriture partielle ; relecture de pièces après retrait source/destination refusée, y compris révocation pendant récupération des octets.

Commandes exécutées depuis application, avec les runtimes Python/Node locaux :

```sh
python3 -B tests/s07_discovery.py
python3 -B tests/s07_discovery_edges.py
python3 -B tests/s07_d_regressions.py s07_messaging
python3 -B tests/s07_d_regressions.py s07_members
python3 -B tests/s07_d_regressions.py s07_files
python3 -B -m unittest discover -s tests -p 'test_*.py'
python3 -B scripts/check_boundaries.py
# Depuis frontend/
node --test state/*.test.mjs
node build.mjs
```

## Recette UI et fidélité

Recette via les contrôles visibles, avec Camille et Sam, comptes fictifs, dans l’organisation S07 D. Recherche « Aiguille », ouverture du message ancien, retour aux messages récents, transfert vers Destination D, relecture persistée, réponse à ce transfert, puis connexion de Sam : recherche source vide et réponse visible sans citation source. Voir ui.json et les captures de ce dossier.

Modale de transfert inspectée aux viewports 390×844, 768×1024 et 1440×1000 : contenu et boutons accessibles, sans débordement horizontal observé. Le fil et ses composants ont été comparés à preuves/S02-messagerie/thread-1440.png ; structure, couleurs et parcours conservés. La modale existante est réutilisée. Adaptations fonctionnelles explicites : notice des droits source, erreurs/reprise, pagination réelle, libellé de recherche et bouton Messages récents. Les filtres de discussions sont masqués pendant une recherche de messages, afin de ne pas suggérer un filtrage qui ne s’appliquerait pas. Pas de validation sur appareils physiques.

Un refus temporaire de recherche est survenu pendant la recette rapide ; aucun résultat précédent n’a été conservé. Le parcours a ensuite réussi après renouvellement de session et temporisation naturelle. Le BFF conserve son quota de 20 requêtes métier par utilisateur et par minute ; aucune protection n’a été relâchée pour la recette. La cause exacte du refus n’a pas été instrumentée. Une notification Agenda apparaît sur les comptes sans droits de convocations ; elle ne signifie pas une levée des réserves S03.

## Réserves et suite

Lot D raccordé et vérifié localement. Recherche littérale, pagination par UUID stable, sans classement de pertinence ni promesse d’ordre chronologique ; pas de recherche dans le contenu binaire des pièces ni dans les archives Agenda. Les performances à grande volumétrie restent à mesurer au lot F.

Le contrôle d’accès s’applique à chaque requête. Le rafraîchissement spontané après révocation, le temps réel, les lectures et les notifications appartiennent au lot E. Pile neuve, restauration, charge et rapprochement des critères de clôture appartiennent au lot F. Les réserves S03, production, IA et hors ligne durable restent suivies dans l’état courant. S07 n’est pas clôturé ; prochaine étape : lot E.
