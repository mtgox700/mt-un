# S06 — Contrats documentaires

30 octobre 2026. Exécution locale ; aucune activation d’un prestataire externe.

## Extensions officielles

Le manifeste Studio utilise `apiVersion: 1` et `window.uniion.register(manifest)` dans `frontend/extensions/uniion-studio.js`. Les extensions sont compilées avec l’application. Ce contrat ne constitue pas une permission de charger du JavaScript tiers distant.

Modèles : identifiant stable, format et suite de blocs. Blocs persistants : identifiant, type autorisé, texte et image locale certifiée lorsque le type le permet. Styles : identifiant de catalogue et options validées. Les listes côté base et côté rendu doivent évoluer ensemble par migration/version du module. Un type inconnu est refusé, jamais exécuté comme code fourni par le document.

Le serveur ne fait confiance ni au HTML ni à une URL cliente. Les images passent par les contrôles et reçus de scan du document. Les rendus Studio s’exécutent dans l’environnement isolé existant sans réseau. Les contenus métier restent dans leur organisation. Une extension ne peut pas élargir les droits, changer d’organisation ou créer une publication par son manifeste.

Formats d’export disponibles : PDF A4, A5, 16:9. Aucun DOCX/XLSX prétendu disponible. Les blocs omis ou partiellement repris par un style sont ajoutés dans des pages complémentaires avec la charte du document, selon le même plan dans l’aperçu et le PDF. Une composition graphique ou un bloc atomique trop grand reste refusé par le contrôle géométrique. Les versions de sources sont distinctes des PDF archivés lors d’une publication.

## Rendus différés

Le bouton PDF lance un travail durable lié à organisation, ressource, version et demandeur. Deux rendus simultanés, huit places maximum. Aucun jeton n’est enregistré dans la file. Les demandes et récupérations recontrôlent les droits ; le rendu revalide avant de produire son résultat. Le navigateur attend le résultat sans bloquer une requête HTTP de longue durée.

Après interruption du serveur, un travail en cours devient reprenable après cinq minutes par un nouveau clic explicite. Le bail empêche un ancien travail de remplacer le résultat d’une reprise. Pas de relance en masse ni de suppression automatique. Une erreur ou déconnexion ne provoque pas un téléchargement tardif. Les résultats et archives en base sont inclus dans la sauvegarde chiffrée.

## Signature optionnelle — contrat préparé

Le bouton « Faire signer » ne simule pas une signature : il indique que le module optionnel n’est pas branché. Une future implémentation reçoit uniquement une référence de publication immuable (organisation, document, version, empreinte du PDF), la liste de signataires explicitement validée et une clé d’idempotence. Elle vérifie l’accès commercial au module, la permission de signature, le fournisseur approuvé et l’activation de l’organisation avant tout transfert.

États prévus : préparé, soumis, en attente, signé, refusé, expiré, annulé, incertain. En cas de résultat incertain, interroger le prestataire avant de renvoyer. Webhooks authentifiés, rejouables et idempotents. La preuve de signature et son PDF restent liés à la version et aux mêmes droits ; aucune modification des sources. Le choix du prestataire, le niveau de preuve et les appels réseau sont reportés au module dédié selon D09/D13. Cette préparation n’est pas une signature électronique opérationnelle.


## Déconnexion et limites de composition

La déconnexion attend une sauvegarde confirmée lorsque le choix « Enregistrer puis se déconnecter » est retenu. Annuler garde la session et reprend la sauvegarde ; quitter sans réessayer exige un choix explicite et ne promet pas d’annuler une requête déjà transmise. Aucun cache persistant métier ajouté au navigateur. Les erreurs, doubles confirmations et changements d’identité sont contrôlés.

La recette S06-cloture-finale valide les 36 combinaisons des 12 styles avec A4/A5/16:9. Les titres de Sérigraphie et Rétro sont cadrés et les styles paysage génériques utilisent la hauteur disponible pour leur échelle typographique. Cela ne supprime pas les limites : une composition réellement excessive reste refusée par le garde de rendu.
