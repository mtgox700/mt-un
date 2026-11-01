# S09 — A1 : attestation de consentement persistante

31 octobre 2026. **S09 démarré ; A1 serveur réalisé et testé. Lot A et sprint S09 ouverts.**

## Périmètre et réalisé

Reprise du handover, lecture des bilans S08/S06 et décisions applicables, inventaire audio et plan A–F. Développement dans `application/`, sans worktree ni dépôt Git disponible à la racine, sans déploiement. Données fictives uniquement.

Migration additive 164 installée sur PostgreSQL local `supabase_db_unii`. Une réunion native dispose désormais d’une attestation de l’opérateur versionnée, lisible et modifiable par le contrat serveur. Le retrait crée une nouvelle version. Une modification de réunion rend l’attestation antérieure non courante. Aucun contenu audio capturé, stocké ou transmis par ce lot.

Le contrat HTTP existant transmet l’autorité de l’utilisateur à la RPC. Verrou de réunion et versions empêchent l’écrasement concurrent ; journal des transitions sans contenu métier. Table privée avec RLS, accès direct retiré. Aucun droit audio accordé par l’attestation.

## Tests exécutés

- **34 contrôles d’intégration réussis** : Auth/MFA local, création fictive, déclaration et relecture par un second acteur, nouveau serveur/session puis relecture, modification de réunion, renouvellement, retrait persistant, audit ; refus lecteur en écriture, autre organisation, module désactivé, ACL révoquée, anciennes versions et types/champs injectés. Voir `integration.json`.
- **278 tests Python réussis**, dont trois nouveaux tests d’aiguillage du contrat ; voir `python-tests.log`.
- Frontières des modules et 14 migrations de référence : OK, `boundaries.log`.
- **3 809 références et anciennes preuves inchangées**, manifestes dans `../S09-demarrage/`.

Le premier essai d’intégration a été refusé à la création : l’organisation fictive manquait de droit commercial. La fixture a été complétée, sans affaiblir le contrôle métier ; la recette entière a ensuite été rejouée avec succès. Les organisations fictives de recette restent locales, sans nettoyage destructif.

## Fidélité et limites

Aucun fichier frontend, style, prototype ou référence modifié. Pas de recette visuelle ni de test sur appareil revendiqué pour cette tranche serveur. Les cases actuelles de capture ne sont pas encore raccordées à cette API.

L’attestation de l’opérateur n’est pas une preuve individuelle du consentement de chaque participant. Aucun droit d’écoute, de téléchargement ni d’envoi externe n’en découle. La restauration de la nouvelle table n’a pas encore été recettée ; les preuves S08 ne la couvrent pas automatiquement.

## Suite

Poursuivre A2 : modèle audio et stockage privé, permissions audio distinctes, liaison consentement/prise/participants, marqueurs et contrôles de fichier. Puis B : remplacer les flux locaux de capture/import/lecture par une sauvegarde serveur vérifiée. Jobs et moteur réel de transcription demeurent en C ; chaîne PV et conservation/restauration en D–F. Les décisions de production restent à S16, avant tout usage réel.

Références : `../../docs/S09-CONTRATS.md`, `../../planification/S09-demarrage/PLAN-S09.md`, `../S09-demarrage/INVENTAIRE.md`.
