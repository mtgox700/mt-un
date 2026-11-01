# Audit de transmission et de mise en production — uniion

Version 3 — **1er octobre 2026**. Portée : `uniion App.dc.html` (13 537 lignes, 1,19 Mo) et le présent
dossier. Remplace l'audit du 5 septembre 2026 (≈10 000 lignes), devenu partiel : l'application a doublé
depuis, et la copie du prototype rangée dans ce dossier datait de cette version (582 Ko). **Elle est
remplacée par la version courante.**

Le §0 donne le verdict. Le §1 liste ce qui **bloque la mise en production**. Le §2 liste ce qui manquait
au dossier de transmission et a été complété aujourd'hui. Les §3 à 6 sont l'état technique du
prototype.

---

## 0. Verdict

| Question | Réponse |
|---|---|
| Le développement peut-il démarrer ? | **Oui.** Interface complète, 57 routes, 47 cibles de navigation toutes résolues, aucune erreur console, CRUD complet. |
| Le dossier de transmission est-il à jour ? | **Oui, depuis cette version.** Les modules ajoutés depuis le 5 septembre sont désormais spécifiés (§2). |
| Le prototype peut-il être mis en ligne tel quel ? | **Non.** C'est une maquette fonctionnelle : aucun serveur, données en clair dans le navigateur, clé d'IA côté client, promesses d'interface non tenues. Voir §1 — 9 bloquants. |
| Décisions client encore ouvertes | 4 : usage mobile, hébergement du modèle, agrément des formations, canal légal des diffusions aux adhérents (§1.9). |

---

## 1. Bloquants de mise en production

Chaque point doit être **levé ou retiré de l'interface** avant ouverture à de vrais utilisateurs.

### 1.1 Clé d'IA et prompts dans le navigateur — **critique**
`llmText` / `llmJson` appellent `api.anthropic.com` depuis le client avec
`anthropic-dangerous-direct-browser-access` et une clé stockée en clair dans `localStorage`
(`uniion.localLlm.v1`, écran Réglages › Clé API). Prompts système, corpus et règle de sourçage sont
lisibles par quiconque ouvre les outils du navigateur.
**À faire :** passerelle serveur unique `POST /ai/ask` (`API.md` §2 et §6). Supprimer l'écran `apikey`
et toute saisie de clé côté utilisateur. Le client n'envoie que du texte déjà masqué et des références.

### 1.2 Toutes les données en clair dans le navigateur — **critique**
`persist()` écrit **41 clés d'état** dans `localStorage` (`uniion.demo.v4`), sans chiffrement :
adhérents (appartenance syndicale, art. 9 RGPD), dossiers (harcèlement, santé), messages, mémoire de
l'assistant, conversations IA, sessions de formation, carte bancaire masquée, comptes de la console
d'administration.
**À faire :** persistance serveur exclusivement. Le seul stockage local admis est le cache hors ligne
chiffré décrit dans `SECURITE.md`, purgé à la déconnexion (`RECETTE.md` critère 4).
**Spécificité :** l'historique IA et la mémoire de l'assistant sont présentés comme « stockés dans ce
navigateur ». En production, choisir : serveur chiffré par utilisateur (recommandé, multi-appareil) ou
local chiffré. Dans les deux cas, revoir les libellés.

### 1.3 Promesses d'interface non tenues — **critique, risque juridique**
| Libellé affiché | Où | Réalité du prototype | Action |
|---|---|---|---|
| « Chiffrée de bout en bout — ni l'employeur ni uniion ne peuvent les lire » | Messages (liste, fil, accueil vide) | Aucun chiffrement ; texte en clair dans `localStorage` | Implémenter E2E (MLS/Signal) **ou** reformuler en « chiffré en transit et au repos » |
| « Agréée DREETS » | Formations › généralistes (6 fiches) | Mention reprise du catalogue fourni | Vérifier l'agrément réel et son numéro, sinon retirer le badge |
| « Attestation de suivi » | Fin de session unii | Simple message de confirmation | Générer un PDF horodaté **sans valeur de formation agréée** (à libeller ainsi) |
| « Modèle souverain, sans entraînement » | Sécurité de l'IA | Dépend du contrat | Inchangé depuis la v2 : tenir par contrat ou reformuler |
| Connexion, MFA, SSO | Écrans d'authentification | Fictifs : tout identifiant passe | Auth réelle (`SECURITE.md`) |
| Paiement par carte, factures | Réglages › Abonnement | Carte et factures fictives | Prestataire de paiement, aucune donnée de carte chez uniion |

