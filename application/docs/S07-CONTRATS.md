# S07 — Contrats des lots A, B et C

30 octobre 2026. Conversations privées et groupes, Supabase local.

## Accès et stockage

Module catalogue : messagerie. Activation, autorisation, droit commercial valide, session MFA aal2, appartenance active à l’organisation et permission read sont cumulés. La permission write autorise création d’une discussion privée et envoi, conformément à messages.send ; aucun droit de groupe n’est implicitement attribué.

Les trois tables message_conversations, message_participations et messages sont dans uniion_private, avec RLS activée et aucun privilège de table pour anon/authenticated. Seule la RPC publique uniion_messaging est exposée aux utilisateurs authentifiés. Elle utilise auth.uid(), jamais un auteur fourni par le client. Les helpers privés sont sans droit d’exécution client. Le BFF utilise le JWT utilisateur, jamais service_role.

Une participation possède une période (joined_at, left_at), une borne de séquence visible_from et la date de l’appartenance d’organisation. Un départ ferme l’accès ; une nouvelle date d’arrivée dans l’organisation ne réactive pas l’ancienne participation. Les commandes habilitées de membres/historique sont raccordées au lot B. Aucun administrateur ou super administrateur ne contourne la participation.

La paire de participants est unique par organisation. Création et répétition renvoient la même conversation ; depuis le lot B, cette commande explicite crée une nouvelle période si la participation est fermée ou périmée, à la prochaine séquence, sans restaurer les anciens accès. La consultation seule ne réactive rien.

## API

POST /identity/messaging, avec CSRF et session opaque existants :

- organization_id : UUID ; contrôlé côté serveur.
- action : participants, list, create, get ou send.
- payload : objet strict, aucun champ supplémentaire.

| Action | Payload | Réponse |
| --- | --- | --- |
| participants | {} | Membres actifs ayant read : identifiant, nom et fonction, sans courriel |
| list | before UUID optionnel | rows, next ; 50 conversations maximum |
| create | participant UUID | Conversation privée créée ou existante |
| get | id UUID, before chaîne de séquence optionnelle | Conversation, messages en ordre croissant, next |
| send | id UUID, clientId UUID, text, replyTo chaîne optionnelle | Message confirmé avec date, auteur et séquence serveur |

Les curseurs ne donnent aucun droit : chaque page recalcule les contrôles. Liste ordonnée par identifiant immuable décroissant ; fil par séquence serveur, pages de 50 messages. Les séquences sont transportées en chaînes pour éviter les pertes de précision JavaScript.

Un verrou de conversation sérialise l’allocation de séquence et les envois concurrents. La clé (organisation, conversation, auteur, clientId) est unique. Même clé et même contenu : même message. Contenu ou référence de réponse différent : refus. Une réponse doit cibler un message actuellement visible de la même conversation ; son extrait est recalculé côté serveur selon les droits du lecteur.

Texte inerte, non vide, jusqu’à 10 000 caractères côté serveur, limite conservatrice de 10 000 unités UTF-16 dans l’interface. Aucun HTML exécuté. Audit minimal (identifiants), sans copie du texte.

## Frontal et reprise

Le service du module possède les requêtes et projections en mémoire. Les conversations/messages S07 sont exclus de la persistance et restauration localStorage héritées. Déconnexion : données, brouillons et requêtes en attente invalidés ; résultats tardifs ignorés. Un changement d’organisation recharge le contexte comme dans le socle existant.

Un envoi n’est affiché qu’après confirmation serveur. En cas de résultat incertain, la saisie et la clé restent en mémoire pour une nouvelle tentative identique. Les brouillons survivent à un passage entre fils dans la même session. Après fermeture/rechargement, relire le fil avant de réémettre une saisie non confirmée ; aucune file durable hors ligne n’est annoncée (S13).

Une coche signifie enregistré, pas lu. Le lot D recherche tous les messages autorisés côté serveur ; compteurs de non-lus et notifications sont raccordés au lot E. Les convocations gardent leur adaptateur et leurs contrôles existants.

