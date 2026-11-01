# S08 — complément du lot E : brouillons métier et application explicite

31 octobre 2026. **Complément implémenté et recetté ; E complet n’est pas clôturé.** La demande « finalise le lot E » a conduit à dépasser la relecture extractive initiale. Le résultat ci-dessous ne couvre toutefois pas encore tous les parcours natifs du prototype. Le nom du répertoire désigne le chantier de finalisation, pas une attestation de clôture.

## Résultat disponible

Les 37 consignes du catalogue sont définies côté serveur. L’appel accepte seulement une action connue et une référence de source ; aucune consigne importée ne devient une commande. Chaque génération exige la politique IA, les droits du module, les droits de la source et la certification exacte de la fixture. Ces contrôles sont renouvelés avant/après l’inférence et à la relecture de l’historique.

Le résultat est un brouillon privé avec citations exactes contrôlées, enregistré chiffré. Le texte proposé reste à vérifier : la validité d’une citation ne valide pas une suggestion, un conseil juridique ou une affirmation ajoutée. Aucun outil métier n’est exposé au modèle. Les champs supplémentaires, commandes ou citations inventées sont rejetés.

Le panneau unii permet de charger les actions, sélectionner une source certifiée, générer, corriger le texte, enregistrer la correction, puis marquer le brouillon comme relu. Une correction annule la relecture précédente. Les versions concurrentes sont refusées ; vingt corrections au maximum sont conservées chiffrées, puis une nouvelle correction est refusée explicitement au lieu d’effacer l’historique. Depuis l’Assistant, « Reprendre le brouillon » recharge sa version serveur dans le panneau.

L’application constitue une seconde action explicite, distincte de la relecture :

- quatre actions Dossiers peuvent ajouter une note au même dossier ; tout dossier comportant une source classée est refusé pour éviter de perdre ses restrictions ;
- deux actions Documents peuvent ajouter un paragraphe au même document, uniquement au statut Brouillon ; les blocs existants, la charte et les autres données du document sont conservés ;
- aucun envoi de message, notification, changement d’habilitation ou publication n’est déclenché.

La destination et le texte appliqué sont relus côté serveur. Les droits d’écriture et la version source sont contrôlés dans la transaction PostgreSQL. Le reçu d’application et la modification métier sont atomiques ; une nouvelle tentative avec le même identifiant restitue le reçu sans doubler le contenu. Le reçu confirme une mutation autorisée, pas une attestation de provenance IA indépendante du client SQL. Les règles ordinaires de validation/publication des Documents restent en place.

Le document en cours de modification est sauvegardé avant génération et application. Une sauvegarde en échec bloque l’appel. Un dossier en édition bloque l’application pour préserver son brouillon. La fermeture/navigation retire les résultats tardifs ; la perte de droits retire aussi le texte de l’éditeur privé. La vérification périodique demeure de dix secondes, sans promesse de révocation poussée instantanément.

Une application change la source : l’ancienne réponse devient inaccessible par les contrôles de version. La nouvelle version n’est **pas** certifiée automatiquement comme donnée fictive. Les reçus d’application restent consultables dans le périmètre de droits actuel pour résoudre une tentative ambiguë.

## Périmètre réel des 37 actions

La matrice exhaustive figure dans `matrice-actions.json`.

- Dossiers, Documents et Messagerie disposent de leurs adaptateurs natifs. La Messagerie porte sur un message précis, pas un fil entier.
- Les autres actions peuvent préparer un brouillon à partir d’un **document de contexte choisi explicitement**. Elles ne lisent pas les données natives de Réunions, Agenda, Communication, Mobile, Formations, Adhérents, Sondages, Intranet ou Reporting.
- Les anciennes entrées spécialisées de génération non raccordées restent refusées. Elles ne fabriquent plus une réussite locale.
- Les réglages de rôles du prototype ne donnent aucun droit serveur. La génération vérifie la permission de lecture du module et la permission IA ; une configuration fine par action/rôle n’est pas livrée.

## Vérifications

| Contrôle | Résultat |
| --- | --- |
| Python | 271 tests réussis |
| Frontend | 221 tests réussis |
| HTTP + MFA + PostgreSQL réel | 130 contrôles réussis, dont génération/persistance/relecture des 37 actions avec fournisseur de test |
| Codex local réel | Brouillon `doc-relire` avec citation vérifiée ; parcours navigateur également exécuté |
| Installation neuve | 50 contrôles, 140 fichiers SQL appliqués depuis zéro |
| Restauration isolée | 375 contrôles SQL/fichiers + 16 contrôles IA ; reçus d’application restaurés |
| Références et anciennes preuves | 834 références et 2234 fichiers de preuve inchangés |
| Compilation et frontières | Réussies |
| Visuel | Document généré, corrigé, relu puis appliqué ; 1440×1000, 768×1024, 390×844 |

Le test navigateur constate deux paragraphes : l’original et la correction insérée ; le document reste Brouillon. Sur mobile, les boutons de relecture/application restent accessibles après défilement. Une capture prise pendant le redimensionnement est conservée comme telle ; les captures `*-stable` et `*-actions` montrent le rendu stabilisé. Les 37 actions n’ont pas toutes une qualification sémantique ni une recette visuelle individuelle.

Un premier lancement du script de restauration a échoué sur un chemin de fixture incorrect après la restauration isolée ; le chemin a été corrigé et le scénario complet rejoué avec succès. Le journal initial est conservé. Aucun service de travail n’a été restauré.

La recette a également vérifié les refus : autre acteur, version périmée, booléen utilisé comme version, application avant relecture, texte/destination forgés, lecteur sans écriture, document validé et dossier avec message classé. Les tests frontaux couvrent les réponses tardives, la correction non enregistrée, la sauvegarde métier en échec et l’effacement du texte après révocation.

## Reste nécessaire à la clôture complète de E

1. Raccorder les sources et parcours natifs des autres modules, au lieu de leur demander un document de contexte.
2. Raccorder les applications prévues pour plan éditorial, pages mobiles et notifications, avec leurs restrictions D12 et circuits D13 ; elles ne sont pas exécutables ici.
3. Finaliser la conversation libre, les parcours spécialisés de formation/rédaction et la configuration fine des actions selon les rôles.
4. Qualifier la qualité métier de l’ensemble des tâches et recetter leurs écrans propres.

Ces points sont des travaux restants, **pas des validations utilisateur prétendument manquantes**. L’autorisation demeure le connecteur ChatGPT/Codex local avec données fictives uniquement. Aucun fournisseur de production, donnée réelle ou déploiement n’est autorisé par ce bilan. D07/D09 et les réserves d’exploitation des lots C/D/F restent distincts.
