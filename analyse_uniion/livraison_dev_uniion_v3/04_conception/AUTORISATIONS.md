# Matrice d'autorisations

Version 1 — 5 septembre 2026. **Document opposable** : c'est cette matrice, et non l'interface, qui
définit ce qu'un compte peut faire. Toute règle ci-dessous est appliquée **côté serveur**. L'interface
masque ce qui est interdit, mais le masquage n'est jamais la protection.

## 1. Rôles

| Rôle | Attribution | Portée |
|---|---|---|
| `militant` | Tout compte rattaché à l'organisation | Ses propres dossiers, l'intranet en lecture, l'agenda selon visibilité |
| `communication` | Attribué par un administrateur | Édition et publication des sites intranet et public, charte des sites |
| `tresorier` | Attribué par un administrateur, 1 à 2 par organisation | Adhérents, cotisations, attestations fiscales |
| `admin` | Désigné à l'ouverture du compte organisation | Membres, rôles, sécurité, facturation, journal d'audit |

Un compte peut porter plusieurs rôles. `admin` n'implique **pas** l'accès au contenu des dossiers
d'autrui ni aux messages chiffrés : l'administration porte sur les comptes et la configuration, pas sur
le contenu (voir §4).

## 2. Matrice rôle × écran × action

Légende : **L** lire · **C** créer · **M** modifier · **S** supprimer · **X** exporter · **—** aucun accès.
Une parenthèse indique une restriction précisée en §3.

| Écran / ressource | militant | communication | tresorier | admin |
|---|---|---|---|---|
| Tableau de bord | L | L | L | L |
| Dossiers — liste | L (1) | L (1) | L (1) | L (1) |
| Dossiers — détail, historique, notes | L C M (2) | L (1) | L (1) | L (1) |
| Dossiers — pièces jointes | L C S (2) | — | — | — (3) |
| Dossiers — suppression | S (2) | — | — | — |
| Assistant juridique | L C | L C | L C | L C |
| Assistant de dossier | L C (2) | — | — | — |
| Sondages | L C M | L C M | L | L |
| Sondages — diffusion | — (4) | C (4) | — | C |
| Documents — bibliothèque | L C M S (5) | L C M S | L C M S (6) | L |
| Documents — signature | C (5) | C | C (6) | — |
| Réunions — séances, enregistrement | L C M (2) | — | — | L (7) |
| Réunions — comptes rendus | L C M | L M | — | L |
| Agenda — événements | L C M S (8) | L C M S (8) | L (8) | L C M S |
| Intranet et site public — pages | L | L C M S | L | L |
| Intranet — demande de publication | — | C | — | C |
| Charte des sites, logos de site | L | L M | — | L M |
| Adhérents — fichier | — | — | L C M S X | L (9) |
| Adhérents — import CSV | — | — | C | — |
| Adhérents — listes de diffusion | — | L (10) | L C M S | L |
| Adhérents — campagnes de message | — | C (10) | C | L |
| Cotisations, attestations fiscales | — | — | L C M X | — (9) |
| Messagerie chiffrée | L C (11) | L C (11) | L C (11) | L C (11) |
| Reporting — bilan de mandat | L X | L X | L X | L X |
| Reporting — télémétrie d'usage | — | — | — | L X |
| Reporting — représentants les plus actifs (nominatif) | — | — | — | L (12) |
| Réglages — profil et mandat personnel | L M | L M | L M | L M |
| Réglages — informations de l'organisation | L | L | L | L M |
| Réglages — identité de marque | L | L M | — | L M |
| Réglages — sécurité, MFA de l'organisation | L | L | L | L M |
| Réglages — membres et rôles | L (13) | L (13) | L (13) | L C M S |
| Réglages — ordre du menu | L M (14) | L M (14) | L M (14) | L M (14) |
| Réglages — facturation et sièges | — | — | L | L M X |
| Journal d'audit | — | — | — | L X |

## 3. Restrictions

1. **Dossiers — visibilité.** Un dossier est visible par son référent, les personnes explicitement
   ajoutées, et personne d'autre. Aucun rôle ne donne accès à l'ensemble des dossiers : la liste
   renvoyée par le serveur est toujours filtrée par appartenance. Les agrégats de reporting sont
   calculés serveur et ne réexposent pas les dossiers individuels.
2. Réservé au référent du dossier et aux personnes ajoutées au dossier.
3. Un administrateur **ne peut pas** ouvrir une pièce jointe de dossier. Il peut constater son
   existence dans le journal d'audit (nom, empreinte, déposant), pas son contenu.
4. La diffusion d'un sondage exige une validation par un pair distinct de l'auteur.
5. Le militant crée et signe ses propres documents ; il ne modifie ni ne supprime ceux d'autrui.
6. Le trésorier est limité aux gabarits financiers : appel de cotisation, reçu, attestation fiscale,
   bilan de trésorerie.