### 1.4 Anonymisation heuristique côté client
`maskText` (12 appels) repère des motifs dans le navigateur. Elle est contournable et non journalisée.
Les surfaces IA sont passées de 5 à **9** : assistant, dossier, documents, intranet, réunions,
@unii dans Messages, dossier guidé, création de dossier depuis un message, Formations (plan, relecture
d'exercice, questions).
**À faire :** masquage serveur de référence, refus si résidu, jeu de 50 textes piégés (`RECETTE.md` §1 critère 9),
étendu aux 9 surfaces.

### 1.5 Aides de démonstration encore présentes
- `anonSendClear` (Assistant) : envoi **non masqué**. Supprimer.
- `npSimulateApproval` (Nouveau sondage) : validation simulée par un pair. Supprimer.
- Interrupteur de console d'administration accessible depuis l'application : la console super-admin
  doit être une application séparée, sur un domaine distinct, avec authentification dédiée.

### 1.6 Diffusion aux adhérents depuis la messagerie
Depuis le 30 septembre, « Envoyer un message » (Adhérents) crée une conversation de diffusion dans
Messages, et un message écrit dans ce fil part en notification aux N adhérents. En production, chaque
envoi doit :
- passer par la file d'envoi persistante (`API.md` §6.3), avec états et désinscription ;
- vérifier, **à l'envoi et non à la création de la liste**, l'opposition et le consentement par canal ;
- être consigné au journal des envois avec le canal et le nombre réel de destinataires (le prototype
  consigne un compte théorique).

### 1.7 Polices chargées depuis Google Fonts
Cinq familles (Philosopher, Inter, Caveat, Montserrat, Lora) sont appelées depuis
`fonts.googleapis.com` : chaque militant transmet son adresse IP à un tiers. Héberger les polices,
ne garder que celles réellement utilisées par les présets de marque.

### 1.8 Contenus générés par l'IA à valeur juridique ou pédagogique
- **Formations** : le parcours, le cours, le quiz et sa bonne réponse sont produits par le modèle.
  L'index de réponse n'est que borné. Afficher « Contenu généré par unii — non validé par un formateur »,
  garder le versionnage du prompt, prévoir un signalement d'erreur par module.
- **Dossiers créés depuis un message ou une conversation** : titre, catégorie, échéance et plan sont
  proposés par l'IA. Ils doivent rester modifiables, ce qui est le cas, et être marqués comme proposés.

### 1.9 Décisions client
1. **Usage mobile** : Messages et Formations sont utilisables en une colonne, mais aucun parcours
   mobile n'a été validé (inchangé).
2. **Hébergement du modèle** (inchangé).
3. **Agrément des formations** : quelles formations sont réellement délivrées, par quel organisme, et
   selon quelles modalités d'inscription ? Le bouton « Demander une session » n'aboutit aujourd'hui à
   aucun destinataire.
4. **Canal légal des diffusions** : la notification dans l'application suffit-elle, ou faut-il un e-mail
   avec désinscription ? Ce choix détermine les mentions d'information des adhérents (`JURIDIQUE.md`).

---

## 2. Écarts du dossier de transmission — comblés le 1er octobre

| Module ajouté depuis le 5 septembre | Spécifié dans |
|---|---|
| Messagerie v2 : contacts, groupes avec administrateurs, diffusions, filtres, réponse citée, réponse en privé, transfert, versement en dossier, sourdine, épingle | `MODELE_DONNEES.md` §v3, `API.md` §6.1, `AUTORISATIONS.md` §5, `ETATS.md` §4 |
| Réglages › Contacts & groupes | idem |
| @unii dans Messages (sélection, actions rapides, réponses privées) | `API.md` §6.2, `AUTORISATIONS.md` §5 |
| Historique des conversations IA, origine par surface, plein écran | `MODELE_DONNEES.md` §v3 |
| Mémoire de l'assistant (catégories, activation, injection) | `MODELE_DONNEES.md` §v3, `AUTORISATIONS.md` §5 |
| Dossier guidé, création de dossier depuis une conversation ou un message | `API.md` §6.2 |
| Formations : 2 catalogues, demandes de session, sessions unii | `MODELE_DONNEES.md` §v3, `API.md` §6.4, `ETATS.md` §4, `RECETTE.md` §6 |
| Abonnements Élu 1.0 à 4.0, console super-admin | déjà décrits en v2 ; console à séparer (§1.5) |
| Menu latéral réductible | `ETATS.md` §4 (préférence d'interface) |

---

## 3. Résultat de l'audit automatique du prototype

| Contrôle | Résultat | Commentaire |
|---|---|---|
| Routes | 57 | 19 écrans portent un `data-screen-label` explicite |
| Cibles `go()` | 47, **toutes résolues** | aucun lien mort |
| Table `tabOf` | 36 entrées | 11 routes absentes : 7 de la console admin (shell séparé, normal) et `raccourcis`, `notifs`, `recherche`, `viewer`, pour lesquelles l'onglet actif n'est pas défini — à rattacher |
| Minuteurs | 17 `setTimeout` / 23 `clearTimeout`, 6 `setInterval` / 13 `clearInterval` | libérés |
| Écouteurs | 6 `addEventListener` / 7 `removeEventListener` | libérés au démontage |
| Appels IA | 6 `llmText`, 8 `llmJson`, 1 `fetch` direct | tous via les deux fonctions : point de bascule unique vers la passerelle |
| Notifications éphémères | 209 appels à `flash()` | pas de région `aria-live` : à ajouter |
| Dates en dur | 66 occurrences de « 2026 » (données d'exemple), 12 libellés « Aujourd'hui » stockés tels quels dans des historiques | stocker en ISO 8601, formater à l'affichage |
| Couleurs en dur dans le gabarit | 283 hexadécimaux | passer par `tokens/` |
| Champs de saisie sans `aria-label` | 65 | une partie est enveloppée dans un `<label>` ; contrôle RGAA à faire |
| Boutons-icônes sans nom accessible | 29 | à corriger |
| Images sans `alt` | 0 | — |
| `innerHTML` / `eval` | 0 | — |

---

## 4. Dette technique et architecture cible

- **Monolithe** : un composant, 259 méthodes, 154 lignes d'état initial. À découper par domaine
  (auth, dossiers, adhérents, messagerie, IA, formations, sites, admin) avec un store par domaine.
- **Persistance par fusion d'identifiants** (`SEED_MERGE_KEYS`) : propre au prototype, à ne pas porter.
- **Données d'exemple dans le code** : `ADHERENTS`, `DOSSIERS`, `CONVOS`, `CONTACTS`, `CONVO_META`,
  `FM_IA`, `FM_GEN`… Les catalogues de formation deviennent du contenu administrable (§6.4 de `API.md`) ;
  le reste relève de `SEED.md`.
- **Identité de l'utilisateur en dur** : `c-me` / « Sophie Marchand » dans la messagerie et les journaux.
  À remplacer par la session.
- **Correspondance contact ↔ auteur** : « Répondre en privé » retrouve l'auteur d'un message de groupe par
  prénom et initiale. En production, chaque message porte un `auteur_id`.
- **Pagination** : seuls les adhérents sont paginés. Messages, conversations IA, sessions de formation,
  journaux à paginer côté serveur (curseur).
- **Défilement de fil** : géré dans `componentDidUpdate`. En production, conserver la position quand
  l'utilisateur lit plus haut et afficher « nouveaux messages ».
- **i18n** : chaînes françaises en dur et dictionnaire de vocabulaire `W` (CSE / section). Fusionner en
  un catalogue unique.

## 5. Actions encore non fonctionnelles (à brancher)

| Action | Écran | À implémenter |
|---|---|---|
| `repShare` | Reporting | Lien signé, expiration 30 jours |
| `wcSaved` | Charte des sites | Persistance du gabarit |
| `sigNotify` | Signature | Notification des cosignataires |
| Facturation | Abonnement | Prestataire de paiement |
| Invitations, export ICS | Agenda | Envoi ICS, flux signé en lecture seule |
| Pièce jointe (`attach`) | Messages | Téléversement chiffré, analyse antivirus |
| Demander une session | Formations | Transmission au bureau ou à l'organisme, suivi de statut |
| Attestation de suivi | Formations | PDF horodaté (§1.3) |
| Copier le texte | Messages | Fonctionne ; prévoir le repli si l'API presse-papiers est refusée |

## 6. Ordre de développement conseillé (mis à jour)

1. Socle : authentification MFA, rôles serveur, journal d'audit, cloisonnement, type d'organisation.
   **Console super-admin séparée.**
2. Passerelle IA + masquage serveur — elle conditionne désormais 9 surfaces.
3. Dossiers, y compris les versements depuis la messagerie et l'assistant.
4. Adhérents, listes, file d'envoi.
5. Messagerie : contacts, groupes, diffusions branchées sur la file d'envoi, chiffrement selon la
   décision §1.3.
6. Agenda, documents et signature, réunions.
7. Assistant : historique et mémoire serveur.
8. Formations : catalogues administrables, puis sessions unii.
9. Sondages, sites, reporting.
10. Hors ligne, facturation.

## 7. Liste de contrôle de mise en production

- [ ] Aucune clé, aucun prompt, aucun corpus dans le bundle client
- [ ] `localStorage` limité aux préférences d'interface (thème, menu réduit) — aucune donnée métier
- [ ] Chaque libellé du §1.3 vérifié ou reformulé, avec validation juridique
- [ ] `anonSendClear` et `npSimulateApproval` supprimés ; console admin sur un domaine séparé
- [ ] Masquage serveur testé sur les 9 surfaces IA, 0 fuite sur le jeu piégé
- [ ] Polices auto-hébergées, aucun appel tiers au chargement
- [ ] Diffusions : opposition vérifiée à l'envoi, désinscription, journal réel
- [ ] Région `aria-live` pour les notifications ; 29 boutons-icônes nommés ; audit RGAA
- [ ] Dates stockées en ISO 8601
- [ ] Données d'exemple absentes de la recette et de la production
- [ ] AIPD conduite (formations IA et mémoire de l'assistant incluses)
- [ ] Sauvegarde et restauration testées (`EXPLOITATION.md`)
