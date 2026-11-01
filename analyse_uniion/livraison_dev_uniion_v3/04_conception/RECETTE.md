# Recette, performance et qualité

Version 1 — 5 septembre 2026. Critères d'acceptation par module, cibles mesurables et matrice de
support. Un module n'est livrable que si **tous** ses critères passent, états non nominaux inclus
(`ETATS.md`).

## 1. Critères d'acceptation

Formulation : *étant donné … quand … alors …*. Un critère est vérifiable par un test automatisé ou une
manipulation reproductible.

### Authentification et rôles
1. Étant donné un compte sans MFA et une organisation qui l'impose, quand l'utilisateur se connecte,
   alors l'accès est refusé jusqu'à l'enrôlement d'un second facteur.
2. Étant donné un compte `militant`, quand il appelle une route réservée au trésorier, alors le
   serveur répond `403 role_insuffisant` et l'appel est inscrit au journal d'audit.
3. Étant donné un mandat arrivé à échéance, quand 24 h se sont écoulées, alors les sessions sont
   invalidées et la reconnexion est refusée.
4. Étant donné une déconnexion, quand l'utilisateur revient, alors aucun contenu de dossier n'est
   lisible depuis le cache local.

### Dossiers
5. Un dossier créé par A n'apparaît jamais dans la liste renvoyée à B non ajouté au dossier — vérifié
   **au niveau de la réponse serveur**, pas de l'affichage.
6. Le déplacement d'une carte est persistant après rechargement.
7. Une pièce jointe n'est téléchargeable qu'après analyse antivirus ; un administrateur non membre
   du dossier reçoit `404`.
8. Deux modifications concurrentes du même dossier produisent un `409` et un écran de comparaison,
   jamais un écrasement silencieux.

### Assistant IA
9. Aucune requête ne quitte le serveur avec un identifiant non masqué : jeu de 50 textes piégés
   (noms, matricules, IBAN, numéros de sécurité sociale, adresses) → 0 fuite.
10. Une question sur le modèle, le fournisseur ou l'hébergement est refusée **sans appel** au
    fournisseur et sans consommation de quota.
11. Toute réponse est stockée avec sa `prompt_version` ; un audit peut rejouer le prompt exact.
12. Le journal ne contient aucun texte de question ni de réponse — vérifié par inspection du schéma
    et par recherche de motifs dans les journaux de recette.
13. Quota atteint → `429` et écran dédié ; aucune réponse simulée n'est jamais affichée.

### Adhérents
14. Un import de 2 000 lignes dont 37 invalides crée 1 963 adhérents, produit un rapport listant les
    37 motifs, et laisse la base inchangée si la transaction échoue.
15. Une liste dynamique recalculée après l'ajout d'un adhérent correspondant l'inclut sans
    intervention manuelle.
16. Un compte `communication` peut envoyer à une liste sans jamais obtenir la liste des membres
    (vérifié sur la réponse serveur).
17. Toute lecture nominative du fichier adhérents est inscrite au journal d'audit.

### Agenda
18. Un événement `bureau` n'est présent dans **aucune** réponse serveur adressée à un compte non
    habilité.
19. Une série récurrente modifiée sur une occurrence ne modifie pas les autres.
20. L'export ICS d'un mandat révoqué cesse de fonctionner sous 24 h.

### Sites
21. Un HTML contenant `<script>`, `onclick` ou `javascript:` est publié assaini, sans exécution.
22. Une page publique ne peut pas être publiée sans relecture par un pair distinct de l'auteur.
23. La charte du site intranet et celle du site public sont indépendantes ; publier l'identité de
    l'organisation ne modifie que les sites dont la charte est en héritage.

### Reporting
24. Aucun agrégat portant sur moins de 5 personnes n'est affiché ni exporté.
25. Le bilan de mandat exporté ne contient aucune donnée nominative.

### Accessibilité
26. Tout parcours principal est réalisable au clavier seul, dans un ordre de focus cohérent.
27. À l'ouverture d'une feuille d'action ou d'une boîte de dialogue, le focus entre dedans et le
    retour arrière le restitue à l'élément déclencheur.
28. Tout message de confirmation ou d'erreur est annoncé par une région live.
29. Contraste : 4,5:1 sur tout texte sous 24 px ; 3:1 au-delà. Aucun gris clair sous 14 px.
30. Zoom à 200 % : aucun contenu tronqué, aucun défilement horizontal sur un écran de 1 280 px.

## 2. Scénarios de bout en bout

| # | Scénario | Traverse |
|---|---|---|
| E1 | Un salarié saisit les représentants → dossier créé → analyse IA → courrier signé → suivi jusqu'à clôture | Dossiers, IA, Documents, Audit |
| E2 | Import du fichier adhérents → liste dynamique → campagne de relance de cotisation → désinscription d'un adhérent | Adhérents, Campagnes, RGPD |
| E3 | Négociation : événement d'agenda → réunion enregistrée → compte rendu relu → page intranet publiée | Agenda, Réunions, Sites |
| E4 | Communiqué public : rédaction → relecture par un pair → transmission webmaster → retour → publication | Sites, Rôles |
| E5 | Perte de mandat : révocation → réattribution des dossiers → purge du cache → export ICS invalidé | Membres, Sécurité |
| E6 | Travail hors ligne : trois modifications locales → reconnexion → un conflit résolu par l'utilisateur | Synchronisation |

