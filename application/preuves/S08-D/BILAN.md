# S08 — lot D : Assistant, historique et mémoire

30 octobre 2026. **Lot D livré dans le périmètre de recette locale fictive autorisé. S08 reste ouvert.** Skill uniion-développement appliqué. Aucun déploiement ni transfert de données métier réelles.

## Résultat

L'écran Assistant utilise les sources certifiées B et les exécutions/quotas C. Une synthèse extractive fictive est enregistrée avec son état réussi, relue avec contrôle de toutes ses sources et affichée avec citations. Chaque demande est une entrée d'historique privée ; aucune conversation juridique libre multi-tours n'est revendiquée dans cette recette.

« Mémoriser » retient la réponse pour le compte et l'organisation courants. La mémoire est initialement suspendue ; son activation est explicite. Elle réutilise les références des sources, après relecture, plutôt que le texte d'une ancienne réponse. Une source modifiée ou révoquée bloque leur réutilisation ; la suspension globale permet de repartir sans mémoire. Aucun fait libre, corpus navigateur ou résultat forgé n'est accepté comme autorité.

Historique et mémoire sont persistants et chiffrés sur le serveur. Le parcours réel a été vérifié : génération Codex, mémorisation, activation, redémarrage du serveur, nouvelle connexion/MFA, réouverture de l'historique, relecture de la réponse et consultation de la mémoire. Les mêmes trois citations et la préférence activée ont été retrouvées.

## Implémentation et droits

Migration locale `ai_history_v2.sql` appliquée au registre : réponses AES-GCM liées par AAD à organisation/acteur/requête, préférences et mutations versionnées. Réponse et état réussi dans une transaction atomique. Pas de modification des migrations Supabase antérieures, pas de clé privilégiée ajoutée, pas de stockage partagé implicite entre comptes.

La clé privée est distincte du fichier de base ; une clé manquante avec du contenu existant provoque un refus, pas une réinitialisation. Le fichier serveur conserve des métadonnées identifiantes en clair sous permissions privées ; le chiffrement du contenu ne protège pas contre l'administrateur de l'hôte détenant la clé.

Liste, relecture et mémorisation recontrôlent les sources avec le JWT courant, leurs versions, la certification fictive et la politique IA. Une réponse devenue inaccessible n'apparaît plus dans la liste ni dans la mémoire retournée. Un changement de mémoire pendant l'inférence interdit la restitution. Un archivage pendant les vérifications de relecture est aussi refusé.

Aucun texte de réponse placé dans l'état local persistant du contrôleur. Les anciennes données IA du navigateur ne sont ni chargées ni envoyées ; elles sont conservées sans usage, sans migration ni suppression implicite. L'archivage serveur masque une demande et désactive son souvenir sans purger son contenu, conformément à la réserve D07.

## Tests observés

| Vérification | Résultat | Preuve |
| --- | --- | --- |
| HTTP, MFA et vrais contrôles Supabase | 35 contrôles réussis | integration.json |
| Codex réel avec trois sources fictives | Réponse persistée puis relue, trois extraits vérifiés | codex-live.json |
| Suite Python finale | 253 tests réussis | python-tests-final.log |
| Historique et mémoire | 20 tests dédiés, inclus dans la suite Python | history-tests-final.log |
| Suite frontale finale | 200 tests réussis | frontend-tests-final.log |
| Compilation et frontières | Réussies | build.log, boundaries-final.log |
| Références et anciennes preuves | Comparaison SHA-256 | integrite-apres.json |

Les tests couvrent notamment l'isolation acteur/organisation, super admin sans lecture métier, requêtes forgées, changement de version, révocation de source/certification, mémoire désactivée ou modifiée pendant l'appel, limite de huit souvenirs, mutations périmées, archivage sans suppression, idempotence après réouverture, chiffrement lié à la ligne, clé perdue, échec atomique d'enregistrement et migration v1→v2.