Le transfert par référence est raccordé au lot D. Suppression de messages et IA du fil restent indisponibles. Les pièces et le classement manuel sont raccordés au lot C. Réponse, informations et copie du texte restent disponibles. Aucun envoi externe.

## Périmètre de validation

Voir preuves/S07-A/BILAN.md et preuves/S07-B/BILAN.md. Installation neuve et restauration S07 restent au lot F ; leur réussite n’est pas déduite des restaurations S06. La révocation est effective à chaque requête ; l’invalidation spontanée d’un écran sans action et les abonnements temps réel appartiennent au lot E.

## Lot B — membres, rôles et historique

Migrations 122–125. Les groupes ajoutent nom (120 caractères), description (2 000), version et rôles de modération par période de participation. Maximum 100 membres, créateur compris. La permission create est requise pour créer un groupe ; le créateur devient administrateur de ce groupe. Administrer l’organisation ne donne pas la modération d’un groupe ni sa lecture.

| Action | Payload | Contrôle supplémentaire |
| --- | --- | --- |
| group_create | clientId, name, desc, members UUID[] | create, clé idempotente et contenu identique |
| group_save | id, version, name, desc, members UUID[] | administrateur courant ; members exclut l’appelant |
| member_role | id, version, participant, admin booléen | administrateur courant, aucune modification de son propre rôle |
| leave | id, version | groupe ; un autre administrateur actif disposant de read doit rester |
| history_grant | id, version, period UUID, messages chaînes de séquences[] | habilitation history et lecture actuelle de chaque message source |
| history_revoke | id, version, period UUID | habilitation history ; retrait des ouvertures explicites de cette période |

Toutes les mutations verrouillent la conversation, contrôlent sa version et auditent les identifiants sans recopier les messages. Une version périmée est refusée. Ajouter ou réinviter ouvre une nouvelle période à la séquence suivante. Retirer ferme la période ; aucun message n’est supprimé. Les rôles et ouvertures historiques ne sont pas restaurés lors d’une réinvitation.

Les ouvertures explicites sont stockées dans message_history_grants, table privée sous RLS sans privilèges clients. Elles ciblent au plus 100 messages choisis et une période actuelle d’un autre participant. Le destinataire doit conserver read et son appartenance active. Le donneur doit être participant courant, habilité history et lecteur des messages choisis. La modération ne donne pas automatiquement history. Révoquer retire toutes les ouvertures explicites de la période ciblée, sans retirer les messages normalement accessibles depuis l’arrivée.

Les extraits de réponse sont recalculés selon les droits actuels. Au rechargement d’un fil, une citation de brouillon n’est restaurée que si son message figure dans la page autorisée chargée. Les requêtes tardives ne modifient pas une nouvelle identité. Les formulaires conservent les saisies en cas de refus ou résultat incertain ; l’erreur apparaît dans le formulaire. Le retrait préparé dans l’éditeur demande une sauvegarde explicite.

Aucun contournement par super admin, administrateur d’organisation ou ancien administrateur de groupe. Un groupe privé de tout modérateur accessible après révocation externe ne donne lieu à aucune auto-escalade ; sa récupération administrative reste un circuit distinct à définir. La révocation s’applique à chaque requête ; le rafraîchissement spontané d’un écran relève du lot E.

## Lot C — pièces privées et classement

Migrations 126–130. Le bouton Joindre dépose une pièce par message (5 Mio maximum), sans modifier la saisie texte en cours. Formats du coffre : PDF, PNG, JPEG, texte UTF-8, DOCX et XLSX, sous validation de structure. Le message « Pièce jointe » et son objet sont réservés avant le transfert ; l’état de quarantaine reste visible, sans rendre les octets accessibles. Aucun contenu de fichier n’est incorporé au texte du message.

La table privée message_files relie une séquence de message à une ressource du coffre et à un objet immuable. Les droits de cette ressource sont ceux du message : membre courant, période ou ouverture historique, read, activation et commercial du module. L’écriture de la pièce nécessite en plus write et son auteur. Les grants génériques ne contournent pas ce lien ; le partage générique de cette ressource ne donne aucun accès.