## 3. Cibles de performance

Mesurées au 75e centile, sur connexion 4G moyenne (10 Mb/s, 70 ms de latence) et appareil milieu de
gamme de 2023.

| Mesure | Cible | Plafond |
|---|---|---|
| Premier affichage utile (tableau de bord) | < 1,5 s | 2,5 s |
| Kanban de 200 dossiers — interactif | < 1,2 s | 2 s |
| Liste de 2 000 adhérents (page de 25) | < 600 ms | 1 s |
| Recherche adhérents (serveur) | < 400 ms | 800 ms |
| Grille d'agenda, mois de 300 événements | < 900 ms | 1,5 s |
| Première réponse IA (jeton initial) | < 3 s | 8 s |
| Réponse IA complète | < 12 s | 25 s |
| Import CSV de 2 000 lignes | < 20 s | 60 s (au-delà : asynchrone) |
| Poids initial (JS + CSS, compressé) | < 350 Ko | 500 Ko |
| Taille maximale d'un import CSV | 5 000 lignes / 5 Mo | traitement asynchrone au-delà |
| Taille maximale d'une pièce jointe | 80 Mo | refus au-delà |

## 4. Accessibilité — cible

**RGAA 4.1 / WCAG 2.1 niveau AA.** Une organisation syndicale est attendue exemplaire sur ce point ; la
déclaration d'accessibilité est obligatoire et déjà prévue dans le pied de page des sites générés.
Audit à commander en fin de développement, avec correction avant mise en ligne. Points déjà couverts
par le prototype : `aria-label`, `aria-pressed`, `role="switch"`, régions live, pilotage clavier du
kanban, respect de `prefers-reduced-motion`, focus visible à 2,5 px. Points à traiter : gestion du
focus des feuilles d'action, navigation clavier de la grille d'agenda, contraste des gris clairs.

## 5. Navigateurs et appareils

| Cible | Support |
|---|---|
| Chrome, Edge, Firefox, Safari — 2 dernières versions majeures | Complet |
| Safari iOS 16+, Chrome Android 12+ | Complet |
| Firefox ESR | Complet (déploiements d'entreprise) |
| Largeur 320 px à 2 560 px | Complet, sans défilement horizontal |
| Internet Explorer, Safari < 15 | Non supporté — message de mise à jour |

**Question ouverte à trancher avec le client** : quel est le niveau d'usage mobile réel attendu ? Le
prototype a une barre de navigation inférieure mais **aucun parcours mobile n'a été validé**. Si le
mobile est majoritaire (militants en atelier, sans poste fixe), les parcours de saisie de dossier et de
consultation d'agenda doivent être conçus mobile d'abord avant développement.

## 6. Outillage attendu

Tests unitaires sur les règles métier (masquage, autorisations, recalcul des listes, récurrence) ;
tests d'intégration sur chaque route avec un jeu de rôles ; tests de bout en bout sur E1 à E6 ;
tests de non-régression visuelle sur les 12 écrans principaux ; analyse statique d'accessibilité en
intégration continue ; jeu de données de démonstration (`seed`) séparé des fixtures de test.

## 6. Compléments version 3 — 1er octobre 2026

### Messagerie
1. Un message envoyé depuis « Envoyer un message » (Adhérents) apparaît dans Messages, dans la conversation directe (1 destinataire) ou de diffusion (N), avec canal et nombre de destinataires **réels**.
2. Le filtre « Sans réponse de ma part » ne liste que les conversations dont le dernier message non système vient d'un autre auteur ; les diffusions en sont exclues.
3. Un membre non administrateur d'un groupe reçoit `403` sur ajout, retrait ou nomination.
4. Le dernier administrateur ne peut pas quitter un groupe sans en désigner un autre.
5. Une réponse en privé ouvre la conversation directe existante sans en créer une seconde.
6. Un message versé dans un dossier reste lisible dans le dossier après suppression du message.
7. Une réponse @unii n'est visible que de son demandeur (vérifié sur un second compte membre du groupe).

### Formations
8. Pour chaque durée (15, 30, 60, 120, 180 min), le nombre de modules vaut 3, 4, 5, 6, 7 et la somme des minutes vaut la durée à ±10 %.
9. Chaque quiz a 2 à 4 choix et un index de réponse valide.
10. Le texte saisi dans un exercice est masqué avant l'envoi en relecture (jeu piégé).
11. Une session interrompue reprend au module courant sur un autre appareil.
12. Aucune session d'un utilisateur n'est lisible par un autre, administrateur compris.

### Performance
- Liste de 500 conversations : premier affichage < 400 ms (virtualisation).
- Génération d'un plan de formation : p95 < 25 s.
