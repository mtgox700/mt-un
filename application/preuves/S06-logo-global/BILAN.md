# S06 — Logo global par défaut

29 octobre 2026 — lot validé en local ; S06 reste ouvert.

## Réalisé

L’écran existant Documents pilote désormais un logo par défaut propre à l’organisation, enregistré dans Supabase. Import PNG/JPEG/SVG (2 Mo maximum), reprise explicite du logo de marque et retrait sont raccordés sans changement de mise en page ni de parcours. Un retrait signifie « aucun logo pour les nouveaux documents » : l’historique est conservé.

Le droit organisation_edit est nécessaire, en plus de la session/MFA, de l’appartenance et de l’accès au module Documents. Le droit métier d’écriture d’un document seul ne permet pas de modifier le réglage de toute l’organisation. La consultation du défaut est possible aux utilisateurs autorisés du module ; elle ne leur donne aucun accès aux documents privés.

La création copie le défaut courant côté serveur dans le document et transfère sa preuve de contrôle au périmètre du document. Les documents existants, leurs logos particuliers et leurs anciennes versions ne sont pas modifiés. Le logo d’une autre organisation n’est jamais repris implicitement.

## Contrôles et persistance

Antivirus, validation SVG et décodage isolé réutilisés. Une preuve réservée au scanner, liée à l’organisation et à l’empreinte de l’image, est requise avant enregistrement. Les images distantes sont refusées. Chaque changement utilise une version attendue, un verrou en base, une nouvelle version d’historique et un événement d’audit sans contenu de l’image. Aucun stockage navigateur du défaut n’est ajouté.

Migration 111 appliquée à Supabase local : configuration, historique et preuves de contrôle en tables privées avec RLS et accès directs révoqués. Aucune suppression d’archive ou de fichier. Les images sont conservées dans la base avec leurs versions, comme les logos documentaires du lot précédent.

## Tests exécutés

- 24 contrôles d’intégration réussis : droit de gestion, refus anonyme/lecteur/simple rédacteur/autre organisation/administrateur suspendu, preuve de contrôle obligatoire, scanner indisponible, remplacement/relecture, version obsolète, retrait, nouveaux documents avec/sans logo, documents existants inchangés, preuve transférée au document et historique conservé. Le défaut de l’autre organisation reste indépendant.
- 105 tests frontaux réussis, notamment séparation entre réglage global et dernier document ouvert, et refus côté interface malgré un document modifiable.
- 145 tests Python réussis ; compilation et frontières des modules vérifiées.
- Desktop 1440 × 1000 : remplacement et création d’un courrier avec le nouveau logo ; refus de retrait par le lecteur.
- Tablette 768 × 1024 : retrait puis reprise explicite du logo de marque ; refus du lecteur.
- Mobile 390 × 844 : import et affichage du défaut ; refus du retrait et de l’import pour le lecteur.
- Captures inspectées, composants existants conservés. Recette par viewports, pas sur appareils physiques.
- 834 empreintes protégées identiques : prototype et S00 intacts.

## Suite de S06

La réserve « logo global par défaut » du bilan précédent est levée en local. Restent les exports serveur Documents avec fidélité graphique et pagination, les circuits de validation/diffusion, la corbeille et le contrat de signature optionnelle, les conflits et la protection des saisies à la fermeture, puis la recette globale. Une restauration incluant les nouvelles tables et les images reste à tester avant clôture. Le réglage du défaut n’implémente pas une propagation automatique de charte entre organisations ni le module complet de gestion de marque. Aucun déploiement de production.
