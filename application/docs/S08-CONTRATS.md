# S08 — contrats du lot A

30 octobre 2026. Passerelle locale, **recette fictive uniquement**. L'autorisation utilisateur du connecteur ChatGPT/Codex local ne constitue pas un choix de fournisseur de production ni une autorisation de transmettre des données métier.

## Routes

Toutes les routes exigent cookie opaque, origine locale exacte, CSRF et session autorisée. Aucun Bearer fourni par le navigateur n'est accepté. Les jetons Supabase et l'authentification Codex restent côté serveur.

- `POST /identity/ai` : `{organization_id, action, payload}`. Actions `status`, `approve`, `activate`, contrôlées par `uniion_ai_policy` avec le JWT de l'utilisateur.
- `approve` : `{enabled, version}` ; super admin et MFA. La version globale augmente à chaque revue, ce qui invalide les activations antérieures.
- `activate` : `{enabled, version, providerVersion}` ; membre actif ayant l'autorité `organization_edit`. Ne donne aucun droit métier. Version initiale d'activation : 0.
- `status` : `{}` ; membre de l'organisation ou super admin. Retourne uniquement l'état de configuration et les capacités de gestion, pas des contenus métier ni des secrets.
- `POST /identity/ai/generate` : `{organization_id, request_id, fixture}`. UUID de demande obligatoire ; seuls `connection` et `summary` sont admis. Le texte correspondant est défini sur le serveur. Tout champ supplémentaire, question libre, fournisseur ou URL client est refusé.
- `POST /identity/ai/cancel` : `{organization_id, request_id}` ; annule uniquement la demande de la même session et organisation. Réponse identique pour une demande inconnue. Une annulation arrivée avant la génération est conservée temporairement.

`authorize`, action RPC réservée à l'usage serveur mais contrôlée également en appel direct, vérifie MFA/session, organisation, appartenance non suspendue, module `assistant` autorisé/activé, accès commercial, permissions `read` et `write`, approbation fournisseur et version de l'activation. Aucune lecture ou génération métier automatique du super admin.

## Persistance et confidentialité

Migrations 141–142 : `uniion_private.ai_providers` et `ai_activations`, RLS activée et aucun accès direct public/anon/authenticated. RPC SECURITY DEFINER avec search_path vide, validation stricte et privilèges EXECUTE bornés. Les approbations/activations sont journalisées dans `uniion_security_events`, sans question ou réponse.

Les générations du lot A sont transitoires : pas de corpus, mémoire, index, fichier, historique ou réponse métier persistée. `core/ai.py` reste le contrat préparatoire pour les sources du lot B ; `adapters/ai_gateway.py` gère la politique et les questions de recette du lot A.

## Connecteur local

Activation technique explicite : `UNIION_AI_CODEX_FIXTURES=1`, en plus de la politique en base. Sans cette variable ou sans authentification ChatGPT disponible, le connecteur échoue sans fournisseur de secours. Ne pas ajouter de clé API au frontal.

Le connecteur lance le binaire Codex installé par `app-server --stdio`, avec un répertoire de travail vide et un CODEX_HOME temporaire privé contenant seulement une copie de l'authentification existante. Il ne copie ni configuration, ni plugins, ni MCP, ni mémoire, ni historique du compte. Le processus demande un thread éphémère, un sandbox lecture seule et aucun outil ; les fonctionnalités shell, applications, plugins, navigateur, ordinateur, agents, images et recherche sont désactivées. Une demande d'outil/approbation ou un événement d'outil reçu provoque un échec. Le processus et son répertoire temporaire sont fermés en sortie. Aucun secret n'est inscrit dans les preuves.

