# S06 — Logos par document et extensions

29 octobre 2026 — Supabase local, données fictives. S06 reste ouvert.

## Réalisé

Les logos PNG, JPEG et SVG (2 Mo maximum) et les images de blocs sont sauvegardés avec la version du document dans Supabase. Chaque nouvelle image passe par l’antivirus et le décodeur isolé ; les SVG sont également validés. La preuve de contrôle est liée au document et à l’empreinte de l’image. Un client ne peut ni fabriquer cette preuve, ni la réutiliser sur un autre document. Les images distantes sont refusées.

Les 12 styles et 12 types de blocs uniion Studio existants sont acceptés par une liste fermée en base, avec validation des palettes et polices. Aucun chargement de nouveau code d’extension. Les sauvegardes conservent style, options, blocs, images et charte. Les droits d’écriture, l’organisation, le module et la version restent contrôlés. Les lecteurs peuvent consulter les images autorisées, mais pas les modifier.

Migration 110 appliquée en local. Aucun fichier du prototype ou de S00 modifié. Les vues et styles CSS du lot précédent sont inchangés ; seuls leurs services sont raccordés. Les messages d’image indiquent la sauvegarde serveur réelle et ne promettent plus une conservation locale.

## Tests exécutés

- 24 contrôles d’intégration réussis : logos PNG/SVG, photo JPEG, relecture, lecture seule, autre organisation, révocation, version périmée, image invalide, SVG actif, preuve forgée ou réutilisée, style/options invalides, photo distante et fichier antivirus EICAR. Une panne simulée du scanner renvoie un refus de service sans enregistrer l’image.
- 26 contrôles de matrice réussis : création et relecture des 12 styles avec les 12 blocs de l’extension.
- 103 tests frontaux et 145 tests Python réussis. Compilation et contrôle des frontières réussis.
- Interface desktop 1440 × 1000 : import réel du logo PNG, changement de style, retour à la liste puis relecture ; refus de retrait du logo et de changement de style pour le lecteur.
- Tablette 768 × 1024 et mobile 390 × 844 : édition d’un bloc Chiffre clé, sauvegarde, aperçu/relecture ; refus du retrait de logo et du changement de style pour le lecteur. Le style reste inchangé après le refus.
- Captures inspectées. Tests par dimensions de navigateur, pas sur appareils physiques. La matrice de persistance ne constitue pas une validation visuelle exhaustive de tous les styles et contenus longs.
- 834 empreintes protégées identiques.

## Limites et suite

La personnalisation est raccordée par document dans l’onglet Charte graphique. Le réglage global « Logo par défaut des documents » de la liste reste à raccorder à une configuration d’organisation sécurisée : ses commandes ne doivent pas modifier implicitement le dernier document ouvert. Cette réserve reste explicite ; le lot ne couvre pas encore ce réglage global.

Les images sont stockées dans le contenu versionné en base, comme pour l’Agenda ; aucune URL publique n’est créée. Une restauration des nouvelles tables/preuves de contrôle reste à tester avant clôture S06. Le remplacement d’un logo ne purge aucune ancienne version.

Restent aussi les exports serveur Documents avec ces personnalisations, les tests de pagination longue et fidélité de tous les gabarits, les circuits de validation/diffusion, le contrat de signature optionnelle, la corbeille, les conflits d’édition et la protection de saisie à la fermeture du navigateur. Le déploiement reste hors périmètre.
