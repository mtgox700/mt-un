# Décisions de mise en production — uniion

17 octobre 2026. Décision client : **Supabase auto-hébergé sur un VPS chez un hébergeur français.**
Les autres choix ont été délégués ; ils sont révisables, chacun avec son point de bascule.

| # | Sujet | Choix | Pourquoi | Révisable par |
|---|---|---|---|---|
| D1 | Hébergement | Supabase auto-hébergé (Docker), VPS français, Ubuntu 24.04 | Décision client. Article 9 RGPD, aucune exposition au Cloud Act | — |
| D2 | Modèle d'IA | **Mistral AI** (La Plateforme, UE), `mistral-large-latest`, alias exposé `unii-v1` | Éditeur français, hébergement UE : rend tenable la mention « modèle souverain » de l'écran Sécurité de l'IA. Contrat à signer : zéro rétention, pas d'entraînement | `AI_PROVIDER=anthropic` dans `.env` (adaptateur prêt) |
| D3 | Front | React 18 + Vite + TypeScript, TanStack Query, application web responsive (PWA au lot 3) | Le prototype est déjà une logique de type React ; une PWA couvre le mobile sans 2ᵉ base de code | App native si un parcours mobile l'exige après pilote |
| D4 | Messagerie | **Chiffrée en transit et au repos** (clé serveur hors base), pas de bout en bout au lancement | Le bout en bout (clés par appareil, récupération) coûte 4 à 6 semaines et bloquerait le MVP. Le libellé de l'interface est corrigé en conséquence | Lot 6 : colonnes `cles_destinataires` et `appareil.cle_publique` déjà prêtes |
| D5 | Chiffrement applicatif | AES-256-GCM, clé par organisation dérivée (HKDF) d'une clé maîtresse en secret des Edge Functions | La base ne voit jamais la clé (schéma, §4). pgsodium est déprécié par Supabase | Passage à un KMS de l'hébergeur |
| D6 | Adhérents (art. 9) | Aucun accès direct aux tables : fonctions `api.adherent_*`, rôle trésorier + double authentification, chaque lecture journalisée | Une politique RLS ne peut pas journaliser une lecture | — |
| D7 | Authentification | E-mail + mot de passe (12 car.), inscription fermée, invitation seule, TOTP obligatoire pour trésorier et admin, jeton 15 min, session 12 h / inactivité 2 h | AUTORISATIONS.md, SECURITE.md | SSO SAML : à l'arrivée d'une fédération qui l'exige |
| D8 | E-mails | Brevo (société française, UE) | DPA standard, délivrabilité | Tout SMTP UE |
| D9 | Sauvegardes | restic chiffré vers stockage objet d'un **autre fournisseur** (ex. Scaleway si VPS OVH), base toutes les heures, fichiers chaque nuit, restauration testée chaque trimestre | Perte max 1 h, rétablissement 4 h (EXPLOITATION.md) | WAL-G pour descendre sous l'heure |
| D10 | Supervision | Uptime Kuma (sur un 2ᵉ petit VPS) + sonde `/functions/v1/sante` + journaux Supabase | Une sonde sur la même machine ne voit pas la panne de la machine | Grafana/Prometheus si plusieurs VPS |
| D11 | Extensions | uniion Studio seul, servi depuis `/ext/` du front, registre en base (`extension`), SRI + signature, activation par l'admin. Chargement par URL libre **supprimé** | Bloquant 2.1 | Registre tiers : revue de code + signature éditeur |
| D12 | Studio Supabase | Jamais exposé : tunnel SSH uniquement. L'API publique ne laisse passer que `/auth /rest /storage /realtime /functions` | Le tableau de bord donne un accès total à la base | — |
| D13 | Console super-admin | Application séparée, autre sous-domaine, hors MVP | Bloquant 1.5 | — |
| D14 | Polices | Auto-hébergées (`front/public/fonts`), CSP `font-src 'self'` | Bloquant 1.7 | — |

## Corrections apportées au schéma de référence

1. **Fuite de dossiers** : dans `uniion.sql`, la politique d'organisation sur `dossier` était permissive ; combinée en OU
   avec la politique de périmètre, elle ouvrait tous les dossiers de l'organisation à tout membre. Les politiques
   d'organisation sont désormais **restrictives** sur toutes les tables (test pgTAP dédié).
2. **Révocation immédiate** : `app.personne_id()` revérifie en base que le compte est actif ; un mandat terminé coupe
   l'accès à la requête suivante, pas à l'expiration du jeton.
3. Vote de sondage unique sans lien avec la réponse (`sondage_participation`).
4. Anonymisation (et non suppression) des adhérents radiés : les cotisations doivent rester 10 ans.
5. Docker publie ses ports en contournant ufw : tous les ports Supabase sont liés à 127.0.0.1.

## Hors ligne : aucune donnée métier sur l'appareil (17 octobre 2026)
La PWA s'installe et s'ouvre hors ligne, mais ne met en cache que le code et les ressources statiques.
Un cache chiffré de dossiers ou d'adhérents aurait exigé une clé dérivée côté appareil, une purge fiable
et une gestion des téléphones perdus : le gain (consultation sans réseau) ne justifie pas ce risque pour
des données d'article 9. À réexaminer si le pilote montre un besoin réel (permanences sans réseau).

## Extensions : signature vérifiée dans le navigateur (17 octobre 2026)
Le registre en base porte l'empreinte SRI et une signature Ed25519 de l'éditeur. Le navigateur refuse
une signature invalide ; s'il ne sait pas vérifier Ed25519, il s'en remet au SRI et au chemin `/ext/`
(fichier servi par uniion). La clé privée reste sur le poste de l'éditeur (`infra/publier-extension.sh`).
