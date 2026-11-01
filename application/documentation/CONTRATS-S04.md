# S04 — Contrats du registre adhérents

## Frontières

Le registre métier `uniion_private.adherents` est distinct d’Auth, des appartenances à une organisation et des contacts du prototype. Un import ne crée aucun compte, aucune invitation ni aucun droit plateforme. La fin d’adhésion ne révoque pas implicitement un compte. Les données et listes restent dans l’organisation ; aucun accès fédération/section n’est hérité.

Le contrat partagé avec les futurs modules est une API autorisée, pas une table publique ni une permission de partage interorganisation. Les partages S00 restent des opérations explicites distinctes.

## Commandes

Toutes passent par `POST /identity/adherents` avec `organization_id`, `action` et `payload`. La RPC `public.uniion_adherents` recontrôle session MFA, appartenance, module activé, accès commercial et permissions. Les fonctions précédentes sont révoquées pour les rôles clients ; les tables privées ne sont pas exposées.

- `list` : fiches et listes de l’organisation. Données financières uniquement avec lecture des cotisations.
- `list_create` : nom, description, critères et UUID de demande. Modification des adhérents requise ; rejeu identique sans doublon.
- `list_update` : identifiant, version, nom et description. Version périmée refusée. Aucune suppression implicite.
- `campaign_targets` : identifiant de liste, résolution dynamique dans l’organisation. Résultat `uniion.members.targets.v1` : organisation, liste/version, identifiants/versions des fiches, prénom, nom, courriel et rattachement entreprise/établissement. Aucun montant ni historique financier. `delivery: not_requested` signifie qu’aucun envoi n’a eu lieu.
- `directory_export` : même projection minimale, droit de téléchargement supplémentaire et événement d’audit. Contrat serveur JSON ; aucun nouveau bouton d’export de l’annuaire ajouté à l’UX. Les téléchargements CSV des règlements et PDF des reçus restent disponibles dans la fiche existante.
- `schedule_activate_preview` et `schedule_activate` : anciennes fiches sans plan, tarif/cadence structurés, première date strictement future confirmée, version de fiche et UUID de demande. Une couverture inconnue ou future chevauchante bloque. Aucun rattrapage, aucune écriture bancaire.

Les critères raccordés sont recherche textuelle, entreprise, établissement, section, direction et statut de cotisation réel. Le statut financier est calculé à partir des échéances et règlements : retard si un solde reste dû avant aujourd’hui, à jour si les échéances exigibles sont réglées, nouveau sinon. Une liste filtrée financièrement reste invisible et inutilisable sans lecture des cotisations, y compris par identifiant connu ou avec le seul droit de téléchargement. La perte du droit retire aussi le filtre financier côté interface.

## Consommateurs futurs

Les modules Campagnes/Messages devront recontrôler les droits, versions et destinataires au moment d’une validation puis d’un envoi, traiter les refus et changements d’organisation, et appliquer D09/D12/D13. Le contrat actuel ne vaut jamais autorisation d’envoi. Aucun fournisseur externe ni envoi réel de campagne n’est activé dans S04.

Documents : les reçus livrés sont non fiscaux. Bulletins, attestations fiscales et notices du prototype restent explicitement non raccordés ; le moteur Documents est prévu en S06. La suppression métier reste bloquée tant que son circuit d’approbation super admin n’est pas raccordé (D07).

## Reprise

La sauvegarde couvre les tables privées et les fichiers `dues_evidence`, avec empreintes et état antivirus. Les deux fonctions des colonnes calculées sont restaurées avant les tables. Restauration isolée de clôture : 241 contrôles d’intégrité et 16 contrôles d’accès avec authentification réelle. Les sessions antérieures ne sont pas restaurées. La recette neuve applique toutes les migrations présentes puis teste Auth, REST et Storage sans la source.