Le protocole a été vérifié contre le schéma JSON généré par le binaire installé et la [documentation officielle App Server](https://learn.chatgpt.com/docs/app-server). La connexion locale reste un appel à un service externe avec le compte ChatGPT ; elle n'est pas une inférence hors ligne. Seules les questions fictives autorisées ont été envoyées.

Les statuts fournisseur autres que `completed`, les réponses vides ou trop grandes, l'interruption et le délai de 120 secondes sont des échecs. Le message utilisateur ne révèle pas l'erreur brute du fournisseur. Aucune relance automatique. Les jetons et le coût restent `null` : aucune consommation inventée.

## Annulation et concurrence

Le BFF libère le verrou des sessions pendant l'appel Codex. Il revalide la session et la politique avant et après l'appel ; une déconnexion, une rotation de session ou un changement de politique empêche la restitution. L'annulation interrompt le processus dès qu'elle est observée par le lecteur du protocole. Elle ne promet pas de rembourser ni d'annuler une inférence déjà reçue par le fournisseur.

Deux appels simultanés maximum par processus. Limite de 10 demandes/minute/utilisateur et budget séparé de 30 annulations/minute. Anti-rejeu en mémoire sur l'acteur, l'organisation et l'UUID pendant 24 heures, borné à 2 048 entrées. Tombstones d'annulation par session pendant 180 secondes. **Ces mécanismes ne remplacent pas l'idempotence et les quotas durables du lot C**, notamment après redémarrage ou sur plusieurs instances.

## Interface et suite

Le parcours Réglages → Configuration IA conserve ses cartes, navigation, couleurs et composants. Les contrôles de clé/fournisseur simulés sont remplacés par l'approbation, l'activation et le test réels. Les garanties de localisation et les compteurs fictifs sont supprimés de cet écran. Le frontal n'utilise plus les anciens appels directs Anthropic/Claude/uniionLocal ni le stockage de clé `uniion.localLlm.v1` ; une éventuelle ancienne valeur n'est ni lue ni supprimée silencieusement.

La génération libre est explicitement indisponible. Le raccordement des sources, anonymisation, Assistant, mémoire, citations et actions unii reste dans B/D/E ; les anciennes autres démonstrations ne sont pas qualifiées par ce lot. Aucune clé ni sélection de fournisseur de production n'a été approuvée.

## Lot B — contexte autorisé (30 octobre 2026)

`POST /identity/ai/context` utilise les mêmes cookies, origine, CSRF, MFA et autorisation IA que la passerelle A. Actions : `catalog`, `preview` avec `sources`, `check` avec `snapshot`. Une référence contient `kind` (case/document/message), `id` UUID et, pour un message, `seq`. Pas de corps de document accepté depuis le navigateur. Limite : 8 sources, 120 passages par source et 24 000 caractères ; dépassement refusé, sans troncature silencieuse.

Les adaptateurs utilisent exclusivement `uniion_cases/get`, `uniion_documents/get` et `uniion_messaging/locate` avec le JWT courant. Projection : description et chronologie autorisée du dossier ; blocs textuels du document ; seul message sélectionné. Pièces jointes, images, charte, messages voisins, réponses citées et contenus transférés ne sont pas développés. Aucun accès direct aux tables métier par le service IA.

Chaque lecture fabrique une empreinte SHA-256 de la projection et de sa version. Toutes les dépendances sont relues avant envoi et après réponse. Un changement ou refus sur une seule source invalide le résultat entier, même si cette source n'est pas citée. Les lectures successives ne forment pas une transaction atomique avec le fournisseur : aucune révocation rétroactive d'un contenu déjà transmis n'est promise.

`generate` accepte également des références `sources`. L'envoi exige leur inscription privée dans `uniion_private.ai_recipe_sources` avec l'empreinte exacte. Migrations 143 et 144 : registre non accessible aux utilisateurs ; RPC `uniion_ai_recipe` vérifiant politique et droits courants de chaque source. Aucune API de certification ; le script de recette inscrit localement ses seules fixtures connues. Le registre ne confère jamais un droit de lecture. Une modification de contenu nécessite une nouvelle certification locale explicite.

Le masquage normalise Unicode, retire le balisage actif et remplace les noms connus des métadonnées autorisées, courriels, téléphones reconnus, URL, UUID, IBAN et NIR. Correspondances temporaires par requête, sans table de réidentification renvoyée. **Ce masquage est partiel, pas une anonymisation exhaustive.** La certification fictive reste obligatoire indépendamment du masquage.

Le fournisseur reçoit des passages masqués identifiés S1/P1, pas les références UUID ni les titres. Sa sortie doit être un JSON strict d'extraits littéraux : aucune prose libre, clé supplémentaire, citation inconnue ou extrait absent accepté. Le serveur rattache titre, emplacement et version ; le rendu texte ne donne aucun pouvoir aux instructions contenues dans les sources. Une citation exacte n'est pas une preuve de pertinence juridique ni une vérification factuelle.

Le résultat conserve toutes les dépendances D12 et n'autorise aucune diffusion. Pas d'historique, index, mémoire ou cache durable créé dans B. L'interface recontrôle le résultat toutes les 10 secondes et l'efface sur refus, indisponibilité, navigation, déconnexion ou masquage de l'onglet. Ce délai n'est pas une révocation instantanée d'un affichage déjà reçu. Assistant, quotas durables et actions métier restent aux lots C–E ; restauration et recette globale à F.

## Lot C — exécutions et consommation durables (30 octobre 2026)

Le point d'entrée local `python -m uniion.app` injecte désormais un `RunLedger` persistant dans `.local-ai/runs.sqlite3`. Migration locale explicite `uniion/adapters/ai_runs_v1.sql`, version de schéma 1, permissions répertoire/fichier 0700/0600, synchronisation complète. Les fabriques de tests sans registre injecté utilisent une base en mémoire isolée ; elles ne constituent pas le lancement persistant du produit. Aucun privilège Supabase supplémentaire ni clé de service ajouté : politique et sources restent vérifiées avec le JWT utilisateur.

Choix de portée : registre d'exécution local à l'instance, comme le stockage local de sessions existant, distinct des ressources Supabase. Plusieurs processus partageant le même fichier sont sérialisés par `BEGIN IMMEDIATE`. Plusieurs hôtes ou copies indépendantes de ce fichier ne partagent pas leurs quotas ; ce déploiement n'est pas qualifié. La base est privée du serveur, pas exposée via REST/Supabase.

Clé durable : organisation + acteur authentifié + UUID de requête. L'identifiant n'est jamais libéré ou réutilisé, même après changement de jour ou redémarrage. Empreinte de la demande conservée, sans question, réponse, référence de source en clair, jeton de session ou secret fournisseur. Un doublon (y compris corps différent) est refusé sans rappel fournisseur. Pas de relecture du texte depuis le registre : l'historique de contenu relève de D. Une réussite dont la réponse HTTP a été perdue reste une réussite enregistrée, pas une invitation à régénérer.

États : `pending` à la réservation ; `running` juste avant invocation du connecteur ; `succeeded` après réponse et contrôles ; `failed` si traitement refusé ; `cancelled` sur annulation ; `uncertain` sur exception après tentative d'appel ou expiration d'une exécution engagée. Le journal de transitions est append-only par le service. Une réponse tardive ne peut promouvoir un état terminal.

Quota de recette serveur : 100 demandes réservées ou engagées par organisation et par jour UTC. Deux exécutions actives maximum pour le connecteur de l'instance entière. Ces valeurs sont des limites techniques de recette, pas une offre commerciale ni un plafond financier. Réservation et vérification des plafonds dans la même transaction. Avant invocation : échec/annulation libère la réservation. Après tentative d'invocation : unité conservée, même si coût inconnu, annulation ou refus de restitution. Une annulation engagée conserve également son emplacement concurrent jusqu'à arrêt du worker ou expiration. Le jour de la réservation porte l'unité, y compris en cas de passage à minuit.

Les baux sont de 180 secondes, supérieurs au délai fournisseur de 120 secondes. La prochaine transaction réconcilie les exécutions expirées : attente non engagée → échec et réservation libérée ; appel engagé → incertain et unité conservée. Aucun worker de reprise ni renvoi automatique. Le connecteur interroge le signal d'annulation durable au plus une fois par seconde ; cela ne garantit pas l'arrêt distant d'une inférence déjà reçue.

`POST /identity/ai/runs` : `{organization_id, request_id?}`. Même session/MFA/origine/CSRF et politique de génération que les appels IA. Retour : quota journalier agrégé de l'organisation, jusqu'à dix états de l'acteur courant (ou l'état de son identifiant demandé), sans résultat ni identité d'un autre utilisateur. `usage` et `cost` sont `null`, pas zéro ni estimation calculée à partir du texte. Aucun endpoint client ne permet d'écrire un état, un quota ou une consommation. L'annulation est autorisée au seul acteur authentifié et ne donne aucun accès métier, même si les droits ont été retirés entre-temps.

