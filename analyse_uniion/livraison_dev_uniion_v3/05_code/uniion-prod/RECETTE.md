# Recette — état de couverture

Critères : `design_handoff_uniion/RECETTE.md` §1. Un module n'est livrable que si tous ses critères passent.
**Auto** = test exécuté en CI · **Manuel** = manipulation à faire en recette, résultat consigné ici · **Lot 6** = module non livré.

| # | Critère (résumé) | Couverture | Où |
|---|---|---|---|
| 1 | Pas d'accès sans second facteur quand imposé | Auto + Manuel | `app.exiger` (aal2) — `lot3.test.sql` ; parcours d'enrôlement à faire |
| 2 | Militant sur route trésorier → refus journalisé | Auto (refus) · **à compléter** (journal du refus) | `lot3b.test.sql` trésorerie |
| 3 | Mandat échu : sessions coupées sous 24 h | Auto (désactivation) + Manuel (reconnexion) | `app.fin_de_mandat` horaire ; Edge `membres` |
| 4 | Après déconnexion, aucun dossier lisible localement | Manuel | PWA sans cache métier ; vérifier DevTools › Application |
| 5 | Dossier de A invisible pour B (réponse serveur) | Auto | `cloisonnement.test.sql`, `lot3.test.sql` |
| 6 | Déplacement de carte persistant | Manuel | |
| 7 | Pièce téléchargeable après antivirus ; admin hors dossier → 404 | Auto (RLS) + Manuel (ClamAV avec EICAR) | Edge `pieces` |
| 8 | Modification concurrente → 409, pas d'écrasement | Auto (version) + Manuel (écran) | `lot3.test.sql` |
| 9 | 50 textes piégés → 0 fuite | Auto — **61 cas** | `_shared/masque.test.ts` |
| 10 | Question méta refusée sans appel ni quota | Auto | `masque.test.ts` (`estQuestionMeta`) |
| 11 | Réponse stockée avec `prompt_version` | Auto (schéma) | `requete_ia.prompt_version`, `corpus_version` |
| 12 | Journal sans texte de question ni réponse | Auto (schéma) + Manuel (recherche de motifs dans les journaux de recette) | |
| 13 | Quota → 429, aucune réponse simulée | Manuel | Edge `ai-ask` |
| 14 | Import 2 000 lignes dont 37 invalides | Auto (petit volume) · **Manuel à 2 000 lignes** | `lot3.test.sql` ; fichier à générer |
| 15 | Liste dynamique recalculée | Auto (recalcul à l'envoi) | `api.liste_effectif` |
| 16 | Communication envoie sans voir les membres | Auto (aucune fonction ne renvoie de nom) + Manuel | `api.campagne_envoyer` |
| 17 | Toute lecture nominative journalisée | Auto | `fonctions.test.sql`, `lot3b.test.sql` |
| 18 | Événement « bureau » absent pour non-habilité | Auto | `lot3.test.sql` |
| 19 | Récurrence : modifier une occurrence | **Non livré** (pas de récurrence au lot 3) | |
| 20 | Export ICS d'un mandat révoqué inactif sous 24 h | Sans objet : l'ICS est généré sur l'appareil, pas d'abonnement | à retenir si un flux ICS est ajouté |
| 21 | HTML assaini | Lot 6 (intranet) | |
| 22 | Pas de publication sans relecture par un pair | Auto | `lot3b.test.sql`, migration 14 |
| 23 | Chartes intranet / public indépendantes | Lot 6 | |
| 24 | Aucun agrégat < 5 personnes | Auto | `fonctions.test.sql` ; `api.liste_effectif` |
| 25 | Bilan de mandat sans donnée nominative | Lot 6 (reporting) | |
| 26–30 | Accessibilité (clavier, focus, live, contraste, zoom 200 %) | Manuel | audit RGAA à faire sur les 13 écrans |

## Scénarios de bout en bout (RECETTE §2)

| # | État |
|---|---|
| E1 | Faisable sans « courrier signé » (signature eIDAS au lot 6) |
| E2 | Faisable de bout en bout |
| E3, E4 | Lot 6 (réunions, intranet) |
| E5 | Faisable (fin de mandat, réattribution, purge du cache) |
| E6 | Sans objet : pas d'édition hors ligne (choix de sécurité, DECISIONS.md) |

## Restauration (EXPLOITATION §3)

| Cas | Outil | Dernier passage |
|---|---|---|
| Restauration complète | `infra/restore-test.sh` (trimestriel, compte rendu signé) | — |
| Une seule organisation | manuel : `pg_restore` dans le conteneur jetable puis export filtré par `organisation_id` | — |
| Dossier supprimé < 30 jours | manuel : corbeille applicative, sinon instantané horaire | — |

## Performance (RECETTE §3)

À mesurer en recette avec `seed` volumineux (200 dossiers, 2 000 adhérents, 300 événements). Seul le poids initial est contrôlé en CI (garde-fou de build).
