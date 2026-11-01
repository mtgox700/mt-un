# S08 — lot E : raccordement des modules à unii

30 octobre 2026. **Tranche de recette fictive livrée ; le périmètre métier complet du lot E reste ouvert.** Skill uniion-développement appliqué. Aucun déploiement ni transfert de données métier réelles. L’autorisation utilisateur reste le connecteur ChatGPT/Codex local avec des données fictives uniquement.

## Parcours livré

Depuis un dossier, un document ouvert ou un message sélectionné, le panneau unii propose « Relire les extraits fictifs ». Une seule référence est envoyée au serveur. Le serveur récupère la source via son contrat métier, vérifie les droits et la certification exacte de la fixture, applique le masquage partiel et demande des extraits vérifiables. Il recontrôle les dépendances avant restitution. La proposition est enregistrée chiffrée dans l’historique privé de l’acteur et de l’organisation, puis relue avant affichage.

« Continuer dans l’Assistant » transmet seulement l’identifiant de la réponse persistée ; l’Assistant la relit avec les droits actuels. Aucune importation du contexte navigateur ou d’une réponse fournie par le client. Les actions de module n’incorporent pas implicitement la mémoire de l’Assistant : le périmètre reste la source sélectionnée.

Dossiers : entrée depuis la fiche et les cartes. Documents : entrée unii dans l’éditeur ; les modifications en attente passent d’abord par le service de sauvegarde du document. Une version modifiée n’est plus certifiée automatiquement et est refusée. Messages : entrée par le menu du message, ou sélection unique dans le fil ; sans sélection, le dernier message chargé est annoncé par son numéro. Plusieurs messages sélectionnés sont refusés sans troncature implicite. Il ne s’agit pas d’un résumé exhaustif du fil.

## Sécurité et brouillons

`POST /identity/ai/actions` accepte exactement organisation, identifiant de demande, action et référence de source. Les trois actions sont `case-excerpts`, `document-excerpts`, `message-excerpts`. Aucune instruction libre, destination, commande administrative, paramètre d’application ni texte de réponse accepté. Le registre C fournit idempotence, quotas, annulation et états honnêtes. Le stockage et la relecture D fournissent chiffrement, isolation et contrôles de sources.

Le texte importé, même lorsqu’il demande un outil ou une citation inventée, reste une donnée non fiable. Aucun outil métier n’est exposé au modèle. Une citation inconnue ou un résultat structuré contenant une commande n’est pas accepté par le validateur B. Les résultats affichés ne sont jamais interprétés comme du HTML ou du code.

Aucune application dans la chronologie, les documents, une page mobile, un plan éditorial ou une notification. Les anciens chemins `uniiApply` et les générateurs non raccordés sont neutralisés dans l’hôte serveur pour éviter une fausse réussite locale. Les brouillons métier ne sont pas remplacés par une réponse IA. Le circuit D12/D13 d’une version dérivée diffusable n’est pas implémenté par ce lot : refuser l’application évite de contourner les restrictions, mais ne remplace pas ce circuit.

Annulation explicite, fermeture, navigation, déconnexion, masquage de l’onglet et démontage invalident les résultats tardifs. Les propositions restent hors de l’état persistant du navigateur. Une relecture toutes les dix secondes retire le résultat si la source change, les droits sont retirés ou le service devient indisponible. Comme D, il s’agit d’un rafraîchissement périodique, pas d’une révocation poussée instantanément à un écran déjà ouvert.

## Vérifications

| Contrôle | Résultat | Preuve |
| --- | --- | --- |
| Suite Python | 262 tests réussis, dont 9 nouveaux | python-tests.log |
| Suite frontale | 213 tests réussis, dont 13 nouveaux | frontend-tests.log |
| HTTP/MFA, Supabase local, trois types de source | 31 contrôles réussis, appel Codex réel inclus | integration.json, codex-live.json |
| Compilation et frontières | Réussies | build.log, boundaries.log |
| Références protégées et anciennes preuves | 834 références et 2187 fichiers de preuve inchangés | integrite-apres.json |
| UI dossier, réponse Codex, annulation, continuation | Vérifiées | dossier-unii-1440.png, annulation-1440.png, assistant-continuation-390.png |
| Responsive | 1440×1000, 768×1024, 390×844 | dossier-unii-*.png |

Tests nouveaux : requête sans brouillon ni prompt, conservation des brouillons métier, réponse hors état local, annulation avant et pendant traitement, fermeture/navigation et réponse tardive, source modifiée, refus d’application forgée, séparation acteur, type de source incompatible, source privée et organisation étrangère, aucun élargissement par mémoire, sélection précise d’un message, échec de sauvegarde du document, absence de secours simulé.

La recette navigateur a également produit des réponses Codex réelles depuis le document fictif contenant une instruction importée non fiable (`document-unii-1440.png`) et le message 1 (`message-unii-1440.png`). Le message voisin n’est pas cité. Le brouillon saisi avant la relecture est resté identique, puis a été retiré sans envoi (`message-brouillon-conserve.png`).

La recette visuelle a détecté le bouton d’annulation désactivé pendant l’appel. Le template a été corrigé ; le bouton reste actif, l’annulation a été rejouée et couverte par un test. Les captures d’annulation sont conservées comme observation de cette étape ; une amélioration ultérieure conserve aussi la référence sélectionnée après annulation pour permettre une nouvelle demande explicite.

## Fidélité et limites

Structure, navigation, couleurs, typographie, cartes et panneau latéral conservés. Comparaison avec la référence extraite et la capture antérieure S05 `desktop-autorise.png`. Les libellés de confidentialité fictifs sont remplacés par des descriptions exactes : masquage partiel, certification fictive, source à vérifier, aucune application automatique. Les anciennes actions restent visibles dans les réglages comme non activées ; les rôles locaux ne prétendent plus accorder des droits serveur.

**Non livré :** les 37 actions métier du catalogue (conseil juridique, rédaction/reformulation, réunions, formations, communication, sondages, pages, etc.), la conversation libre, les dérivés applicables puis diffusables et les adaptateurs des autres modules. Les trois contrats permettent seulement la relecture extractive de fixtures certifiées. Ce bilan ne transforme pas cette tranche en validation du périmètre métier complet de E ou de S08.

Suite utile : F peut recetter globalement le périmètre fictif raccordé. La clôture métier de S08 exige encore les fonctions ci-dessus et les décisions de production D09/D07. Les réserves C/D sur stockage local d’instance, multi-hôte, sauvegarde/restauration globale, coûts/jetons inconnus et conservation restent applicables.