Configuration IA réutilise la carte Consommation, affiche demandes réservées/engagées, disponibilités, jetons/coût inconnus et dernier état connu. Actualisation à l'ouverture et après génération, ou par « Actualiser le suivi ». L'erreur de suivi est affichée comme indisponibilité, jamais comme compteur nul. Pas de stockage navigateur ajouté.

Conservation : aucune purge automatique. Le fichier contient des métadonnées personnelles (identifiants et dates) et doit être inclus dans la future politique de sauvegarde validée. Copie cohérente via API SQLite backup testée en environnement isolé ; restauration globale, chiffrement des sauvegardes et objectifs D07 restent à qualifier en F. Restaurer une sauvegarde antérieure peut perdre des tombstones : aucune remise en route de traitements ni prétention d'idempotence après restauration périmée sans rapprochement.

## Lot D — Assistant, historique et mémoire (30 octobre 2026)

Migration locale `ai_history_v2.sql` : réponses chiffrées AES-GCM, préférences de mémoire et versions dans le même registre serveur que C. Le fichier de clé `.local-ai/runs.history.key` est distinct, privé 0600 ; sa perte avec des réponses existantes bloque le démarrage, sans remplacement silencieux. L'AAD lie chaque réponse à organisation, acteur et requête ; le remplacement de ciphertext entre lignes échoue. Organisation, acteur, dates et indicateurs restent des métadonnées en clair dans le fichier privé. Le chiffrement ne protège pas contre un administrateur de l'hôte détenant la clé.

