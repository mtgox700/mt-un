# Matrice de recette S07

## Acteurs fictifs

Organisation A : membre auteur, destinataire participant, membre hors conversation, gestionnaire sans lecture métier. Organisation B : membre étranger. Super admin : aucun accès métier par défaut. Préparer les fixtures dans le périmètre local autorisé, sans vrais destinataires ni données réelles. Ne pas accorder de nouveaux accès dans une interface si un contrôle exige une confirmation spécifique ; expliquer alors exactement l’action.

| ID | Scénario | Résultat attendu |
|---|---|---|
| M01 | Envoyer puis recharger/reconnecter | Message durable, auteur/date serveur exacts |
| M02 | Même envoi rejoué / double clic | Un message ; pas de succès fictif |
| M03 | Hors groupe, même organisation | Liste, texte, pièces, recherche, compteurs et événements refusés ou filtrés |
| M04 | Identifiants d’une autre organisation | Aucun accès ni association incohérente |
| M05 | Arrivée puis historique antérieur | Masqué par défaut ; ouverture seulement habilitée et auditée |
| M06 | Départ puis réinvitation | Accès retiré ; ancien historique non rétabli implicitement |
| M07 | Révocation avec session/canal ouverts | Nouveaux accès et événements bloqués, état invalidé |
| M08 | MFA/module/permission révoqués | Refus serveur, pas de données de démonstration en secours |
| M09 | Réponse à message inaccessible | Pas d’extrait ou citation révélée |
| M10 | Recherche et pagination | Résultats autorisés, ordre stable, pas de saut/doublon lors d’un nouvel envoi |
| M11 | Pièce saine/infectée/scan interrompu | Accès contrôlé, quarantaine fermée, reprise vérifiable |
| M12 | Téléchargement sans permission | Refus même si lecture du message autorisée |
| M13 | Transfert source/destination | Droits cumulés et restrictions de diffusion préservés |
| M14 | Classement dans un dossier | Droits sources + dossier ; révocation source effective |
| M15 | Perte réseau, reconnexion, réponse tardive | Reprise sans doublon, aucune donnée entre comptes |
| M16 | Texte hostile et fichier trompeur | Rendu inerte, pas d’exécution ni accès Storage public |
| M17 | Demande de suppression | Circuit approuvé ; aucune suppression irréversible automatique |
| M18 | Pile neuve et restauration isolée | Schéma/objets/droits/historique conservés ; essais Auth réels après reprise |

## Stratégie de tests

Pendant le lot : tests unitaires sur règles/états modifiés, intégration sur Supabase réel, requêtes directes de refus. Après intégration : tests des contrats affectés et compilation. Aux jalons : non-régression transversale. À clôture : suite appropriée complète, installation et restauration isolée, contrôles d’intégrité.

Interface : mobile 390×844, tablette 768×1024, desktop 1440×1000. Pour chaque parcours touché : succès/refus lisibles, menus/modales accessibles, défilement, clavier/focus lorsque testable, aucun élément persistant masquant une action, contenu long. Vérifier les parcours, pas seulement capturer l’accueil. Les appareils physiques restent une qualification distincte.

## Preuves et bilan

Un nouveau dossier par lot dans preuves/S07-<lot>/. Résultats structurés avec noms de scénarios, compte fictif pseudonymisé, attendu/observé, date, échecs. Logs bornés sans secrets. Captures utiles seulement. Ne pas additionner les suites historiques pour fabriquer un taux de couverture.

Bilan : livré ; tests exécutés maintenant ; preuves antérieures réutilisées ; réserves ; prochaine action. Une commande lancée n’est pas un test réussi. Un test refusé par l’environnement n’est pas un succès. Une migration appliquée ne démontre pas la restauration.
