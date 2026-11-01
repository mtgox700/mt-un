# Suivi du chantier — mise en production uniion

Démarré le 17 octobre 2026. ✅ fait · 🟡 commencé · ⬜ à faire · 👤 action côté client

## Lot 0 — Socle (2 sem.)
- ✅ Dépôt structuré : `infra/`, `supabase/`, `front/`, CI
- ✅ Script d'installation VPS : durcissement SSH, ufw, fail2ban, mises à jour auto, Docker, Supabase, Caddy, secrets générés
- ✅ Caddy : TLS auto, HSTS, CSP stricte, API filtrée, Studio fermé
- ✅ CI : gitleaks, migrations depuis zéro, pgTAP, contrôle « aucune table sans RLS », tests du masquage, build avec garde-fou
- ✅ Déploiement avec approbation manuelle et retour arrière en une commande
- 🟡 Front React + Vite : connexion, double authentification, garde d'organisation — écrans métier à porter (lot 3)
- 👤 Commander le VPS (4 vCPU / 16 Go / 160 Go NVMe) + un petit VPS de supervision ; DNS `app.` et `api.`
- 👤 Ouvrir le dépôt Git et ses secrets (`VPS_SSH_KEY`, `POSTGRES_PASSWORD`, variables `VPS_HOST`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`)
- ✅ Environnements recette et production (`infra/ENVIRONNEMENTS.md`) : `main` → recette automatique, étiquette `v*` → production avec approbation, sonde de santé après chaque déploiement
- 👤 Commander un 3ᵉ petit VPS pour la recette ; créer les environnements GitHub `recette` et `production`

## Lot 1 — Sécurité & données (3 sem.)
- ✅ Schéma de référence migré (14 migrations versionnées)
- ✅ Hook de jeton : organisation et personne dans le JWT, bascule multi-organisation
- ✅ RLS sur toutes les tables, cloisonnement restrictif, périmètre de dossier, visibilité d'agenda — **défaut du schéma d'origine corrigé**
- ✅ Droits retirés à `anon`, ouverts colonne par colonne
- ✅ Adhérents par fonctions journalisées, trésorier + double authentification, agrégats à seuil de 5
- ✅ Journal d'audit en ajout seul, empreinte chaînée
- ✅ Chiffrement applicatif (Edge Function `coffre`) : notes, détail de dossier, conversations d'assistant, messages
- ✅ Buckets privés `media`, `pieces`, `exports` et leurs politiques
- ✅ Durées de conservation : 25 règles quotidiennes tracées, désactivation horaire en fin de mandat
- ✅ Edge Function `membres` : ouverture d'organisation (2 admins minimum), invitation (sièges, 2 trésoriers max), rôles (2 admins conservés), fin de mandat (réattribution des dossiers, coupure des sessions), réinitialisation de la double authentification, bureau — tout journalisé
- ✅ Edge Function `pieces` : types autorisés, 80 Mo, ClamAV, empreinte, chiffrement lié à la pièce, téléchargement déchiffré en flux (pas d'URL), journal d'accès, corbeille
- ✅ Conteneur ClamAV interne (aucun port publié)
- ✅ Edge Function `file-taches` (chaque minute via pg_cron) : purge des fichiers échus, réanalyse antivirus, envois e-mail ; reprise exponentielle, abandon à 6 essais
- ✅ Diffusions aux adhérents : `api.campagne_envoyer` (trésorier/admin + double authentification), consentement et désinscription **revérifiés à l'envoi**, lien de désinscription en un clic + en-tête List-Unsubscribe, suivi agrégé
- ✅ 30 tests pgTAP : cloisonnement (14) + fonctions métier et couverture RLS (16)
- ✅ 22 tests pgTAP du lot 3 (`lot3.test.sql`) : dossiers, import, agenda, documents
- ✅ 28 tests pgTAP (`lot3b.test.sql`) : pages (relecture ≠ auteur), médias, extensions, trésorerie (migration 13), rétention (dates simulées)
- ✅ Migration 14 : **deux failles corrigées**, trouvées en écrivant ces tests — un auteur pouvait publier sa page sans relecture ; un média pouvait pointer vers le fichier d'une autre organisation et le faire purger à 30 jours
- ✅ Import CSV d'adhérents côté serveur : `api.adherents_importer` (simulation puis import, validation ligne à ligne, doublons, rapport sans donnée nominative, consentement jamais présumé, journal)

## Lot 2 — Passerelle IA (1,5 sem.)
- ✅ Edge Function `ai-ask` : surfaces contrôlées, filtre méta, quota, contrôle de périmètre du dossier
- ✅ Masquage serveur : motifs + dictionnaire de l'organisation + civilités + détection de nom résiduel → refus
- ✅ Prompts versionnés, journal sans contenu, alias de modèle
- ✅ Client : `demanderUnii()` + ré-identification locale (la table de correspondance ne quitte pas l'appareil)
- ✅ Textes piégés : **61 cas** (42 pièges, 10 textes légitimes, injections). Masqueur renforcé : nom en début de phrase, nom en capitales, « M Leroy », initiale, prénom seul en contexte RPS, noms du dictionnaire à une faute près, nom dans une adresse e-mail, e-mail déguisé, URL, 0033, immatriculation, âge
- ⚠ Limite documentée : nom inconnu tout en minuscules (parade : dictionnaire de l'organisation)
- 👤 Contrat Mistral AI : zéro rétention, pas d'entraînement, hébergement UE ; clé d'API
- ✅ Corpus de référence versionné (`ai-ask/corpus.ts`, `ctrav-2026-10.1`) : 32 articles, injecté dans les prompts, interdiction d'inventer un numéro d'article, réserve affichée tant qu'il n'est pas validé ; la CI bloque une version de production non validée
- 👤 Faire vérifier chaque article sur Légifrance par un juriste (renseigner `verifie_le`) ; ajouter les conventions collectives des organisations pilotes

## Lot 3 — Modules cœur (4 à 6 sem.)
- ✅ Jetons de couleur réparés (`tokens.css` : les `--ac*` contenaient du code au lieu de valeurs)
- ✅ Coque : barre latérale (bureau), barre basse (mobile), profil, déconnexion
- ✅ Accueil : échéances du référent, raccourcis
- ✅ Dossiers : tableau 3 colonnes, glisser-déposer + flèches clavier, recherche, catégorie, création ; concurrence optimiste (conflit signalé, rien n'est écrasé)
- ✅ Dossier : en-tête modifiable, état, contentieux, suppression (référent), détail confidentiel et notes chiffrés, pièces (dépôt multiple, attente antivirus rafraîchie seule, aperçu / téléchargement en mémoire, corbeille), historique, périmètre d'accès
- ✅ Assistant : général (non conservé) et par dossier (conservé chiffré), refus de masquage expliqué, « texte réellement envoyé » consultable
- ✅ Migration 9 : identifiants et référent posés par la base, insertion colonne par colonne, version et historique d'état tenus par déclencheurs, vue `api.collegues`
- ✅ Adhérents : effectifs agrégés (seuil 5) pour admin et trésorier, liste nominative trésorier seul (recherche temporisée : chaque lecture est journalisée), fiche en panneau, création, suppression motivée
- ✅ Import CSV : lecture locale (UTF-8 ou Windows-1252, ; ou ,, alias de colonnes), vérification serveur, import, modèle téléchargeable
- ✅ Membres : invitation, rôles (garde-fous 2 admins / 2 trésoriers remontés du serveur), bureau, réinitialisation double auth, fin de mandat avec repreneur ; alertes « invitation en attente » et « double auth. non activée »
- ✅ Réglages : profil (téléphone, visibilité des coordonnées), double auth facultative, mot de passe avec code e-mail, déconnexion globale, bascule d'organisation, thème
- ✅ Migration 10 : `api.adherents_importer`, `api.membres_lister`, `api.mon_profil`
- ✅ Agenda : mois (grille, pastilles sur mobile), « à venir », types, visibilité filtrée serveur, invités (membres actifs uniquement), réponses présent/absent, dossier lié, export .ics local
- ✅ Documents : modèles (page blanche, tract, compte rendu, courrier), éditeur de blocs avec enregistrement automatique et concurrence optimiste, styles uniion Studio (palettes, polices, formats, emplacements d'image), aperçu paginé, impression / PDF au format exact, statuts brouillon → relu → diffusé (« signé » réservé au prestataire)
- ✅ Rédaction avec unii : proposition complète en blocs, acceptée ou non ; jamais d'image envoyée
- ✅ Migration 11 : surfaces IA manquantes dans le type (le journal échouait), valeurs par défaut et colonnes autorisées pour agenda / documents / médias, version tenue par la base, invités hors organisation refusés, signature non forgeable, `api.extensions_actives`
- ✅ Ré-identification sur tout l'échange (historique compris) : la passerelle renvoie chaque morceau masqué, l'appareil les aligne
- ✅ Migration 12 : **correctif** — politiques agenda mutuellement récursives (erreur à la première lecture), remplacées par des fonctions security definer
- ✅ Chargeur d'extensions : registre en base, fichier `/ext/` uniquement, SRI, signature Ed25519 de l'éditeur (`VITE_EXT_CLE_PUBLIQUE`), manifestes hors registre refusés, éléments désactivables un à un
- ✅ Réglages › Extensions (administrateur) : activer, passer à la version publiée, désactiver, couper un style ou un bloc
- ✅ `infra/publier-extension.sh` : empreinte SRI + signature Ed25519 → SQL du registre
- 👤 Générer la clé de l'éditeur, signer Studio 1.2.0, renseigner `VITE_EXT_CLE_PUBLIQUE`
- ✅ Photos : bucket privé `media`, réduction à 1 400 px et réencodage WebP (EXIF supprimé), question « personne reconnaissable » + accord écrit, affichage par URL locale libérée à la fermeture
- ✅ Aides de démo du prototype (`anonSendClear`, `npSimulateApproval`, écran Clé API, réinitialisation) : non portées, absentes de la production
- ↪ Libellés messagerie « chiffrée en transit et au repos » et badge DREETS : à appliquer en portant ces écrans (lot 6)
- ✅ PWA : installable, coque hors ligne, **aucune donnée métier en cache** (choix plus sûr qu'un cache chiffré), purge du cache et de la mémoire à la déconnexion, bandeau « hors ligne »
- ✅ Trésorerie : synthèse annuelle, retards, saisie des versements depuis la fiche adhérent, attestations fiscales générées et imprimables (mention art. 199 quater C du CGI ; plus de « PDF signé » fictif)
- ✅ Diffusions : listes à critères recalculées à l'envoi, effectif joignable (masqué sous 5 hors trésorier), composition avec {prenom}, programmation, envoi confirmé (trésorier / admin), suivi agrégé
- ✅ Migration 13 : fonctions trésorerie, attestations, effectifs, critères

## Lot 4 — Conformité & exploitation (1,5 sem.)
- ✅ Scripts de sauvegarde et de test de restauration, crontab
- ✅ Sonde de santé (base, rétention, file, taux d'échec IA)
- 🟡 Polices : Studio rebranché sur `/fonts/studio.css` — **fichiers woff2 à déposer**
- 👤 Stockage objet chez un 2ᵉ fournisseur pour les sauvegardes ; compte Brevo + domaine expéditeur authentifié (SPF, DKIM, DMARC)
- 👤 AIPD, registre des traitements, mentions d'information, DPA (hébergeur, Mistral, Brevo)
- ✅ Uptime Kuma sur VPS de supervision (`infra/supervision/`) : 8 sondes, battements de sauvegarde et de disque
- ✅ Correctif : la sonde de santé appelait une fonction inexistante (aurait répondu 503 en permanence) — migration 14
- ⬜ 5xx, latence p95, échecs d'authentification par compte : Grafana + Loki sur les journaux Caddy (Kuma ne mesure pas des taux)
- ⬜ Premier test de restauration avec compte rendu signé (dès que le VPS et le stockage existent)

## Lot 5 — Recette & pilote (2 sem.)
- ✅ `RECETTE.md` : couverture des 30 critères et 6 scénarios (auto / manuel / lot 6)
- ⬜ Passages manuels de recette ; audit d'accessibilité RGAA ; test d'intrusion externe
- ⬜ Pilote : 1 organisation, données réelles, 2 administrateurs minimum

## Lot 6 — Modules suivants (8 à 12 sem.)
- ⬜ Messagerie bout en bout · Réunions (audio) · Intranet / thèmes web · Sondages · Reporting · Formations · Abonnement · Console super-admin
