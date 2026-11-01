# S05 — Finition et proposition de clôture locale

29 octobre 2026 · Supabase local · Skill uniion appliqué.

## Périmètre livré

Le classement couvre les contenus serveur validés : convocations, archives PDF/ICS et pièces jointes. Les sources restent contrôlées à chaque consultation : classer une référence ne donne aucun droit supplémentaire. Les conversations de démonstration et brouillons locaux restent exclus selon l’arbitrage utilisateur.

Les réserves de finition sont traitées : préparateur du tableau Dossiers extrait ; accueil alimenté par les dossiers accessibles ; navigation entre pages de l’aperçu ; reprise antivirus ; retrait réversible des références et des dossiers soumis au super admin. Les ajouts visibles utilisent les composants existants et ont été expressément approuvés dans cette conversation.

## Retrait et restauration

Une demande porte un motif et une version. Tant qu’elle attend la validation, le contenu reste accessible selon ses droits habituels. Le super admin voit un inventaire technique, sans contenu métier. L’approbation retire le dossier ou la référence. Les octets et historiques sont conservés. La restauration exige les droits métier actuels et ne rétablit aucun droit révoqué.

Les migrations 104–107 ajoutent ces états et leurs contrôles. Deux défauts détectés et corrigés : les politiques PostgreSQL conservaient la référence à la fonction renommée ; un alias SQL ambigu empêchait l’affichage de la corbeille. Les accès directs aux ressources et versions retirées sont désormais refusés par RLS.

## Vérifications exécutées

- 97 tests frontaux et 145 tests Python réussis. Compilation et frontières validées.
- Six suites de non-régression S05 réussies : 33, 23, 27, 21, 30 et 26 contrôles respectivement. Ces nombres incluent les prérequis de chaque suite.
- 28 contrôles ciblés de retrait/restauration, 11 contrôles de liste et RLS, 13 contrôles d’aperçu et reprise antivirus réussis. Refus du lecteur, droits source, retrait de référence/message/dossier, rétablissement des octets et maintien des révocations couverts.
- Pile neuve : 92 contrôles réussis jusqu’à la migration 106 ; la migration corrective 107 a ensuite été appliquée avec succès sur cette même base isolée.
- Sauvegarde finale `20261029T174845Z`, base et fichiers restaurés dans une pile isolée : 301 contrôles réussis. Puis 12 contrôles Auth/MFA et droits sur cette restauration. Aucun volume de sauvegarde supprimé.
- 834 fichiers de référence vérifiés : aucun changement du prototype ni de S00.

## Interface et fidélité

Formats : mobile 390×844, tablette 768×1024, desktop 1440×1000.

L’accueil réel et le refus d’édition ont été testés aux trois formats (preuves S05-accueil). L’aperçu des deux pages est vérifié aux trois formats ; captures de la page 2 disponibles. Le retour à la page 1 a été observé sur mobile. Les demandes de retrait du lecteur sont refusées dans l’interface aux trois formats. La reprise réelle de l’antivirus est actionnée sur mobile. Le cycle gestionnaire demande → approbation super admin est actionné sur tablette, puis la restauration sur mobile. Les autres combinaisons d’acteurs, notamment le retrait de message classé, sont couvertes par les tests d’intégration, pas présentées comme des clics répétés aux trois tailles.

Les captures inspectées ne montrent pas de chevauchement des commandes de l’aperçu. Aucun débordement horizontal de page constaté sur les vues mesurées. Les notifications de corbeille occupent leur zone dans le flux. Pas de refonte des écrans, couleurs ou styles généraux ; ajouts fonctionnels autorisés uniquement.

## Incident de recette résolu

Le service antivirus local est devenu indisponible pendant les recettes et les opérations Docker ont ralenti. Les fichiers sont restés bloqués : ces échecs ne sont pas comptés comme des refus de permissions réussis. ClamAV a été redémarré ; seules les piles isolées créées pour ce lot et déjà validées ont été arrêtées, sans suppression. Le téléchargement réel du fichier classé et les 28 contrôles de retrait ont été rejoués avec succès après rétablissement. La session UI interrompue a été reconnectée avant la fin de la recette.

## Conclusion et suite

Clôture technique locale proposée pour S05 dans son périmètre serveur validé. L’acceptation produit reste à l’utilisateur. Ce bilan ne vaut ni déploiement ni validation de production.

Les futurs raccordements de l’éditeur Documents, des conversations encore locales et de l’assistant IA restent dans leurs lots dédiés. La signature électronique demeure une option dédiée. Aucune purge physique ni suppression automatique n’est activée. L’exploitation OVH/Supabase managé, la supervision de l’antivirus et la recette de restauration sur la cible restent à vérifier avant production.