La réponse et l'état réussi sont enregistrés dans une seule transaction, après les contrôles B. Un échec de chiffrement/écriture n'annonce pas de réussite ; une réponse annulée, expirée ou refusée n'est pas enregistrée. La réponse chiffrée contient les extraits masqués, citations et toutes les empreintes de sources. Aucune question libre ni texte de mémoire fourni par le navigateur n'est accepté pour l'inférence.

`POST /identity/ai/assistant` : même authentification/MFA/origine/CSRF. Champs communs `organization_id`, `action`. Actions :

- `generate` avec `request_id`, `sources` : recette extractive fictive, quotas et anti-rejeu C ; réponse persistante.
- `list` sans autre champ : au plus 50 demandes récentes accessibles, plus les réponses mémorisées accessibles (8 maximum), et préférence de mémoire. Aucun titre métier d'une réponse devenue inaccessible n'est retourné.
- `read` avec `id` : déchiffrement privé, relecture de toutes les sources, comparaison d'empreintes, vérification de certification et politique avant restitution.
- `remember` avec `id`, `version`, `enabled` booléen : conserver/retirer une référence de mémoire après revalidation. Maximum 8 réponses retenues.
- `configure` avec `version`, `enabled` booléen : activation explicite de la mémoire du compte dans cette organisation ; désactivée initialement.
- `archive` avec `id`, `version` : masque la demande dans l'historique actif et retire sa référence de mémoire. Aucun contenu supprimé ni purge automatique ; conservation D07 non contournée.

L'acteur provient toujours de la session. Aucun champ utilisateur/propriétaire, résultat, statut, empreinte ou texte libre ne peut être imposé par le client. Les versions préviennent les modifications concurrentes silencieuses. Le super admin ne devient pas lecteur des historiques d'autrui. Les lectures restent conditionnées à la politique IA active ; une désactivation fournisseur peut donc empêcher temporairement leur consultation.

La mémoire ne réinjecte pas aveuglément le texte d'une ancienne réponse : elle ajoute les références de ses sources à la sélection de la nouvelle demande, relit et recertifie les projections courantes, et impose toutes leurs restrictions. Une mémoire dont la source est modifiée/révoquée fait refuser la génération avec mémoire active ; elle n'est pas silencieusement abandonnée. La suspension globale permet de repartir sans ces références. Le changement de préférence ou d'une référence mémorisée pendant une génération fait refuser sa restitution. Plus de huit sources cumulées entraîne un refus, sans troncature.

L'Assistant conserve la disposition existante, mais remplace les demandes juridiques et faits préremplis simulés par une synthèse de sources fictives certifiées. Une entrée libre reçoit un refus local, sans transmission. Chaque demande constitue une entrée d'historique ; il ne s'agit pas encore d'une conversation juridique libre multi-tours. « Mémoriser », « Relire », suspension et désactivation opèrent sur le serveur. Les actions vers les dossiers restent au lot E et indiquent leur indisponibilité.

