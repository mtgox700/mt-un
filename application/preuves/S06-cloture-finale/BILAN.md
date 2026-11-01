# S06 — Clôture technique locale

30 octobre 2026 — skill uniion-developpement appliqué. Périmètre : Documents et exports. **S06 peut être clôturé en local**, avec validation visuelle finale par le porteur du projet. Aucun déploiement ni fournisseur externe activé.

## Réserves levées

Les 13 échecs de première page du témoin précédent sont corrigés. La typographie des gabarits paysage tient compte de la hauteur disponible ; les titres de Sérigraphie et de l’Affiche rétro restent dans leur cadre. Couleurs, polices, compositions et commandes sont conservées. Les trois compositions paysage spécifiques déjà validées restent inchangées. Les blocs non repris continuent sur les pages complémentaires avec la même charte, selon un plan partagé entre aperçu et export.

Une déconnexion avec un brouillon non confirmé ouvre la modale existante : enregistrer puis se déconnecter, quitter explicitement sans réessayer, ou annuler. La sauvegarde doit réussir avant la fermeture de session. Un échec laisse la session ouverte et propose de réessayer ou de choisir explicitement l’abandon. Aucun brouillon métier n’est ajouté au stockage persistant du navigateur. Une requête déjà envoyée peut aboutir : l’interface le précise, l’abandon n’est pas présenté comme une annulation de transaction serveur.

## Vérifications du lot

| Vérification | Résultat et preuve |
| --- | --- |
| 12 styles × A4/A5/16:9 | 36/36 exports réussis, matrix.json et PDF conservés |
| Compléments texte long, image et extension | 3 formats réussis, contenu final présent, render.log |
| Titres volontairement excessifs | 11 refus sûrs ; 1 export Journal paysage intégral, les 60 occurrences sont présentes et sa page a été inspectée (oversized.json) |
| Serveur | 146 tests réussis, unit-tests.log |
| Frontal | 122 tests réussis dont 5 de protection de déconnexion, frontend-tests.log |
| Accès et cycle documentaire Supabase local | 32 contrôles réussis, integration.json / integration-run.log |
| Compilation et frontières | Compilation réussie ; frontières des modules et 14 migrations de référence vérifiées |
| Interface | Mobile 390×844, tablette 768×1024, desktop 1440×1000 ; aperçu, export et confirmation lisibles |
| Sauvegarde avant déconnexion | Exécutée sur mobile ; reconnexion MFA et titre rechargé depuis le serveur |
| Abandon explicite | Exécuté sur desktop ; reconnexion MFA, titre non envoyé absent et titre serveur conservé |
| Annulation | Desktop et tablette : session et saisie conservées |
| Téléchargements réels | Même SHA-256 sur les trois viewports, 2 pages et contenu complémentaire présents (downloads.json) |
| Références protégées | 834 empreintes identiques, integrity.json |

Les essais sont des émulations de taille dans le navigateur local, pas une certification sur téléphones ou tablettes physiques. Les erreurs de sauvegarde, doubles confirmations et changements d’identité pendant une sauvegarde sont couverts par les tests unitaires du service de déconnexion. Les droits sont vérifiés côté serveur, indépendamment de la taille d’écran.

## Clôture du périmètre roadmap

Éditeur, blocs, modèles, charte et logos persistants ; aperçu/pagination communs au rendu ; PDF réels et travaux durables ; contrôle d’accès à la lecture, export et archives ; corrections, validation par version avec second acteur, diffusion interne aux destinataires déjà habilités ; archives, corbeille approuvée et restauration : couverts par les lots S06 et leurs recettes. Les contrats des extensions et de la signature optionnelle sont décrits dans docs/S06-CONTRATS.md.

Les preuves antérieures de S06-finalisation restent applicables : reprise du worker (10 contrôles), restauration isolée (312 contrôles), puis Auth/MFA/droits après restauration (15 contrôles). Elles n’ont pas été rejouées dans ce lot, qui ne modifie ni schéma ni stockage serveur. Les anciens bilans sont conservés ; celui-ci lève les deux réserves du bilan S06-pages-complementaires.

## Limites et suite

Un bloc atomique ou une composition dépassant réellement le cadre peut toujours être refusé ; aucun export tronqué n’est annoncé comme réussi. La matrice valide les contenus témoins, pas toute longueur imaginable. Les exports proposés sont PDF A4/A5/16:9 ; aucun Word/Excel n’est prétendu disponible.

La signature électronique optionnelle reste à brancher dans son module dédié ; l’IA commune relève de S08, la messagerie complète de S07, le hors ligne durable de S13. OVH, Supabase managé, appareils physiques, qualification sécurité/charge indépendante et recette d’exploitation restent des étapes ultérieures. Ces dépendances ne sont pas présentées comme réalisées par la clôture locale de S06.

Prochaine étape roadmap : **S07 — Messagerie et collaboration**, selon son périmètre prévu, sans lancement dans ce lot.
