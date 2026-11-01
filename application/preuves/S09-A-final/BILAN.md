# S09 — lot A : contrats et persistance serveur

31 octobre 2026. **Lot A techniquement terminé dans le périmètre serveur de recette fictive ; S09 reste ouvert.** Le raccordement des écrans relève du lot B, il n’est pas présenté comme réalisé.

## Réalisé

A1 et A2 sont conservés : réunions natives, attestation versionnée, audio immuable dans le coffre privé, droits audio distincts, contrôle de format/antivirus, quarantaine et rejeu idempotent. Cette finalisation ajoute les marqueurs propres à chaque prise, qui figuraient dans le périmètre initial A mais n’avaient pas été livrés dans A2. Leur report provisoire à B dans le précédent bilan est ainsi levé.

Migration additive 167 installée en local : durée attestée à partir des octets WAV vérifiés et révisions privées des marqueurs. Les temps sont bornés par la durée serveur ; les types correspondent aux sept catégories du prototype. Notes et identifiants sont strictement validés. Une nouvelle révision conserve les précédentes ; aucune suppression physique.

Les marqueurs héritent des restrictions de l’audio et du consentement. La lecture et l’écriture sont séparées. Les versions et le verrou de réunion empêchent les écrasements concurrents. Modifier un marqueur ne modifie pas l’attestation ; les futurs dérivés devront référencer la révision de marqueurs. Aucun transfert automatique vers le PV ou l’IA n’élargit les accès.

## Vérifications exécutées

| Vérification | Résultat |
| --- | --- |
| Intégration A1, nouvelle exécution | 34 contrôles réussis |
| Intégration A2, nouvelle exécution avec durée | 56 contrôles réussis |
| Marqueurs, exécution finale | 60 contrôles réussis, dont deux écritures concurrentes : un seul succès |
| Total des trois suites | 150 contrôles, `acceptance.json` |
| Tests Python | 287 réussis, `python-tests.log` |
| Frontières des modules | OK, `boundaries.log` |
| Références/frontend/anciennes preuves | Toutes les empreintes inchangées, `integrite-apres.json` |

La recette marqueurs vérifie sauvegarde/relecture, redémarrage application/session, conservation des anciennes versions, bornes, doublons, types/champs injectés, version périmée, durée falsifiée, accès lecture seule, autre réunion/organisation, retrait du consentement, audit sans notes et concurrence réelle de deux RPC. Les 60 contrôles incluent la préparation Auth/Storage de leur réunion fictive ; ce ne sont pas 60 parcours UI.

Les suites historiques ont été rejouées vers de nouveaux dossiers `a1/`, `a2/`, `markers/`, sans écraser les anciennes preuves. La suite marqueurs a été rejouée après ajout du contrôle concurrent ; son `integration.json` à 60 contrôles est le résultat final, le premier `run.log` en contient 58. Aucune nouvelle preuve historique n’est extrapolée.

## Limites et fidélité

Aucun fichier frontend ou design modifié. Pas de test micro ni appareil physique ; les sources sont des fichiers audio synthétiques. Même profil initial WAV PCM ≤ 5 Mio, 20 prises par réunion. L’attestation reste celle de l’opérateur ; pas de preuve individuelle de consentement. Les anciennes prises A2 doivent rejouer leur dépôt vérifié pour obtenir une durée avant d’utiliser les marqueurs.

La restauration depuis sauvegarde, les transferts segmentés, les formats navigateur, les jobs de transcription et la chaîne PV ne font pas partie de cette clôture serveur A. Les réserves antivirus A2 sont conservées. Aucun déploiement, envoi externe, donnée réelle ni purge.

## Reste à faire

Voir [le reste à faire détaillé](RESTE-A-FAIRE.md) : B capture/import/lecture, C transcription durable, D PV et validation, E conservation/restauration, F recette complète. Prochaine tranche concrète : parcours d’import fictif vers stockage serveur dans les écrans existants.