Le module frontal ne place pas les réponses dans l'état historique persistant du contrôleur. Les anciennes clés locales `aiConvs/aiConvId/aiMem/aiMemOn` ne sont ni chargées ni envoyées ni remplacées par les nouvelles réponses ; si elles existent déjà, elles sont conservées sans usage pour éviter une suppression implicite de travail ancien. Aucune migration de ces données potentiellement réelles n'est effectuée.

Les écrans actifs relisent historique/mémoire toutes les dix secondes ; la réponse ouverte est revalidée. Navigation, changement d'identité, annulation et masquage de l'onglet effacent les contenus affichés et invalident les retours tardifs. L'indisponibilité d'une vérification efface les données à l'écran. Le délai de polling et une inférence déjà reçue par le fournisseur ne permettent pas une révocation instantanée rétroactive.

Sauvegarde/restauration globale D07, rotation de clé, flux métier E et qualification globale F restent ouverts. Une sauvegarde du seul fichier SQLite ne suffit pas à restaurer le contenu : la clé associée est nécessaire et doit faire partie d'une procédure de sauvegarde chiffrée séparée. Aucun hébergement de production ni conformité générale revendiqué.

## État consolidé — clôture locale S08, 31 octobre 2026

Les sections A–D ci-dessus décrivent leurs livraisons successives. Le présent état prévaut pour les capacités ajoutées depuis : conversation libre fictive, actions métier, rôles et objets natifs. Le choix et l’admission des fournisseurs de production sont reportés par l’utilisateur au dernier sprint (S16), avant toute utilisation réelle. Les contrôles D09 restent obligatoires ; ce report n’est pas une activation.

- `/identity/ai/actions` : catalogue, réglages versionnés, attribution de rôles sous habilitation distincte, génération des 37 actions et des sept artefacts spécialisés. Une génération accepte une référence native, pas le contenu métier fourni arbitrairement par le navigateur. Les actions de liste sont bornées à huit sources.
- `/identity/ai/chat` : précontrôle d’éligibilité à la recette interactive, puis question fictive, références et éventuel parent. Huit sources/tours maximum ; historique privé chiffré, dépendances cumulatives et revalidation du parent. Les organisations non inscrites explicitement restent refusées.
- `/identity/ai/assistant`, action `create_case` : identifiant/version d’une réponse persistée. Le dossier créé reste privé et dépend de toutes les sources, y compris les contributeurs du contexte d’organisation. Un partage générique ne lève pas cette restriction.
- `/identity/ai/drafts` : correction, relecture, application explicite et reçu idempotent. L’application modifie le brouillon autorisé, jamais une destination imposée par une instruction du modèle. Une modification de source invalide l’ancienne réponse.
- `/identity/business` : objets natifs appartenant à leur organisation, accès par module et ressource, sauvegarde sous version attendue. Publications locales distinctes, relecture par un second acteur, permission de diffusion et audience explicite. Révocation possible d’une ancienne version publiée. Aucun push externe.

Le générateur Documents enregistre dans le service Documents puis ouvre l’éditeur de ce document ; il n’expose pas une copie locale non suivie. Intranet enregistre son texte structuré et son chapô ; l’aperçu des pages serveur ne rajoute pas les dates, coordonnées ou horaires du prototype. Le projet de PV est enregistré sur la réunion et consultable dans le panneau unii ; les traitements audio/transcription et la chaîne complète de PV relèvent de S09. Les options de sondage sont persistées, mais la collecte des votes relève de S10.

Les garde-fous frontaux écartent les réponses tardives après navigation, empêchent une double préparation simultanée et recontrôlent les sources et listes. La revalidation périodique reste de dix secondes, sans promesse de retrait instantané d’un texte déjà vu. Les publications consultables ne révèlent l’identifiant de source que si le lecteur possède déjà le droit de la lire.

Source de vérité pour les preuves, limites et reports : `preuves/S08-F-final/CLOTURE.md` et `preuves/S08-F-final/RESERVES.md`. Le registre reste mono-instance local ; coûts et jetons restent inconnus. Aucun déploiement ni transfert de données réelles n’est autorisé par cette clôture.