7. L'administrateur voit qu'une séance a été enregistrée et par qui, jamais l'audio ni la
   transcription.
8. **Agenda — visibilité.** Trois niveaux : `section` (toute l'organisation), `bureau` (membres du
   bureau), `prive` (créateur et participants). Le filtrage est **serveur** : un événement `bureau`
   ne doit jamais transiter vers un client non habilité, même masqué à l'affichage.
9. L'administrateur voit les **effectifs et les agrégats** du fichier adhérents, jamais la liste
   nominative ni les montants individuels : l'appartenance syndicale relève de l'article 9 du RGPD et
   son accès est restreint au trésorier. Si l'administrateur est aussi trésorier, il porte les deux
   rôles et l'accès est journalisé à ce titre.
10. Le rôle communication peut cibler une liste de diffusion **sans en voir les membres** : il choisit
   une liste par son libellé, le serveur résout les destinataires. Aucun export.
11. La messagerie est chiffrée de bout en bout : le serveur stocke des messages qu'il ne peut pas lire.
   Aucun rôle, y compris `admin`, ne dispose d'un accès de déchiffrement.
12. Vue nominative soumise à double condition : rôle `admin` **et** inscription de la consultation au
   journal d'audit, consultable par les intéressés.
13. Annuaire interne : nom, mandat, rôles, établissement. Pas de coordonnées personnelles si le membre
   a restreint leur visibilité dans son profil.
14. Préférence individuelle, portée par le compte, sans effet sur les autorisations.

## 4. Principes non négociables

- **Cloisonnement employeur.** Aucun compte rattaché à l'employeur n'existe. Aucun export, lien de
  partage ou notification ne doit pouvoir être adressé à une adresse du domaine de l'entreprise sans
  action explicite de l'utilisateur, écran d'avertissement, et inscription au journal.
- **Refus par défaut.** Toute route non listée est refusée. Un rôle inconnu vaut `militant`.
- **Réponse en cas de refus.** `403` avec un code métier (`role_insuffisant`,
  `hors_perimetre_dossier`, `donnee_article_9`) et **sans révéler l'existence** de la ressource
  quand la seule connaissance de son existence est déjà une fuite (dossier d'autrui, événement privé) :
  dans ce cas, `404`.
- **Journalisation.** Toute lecture de donnée d'article 9, toute consultation nominative, tout export et
  tout changement de rôle sont inscrits au journal d'audit (acteur, action, objet, horodatage,
  appareil), conservé 5 ans, non modifiable.
- **Révocation.** La fin d'un mandat désactive le compte sous 24 h : sessions invalidées, appareils
  déliés, dossiers réattribués par un administrateur, cache local purgé à la reconnexion refusée.

## 5. Compléments version 3 — 1er octobre 2026

| Ressource / action | militant | communication | tresorier | admin |
|---|---|---|---|---|
| Messages — directs et groupes dont on est membre | L C | L C | L C | L C |
| Groupe — créer | C | C | C | C |
| Groupe — renommer, membres, admins | admin du groupe uniquement (5.1) | idem | idem | idem |
| Diffusion aux adhérents — envoyer | — | — | C | C (5.2) |
| Contacts — élus et externes | L C M | L C M | L C M | L C M S |
| Contacts — adhérents | L (5.3) | — | L | L |
| Verser un message dans un dossier | C (membre du dossier) | — | — | — |
| @unii dans Messages | L C (sur les messages visibles) | idem | idem | idem |
| Historique IA, mémoire de l'assistant | L C M S (les siens) | idem | idem | idem — **jamais ceux d'autrui** |
| Formations — catalogues | L | L | L | L |
| Formations — demander une session | C | C | C | C ; reçoit et arbitre les demandes |
| Formations — sessions unii | L C M S (les siennes) | idem | idem | idem — **aucun accès au contenu d'autrui** |
| Catalogues — édition | — | — | — | éditeur uniion (console) |

5.1 Être administrateur de l'organisation ne donne **aucun** droit sur un groupe dont on n'est pas
membre (principe §4).
5.2 L'envoi aux adhérents porte sur des données d'article 9 : il est réservé aux rôles ayant accès au
fichier. Le prototype l'ouvre à tous les élus : **à restreindre**.
5.3 Un militant voit nom et fonction des adhérents dans l'annuaire de messagerie pour pouvoir leur
écrire. Coordonnées et statut de cotisation restent réservés au trésorier et à l'admin.
5.4 « Répondre en privé » et « Écrire à » ne sont proposés que si l'auteur a un compte et que
l'organisation autorise les messages directs entre membres.
5.5 Un transfert ne peut viser qu'une conversation dont l'utilisateur est membre ; un message issu d'un
groupe et transféré garde la mention « Transféré », sans l'auteur d'origine.