POST /identity/messaging ajoute file_upload (id, clientId, filename, content base64), file_preview (id, attachment, page), file_download (id, attachment) et file_rescan (id, attachment). Entrées strictes, JWT utilisateur. La préparation retourne le même objet pour la même clé et les mêmes métadonnées/empreinte ; changement de contenu refusé. Un dépôt interrompu sans objet peut renouveler sa fenêtre courte d’insertion, sans écraser d’objet. Après rechargement, le frontal réutilise la clé du message inachevé correspondant au même fichier. Aucune file hors ligne durable n’est ajoutée.

Le scan ClamAV et le rendu isolé sont ceux du coffre. État pending/error/infected/invalid : pas de téléchargement, d’aperçu ni de classement de la pièce. Une ancienne génération de scan ne libère pas une nouvelle analyse. Les lectures directes Storage restent fermées ; la passerelle vérifie l’empreinte et les droits après récupération. L’aperçu PDF/PNG/JPEG renvoie une image inerte ; les autres formats restent téléchargeables si autorisés, sans aperçu promis. Le téléchargement exige l’habilitation download distincte. Le worker technique existant ne donne aucun rôle métier au client.

POST /identity/cases ajoute message_classify (case, expected, conversation, seq chaîne, file UUID ou chaîne vide). Chaque opération classe un message entier ou sa pièce, par référence durable. Écriture du dossier, version et lecture actuelle de la source sont cumulées. Les listes, compteurs, historique, aperçu et téléchargement du dossier revérifient la source. Retrait du participant, fermeture d’historique, module désactivé, suspension, corbeille source ou révocation du dossier bloquent la référence. Aucun texte historique n’est copié dans le corps durable du dossier.

Les demandes de corbeille de pièces Messages réutilisent le circuit D07 du coffre : demande de l’auteur encore habilité, validation super admin sur métadonnées minimales, restauration explicite sans rétablissement de droits perdus. Aucun effacement physique. Les références classées utilisent le retrait/restauration existant des liens Dossiers.

Recette : preuves/S07-C/BILAN.md. Création de dossier par qualification IA, classement automatique d’extraits, transfert vers une autre audience et signature restent indisponibles dans ce lot ; les commandes de classement manuel d’un message ou d’une pièce sont raccordées. D/E/F restent ouverts.


## Lot D — réponse, transfert et recherche

Migrations 131–132. La réponse existante conserve seulement une séquence cible ; la citation est résolue à chaque lecture selon les droits actuels, y compris lorsqu’elle vise un transfert. Une réponse peut rester visible sans sa citation devenue inaccessible.

| Action messaging | Payload | Résultat et contrôle |
| --- | --- | --- |
| search | query (1–200 caractères), before UUID optionnel | 50 correspondances maximum, curseur next ; lecture autorisée de chaque source avant projection |
| targets | query (0–200 caractères), before UUID optionnel | 50 discussions courantes autorisées ; métadonnées minimales |
| locate | id conversation, seq chaîne | page de 50 messages au plus finissant au résultat ; focused et curseur vers les plus anciens |
| forward | id source, seq chaîne, clientId UUID, targets UUID[] | 1–20 destinations distinctes, source exclue ; write et participation courante ; transaction atomique |

La recherche porte sur le texte, le nom de pièce et le nom de conversation dans tous les messages ordinaires persistés et autorisés, pas seulement le fil chargé. Correspondance littérale insensible à la casse, sans extraction du contenu binaire ni indexation des convocations Agenda. Pagination stable par UUID de message décroissant, sans promesse d’ordre chronologique ou de pertinence. Aucun total inaccessible n’est exposé. Les filtres de listes de discussions ne sont pas affichés pendant une recherche de messages. Un résultat ouvre sa séquence exacte ; « Messages récents » recharge la fin du fil.