Une sauvegarde SQLite cohérente copiée avec sa clé privée dans un répertoire temporaire a été relue ; la clé de requête restait non rejouable. Ce test ne constitue pas une restauration globale D07. Les tests frontaux couvrent absence d'envoi de texte libre, relecture avant affichage, absence de réponse dans l'état persistant hérité, retours tardifs après navigation/déconnexion, disparition sur révocation/indisponibilité, mutation mémoire par identifiant/version et conflit sans faux succès.

## Fidélité et recette UI

Comparaison aux références S00 `assistant-desktop.jpg` et `memoire-mobile.jpg`. Navigation, cartes, palette, hiérarchie et disposition de l'Assistant conservées. Les intitulés juridiques et garanties simulées sont remplacés par les capacités réelles de recette fictive. Les actions métier vers les dossiers annoncent leur raccordement au lot E ; aucun dossier n'est créé par cette recette.

Le formulaire de mémoire libre indique désormais le parcours « Mémoriser » depuis une réponse vérifiée. « Relire » et « Désactiver » remplacent l'édition libre et l'oubli destructif. Les interrupteurs exposent leur état réel aux technologies d'assistance.

Une anomalie mobile de la disposition héritée comprimait les souvenirs longs entre l'interrupteur et les actions. La ligne autorise maintenant le retour à la ligne des actions, tout en conservant la disposition bureau. Correction vérifiée sur le contenu réel de recette.

Viewports 1440×1000, 768×1024 et 390×844. Aucun débordement horizontal observé ; largeur utile mobile 382 px, tablette 768 px pour la mémoire sans barre de défilement et 760 px pour l'Assistant avec barre. Défilement de la réponse et accès aux commandes vérifiés. Aucun appareil physique testé.

Captures : assistant-1440.png, assistant-768.png, assistant-apres-redemarrage-390.png, memoire-1440.png, memoire-768.png, memoire-corrigee-390.png. La capture bureau initiale montre le contenu et la disposition ; la correction finale concerne le retour à la ligne mobile et les attributs accessibles.

## Limites et suite

Masquage partiel, citations littérales et sources fictives exclusivement. Pas de qualification juridique, de texte libre transmis, d'import d'ancien historique, ni de mémoire arbitraire. Cinquante demandes récentes listées ; huit souvenirs maximum, avec toutes leurs sources cumulées (huit maximum). Une mémoire devenue inaccessible exige une suspension globale ou une remise en conformité de ses sources pour poursuivre sans refus ; elle n'est pas supprimée silencieusement.

Les revalidations successives ne constituent pas une transaction atomique avec Supabase ou le fournisseur. L'écran se revalide toutes les dix secondes et efface ses contenus sur échec ; aucune révocation instantanée rétroactive d'un contenu déjà vu/transmis n'est promise. Navigation, masquage d'onglet et déconnexion invalident les retours tardifs.

Registre local, pas de qualification multi-hôte. Sauvegarde globale, rotation de clé, restauration périmée et politique complète D07 restent à traiter en F ; la clé privée est indispensable à toute restauration du contenu. Aucun effacement automatique. D09 de production demeure ouvert.

**Prochaine étape : E — actions unii et raccordement des modules.** Le lot F et les arbitrages de production ne sont pas clôturés.

## Dernière recette et intégrité

La révocation temporaire du droit du lecteur fictif sur une seule source a retiré toute la réponse ouverte et la mémoire accessible au contrôle suivant. État visible : « Réponse retirée : source modifiée, accès retiré ou réponse archivée. » ; capture assistant-source-revoquee-768.png. Le droit a été restauré à son état initial, puis la mémoire globale a été suspendue depuis l'interface. Le souvenir et l'historique sont conservés ; aucune suppression effectuée.

`restart-local.json` constate le schéma v2, une réponse persistée, sa référence mémorisée, les permissions 0600 de la base/clé et l'absence des identifiants des sources fictives en clair dans le fichier de base. 834 références protégées et 2 164 preuves historiques inchangées. Scan des secrets de fixtures S08 et motifs JWT sans signal dans les preuves textuelles D ; ce scan n'est pas une garantie exhaustive.
