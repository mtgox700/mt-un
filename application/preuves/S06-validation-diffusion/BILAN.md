# S06 — Validation et diffusion interne des documents

30 octobre 2026 — lot local réalisé et testé ; S06 reste ouvert.

## Décision utilisateur

Second acteur obligatoire pour tous les documents de ce lot. Diffusion interne limitée aux personnes déjà habilitées sur le document, sans élargissement des accès ni envoi externe. La modale existante propose validation après relecture puis diffusion interne. Cette décision est consignée ici sans modifier S00.

## Réalisation

Module Documents : service de publication séparé, commande serveur et migration 113 appliquée à Supabase local. Le bouton Diffuser ouvre la modale existante. Les confirmations simulées et audiences fictives sont remplacées par les actions et résultats réels. Aucun changement de CSS, de disposition ou de navigation.

Deux permissions distinctes : document_review et document_publish, avec libellés dans l’administration des droits. Aucune attribution automatique. Session/MFA, appartenance, module et accès à la ressource sont obligatoires. Le super admin ne reçoit pas de privilège métier implicite.

Les contributeurs des versions antérieures et courante ne peuvent pas valider leur propre document. Une attribution d’auteur inconnue bloque aussi la validation. La publication recontrôle l’accès du valideur et sa permission de validation. Le diffuseur peut être le rédacteur, après validation par un autre acteur.

Les validations/publications sont liées à une version exacte et historisées en tables privées avec RLS, accès direct révoqué et référence à l’historique immuable de la ressource. Les actions effectives sont auditées. Une répétition de publication ne crée pas un second événement. Une modification ultérieure crée un nouveau brouillon sans effacer l’ancienne publication. Les métadonnées PDF reprennent le statut courant au lieu d’indiquer systématiquement brouillon.

La diffusion de ce lot signifie publication interne du statut et de la version dans Documents, consultable par les personnes déjà autorisées. Elle n’envoie pas de notification, d’e-mail, de PDF ni de message externe et ne crée aucun nouveau droit. Le contenu était déjà accessible à ces lecteurs avant publication. Aucun archivage binaire PDF ajouté.

## Tests exécutés

- 25 contrôles d’intégration réussis : MFA, création, refus anonyme, relecteur sans accès, auteur, publication avant validation, autre organisation, validation par second acteur, lecture du statut, publication sans permission, révocation du valideur, publication autorisée et idempotente, audit unique, modification et nouvelle validation exigée, historique conservé, module désactivé, trois documents de recette UI.
- 110 tests frontaux réussis : notamment réponse tardive après déconnexion, refus sans succès optimiste et double confirmation.
- 146 tests Python réussis ; compilation et frontières des modules vérifiées. Les métadonnées PDF du statut diffusé ont un test dédié.
- Interface CUA avec deux comptes fictifs : sur desktop 1440 × 1000, tablette 768 × 1024 et mobile 390 × 844, validation réelle par le relecteur, refus de publication faute de permission, puis première publication avec le diffuseur. Refus d’auto-validation également testé sur desktop.
- Les trois publications UI ont été relues en base : deux acteurs distincts et date de publication persistante. La recette par API confirme la relecture des statuts par l’autre compte et l’historique des versions.
- Captures desktop/tablette/mobile inspectées : modale et boutons lisibles ; aucun chevauchement observé sur ce parcours. Tests de viewports, pas d’appareils physiques.
- 834 empreintes protégées identiques : prototype et S00 intacts.

## Réserves et suite

S06 n’est pas clôturé. Restent : rejet métier motivé et demande de corrections, consultation dédiée des anciennes publications, notifications et éventuels canaux de diffusion supplémentaires avec leurs audiences explicites, archivage du PDF effectivement diffusé, corbeille, contrat de signature optionnelle, conflits/protection des saisies, recette graphique complète et restauration incluant les tables et images S06. Les refus d’autorisation testés ici ne constituent pas un circuit de rejet humain motivé.

Aucun fournisseur externe ni déploiement de production. Les tests de reprise de session après rechargement et la recette globale restent distincts de cette recette de publication ; la persistance est établie par les relectures serveur et base.