Les transferts sont des références privées : message_forwards et message_forward_batches sous RLS, sans privilège client direct. Aucun corps ni fichier source n’est recopié dans le message durable de destination. La projection conserve l’auteur et la date du transfert, avec l’indicateur Transféré. Le lecteur doit cumuler l’accès au message de destination et à chaque maillon source, y compris périodes et ouvertures historiques. Chaîne limitée à huit références. Une destination accessible ne donne aucun droit supplémentaire à ses membres : sans accès source, la référence est absente du fil, des extraits et de la recherche. Une publication distincte vers une audience élargie selon D12/D13 reste hors périmètre.

Les pièces transférées utilisent l’objet source et restent en lecture seule dans ce contexte. L’aperçu et le téléchargement vérifient la destination et la source ; download demeure distinct. Corbeille/quarantaine source masquent la référence transférée. Le classement Dossiers conserve la référence au message de destination et cumule les droits de tous les maillons.

Une clé de transfert appartient à l’acteur et à l’organisation ; sa réutilisation impose la même source et les mêmes destinations. Verrouillage ordonné des conversations et verrou de lot empêchent les doublons concurrents et les lots partiels. La réponse durable ne contient que les identifiants produits. Un résultat réseau incertain conserve sa sélection et sa clé pour une reprise sans duplication. Toute réponse tardive est ignorée après changement d’identité/contexte. Aucun succès optimiste, aucune file hors ligne.

La modale existante affiche les destinations serveur, une notice des droits source et les erreurs. Audit minimal sans texte des messages. Recette : preuves/S07-D/BILAN.md. Le rafraîchissement spontané après révocation reste au lot E ; toutes les requêtes de D revérifient les droits. Pile neuve/restauration/charge et clôture restent au lot F.


## Lot E — temps réel local, lectures et notifications

Migrations 133–135. Table privée message_reads : curseur monotone par organisation, conversation et période de participation. Le départ ne supprime pas la trace ; la nouvelle période de réinvitation n’hérite pas de son curseur. Les non-lus sont calculés sur les messages actuellement visibles d’autrui après ce curseur. Une ouverture historique ultérieure sous ce curseur ne recrée pas une alerte rétroactive. Il s’agit d’un état de lecture dans l’application, pas d’une preuve de lecture humaine.

| Action | Payload | Comportement |
| --- | --- | --- |
| read | id, seq chaîne | séquence actuellement lisible, curseur monotone de l’acteur courant ; aucune permission write nécessaire |
| read_all | objet vide | avance les curseurs aux dernières séquences actuellement autorisées ; idempotent |
| notices | objet vide | au plus 50 notifications non lues, ordre date serveur/id ; référence, titre autorisé et date, sans copie du texte |
| live | id optionnel, at optionnel avec id | projection autorisée, compteurs, empreintes, première page de discussions, notifications et page de fil éventuelle |

Le flux GET /identity/messaging/events reçoit organization, id et at optionnels, et cursor optionnel. Cookie de session HttpOnly uniquement, Host/Origin/Fetch-Site contrôlés, MFA et droits de module vérifiés avant abonnement et à chaque projection. Aucun JWT dans le navigateur ou l’URL. Trois connexions par session et 64 par processus au maximum ; fermeture/renouvellement du flux après deux minutes. Les battements du flux ne prolongent pas l’inactivité de session.

Transport SSE réel sur un serveur WSGI concurrent local. Chaque mutation réussie sur ce BFF réveille un signal interne sans identifiant ni contenu ; les abonnements reconstruisent leur projection sous le JWT du lecteur. Une activité cachée ne change ni le curseur ni le flux de données reçu. Les battements sans métier suivent une cadence de dix secondes. Les changements venant d’un autre processus ou directement de la base sont réconciliés à cette cadence ; ce transport local n’est pas un bus distribué de production.

Le curseur SSE est une empreinte opaque de la projection autorisée, pas le numéro d’un événement global. Last-Event-ID est accepté ; la reconnexion renvoie toujours un instantané autorisé, puis le frontal déduplique le curseur. Les messages gardent leur ordre serveur seq et leur pagination. Pas de promesse de livraison de chaque événement intermédiaire : les messages durables et les curseurs de lecture permettent la reprise de l’état. Une page récente contient 50 messages ; les pages plus anciennes restent récupérables. Un changement de projection invalide les anciennes pages et les références transitoires, afin de ne pas conserver des extraits révoqués.

L’accès retiré ferme le flux ou retire la conversation de sa projection. Le frontal purge les messages, notifications, recherches, citations, formulaires et aperçus concernés ; les réponses tardives d’une ancienne identité sont ignorées. Coupure : purge de l’état reçu, reconnexion automatique et resynchronisation. Un délai sans battement de 25 secondes déclenche aussi une purge/reconnexion, sous réserve de l’ordonnancement du navigateur. Les trames déjà en vol ne sont pas récupérables ; aucune nouvelle projection ne contourne le contrôle serveur. Les délais incluent la latence réseau et les requêtes en cours.

L’acquittement automatique exige un fil ouvert, un document visible avec focus et un défilement en bas. Le bouton existant Tout marquer comme lu utilise read_all. Les notifications Messages utilisent la cloche et la page existantes, sans email ni push système. Les exemples de notifications statiques sont retirés du mode connecté ; les adaptateurs Agenda/Documents restent distincts. La coche simple indique toujours l’enregistrement serveur : aucune nouvelle liste nominative de lecteurs ni double coche supposée n’est ajoutée.

Voir preuves/S07-E/BILAN.md. Charge représentative, restauration incluant message_reads et installation neuve restent au lot F. Les performances de la projection, qui recalcule les droits sur l’historique visible, ne sont pas qualifiées pour la production.

## Lot F — qualification et corrections de volume

Migrations 136–140 : notifications limitées à la page autorisée avant projection des titres, révision des messages simples sans reconstruction répétée du JSON, non-lus comptés après un contrôle d’appartenance par conversation et selon la période courante, recherche matérialisant une seule fois les origines autorisées. Les pièces, réponses et transferts gardent la projection complète et les contrôles de chaîne. Une action SQL NULL ou un payload non objet est explicitement refusé. Les formats d’API, la pagination et les droits métier ne changent pas.

Qualification locale bornée : 1 200 écritures distinctes avec huit appels RPC simultanés, en plus de deux messages initiaux ; aucune séquence manquante ou dupliquée. Dix projections live sur cet état : 0,82–1,80 seconde sans autres recettes lourdes en parallèle. Avec restaurations/régressions concurrentes sur le même hôte, certains échantillons ont atteint 2,34 secondes. Ce budget de deux secondes ne constitue ni un SLA ni une qualification du BFF, de plusieurs serveurs, de longues chaînes de transferts à grande échelle ou de la production. La recherche reste une recherche exhaustive contrôlée, sans moteur d’indexation du contenu des fichiers.

Installation neuve : 134 fichiers SQL baseline/migrations jusqu’à 139, puis migration 140 appliquée incrémentalement sur cette même cible issue de zéro ; 135 fichiers au total. Auth/MFA, coffre/ClamAV et S07 vérifiés. Restauration chiffrée isolée de l’état final, tables S07 et octets privés, puis nouvelles connexions MFA et refus métier. Aucune session Auth historique restaurée. Aucune remise automatique des files d’envoi ; admission en production toujours distincte avec réconciliation des révocations postérieures au snapshot.

Preuves consolidées et réserves : ../preuves/S07-F/BILAN.md. F permet la clôture technique locale de S07 ; aucune validation visuelle utilisateur ou mise en production n’en est déduite. Restent hors périmètre : bus distribué, push/email de Messages, hors ligne durable S13, diffusion élargissant les droits D12/D13, classement IA et signature.

## Statut de clôture — 30 octobre 2026

S07 A–F est clôturé dans le périmètre local sur décision utilisateur « ok cloture ». La livraison et sa présentation visuelle sont acceptées sur les éléments présentés ; les limites techniques et exclusions ci-dessus restent applicables. Voir ../preuves/S07-F/CLOTURE.md.
