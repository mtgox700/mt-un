# S09-D — PV liés à la transcription

## Parcours

Dans la fiche de réunion, sélectionner une prise puis « Préparer le projet de PV ». Une transcription terminée est requise. Le serveur assemble un projet à relire à partir de l’ordre du jour, de la transcription horodatée et des versions courantes des marqueurs. Il ne déduit pas de décision, ne simule pas une synthèse et n’appelle pas de fournisseur pour cet assemblage.

« Corriger le PV » réutilise la modale existante. La sauvegarde attend la version lue et crée une nouvelle version ; une saisie périmée est refusée. Le texte non enregistré reste dans la modale en cas d’erreur. « Passer en mode assistant » utilise, lorsqu’un PV est ouvert, ce PV comme source du contrat S08 existant : transcription et marqueurs font partie de son contexte privé. Les règles d’activation, de fournisseur, de recette et les limites propres au contexte IA continuent à s’appliquer. Ce lot n’active aucun nouveau fournisseur et ne présente pas l’assemblage comme une génération IA.

« Relecture et diffusion du PV » réutilise la publication S08 : une autre personne habilitée relit la version, fixe les destinataires, puis une personne autorisée publie dans l’application. La copie publiée contient uniquement le titre et le texte du PV relu. Aucun accès à l’audio, à la transcription brute ou à la provenance privée n’est donné. Le téléchargement n’est pas autorisé par cette copie.

« Gérer les versions diffusées du PV » permet de révoquer une ancienne version, y compris après retrait du consentement audio. Cette gestion exige la permission de publication et l’accès métier à la réunion ; elle ne dévoile pas le brouillon bloqué.

## Persistance et restrictions

Les migrations 173–179 ajoutent une provenance privée `meeting_minutes` et des gardes cumulatives sur les ressources, versions, partages et contextes IA. Le PV est une ressource distincte : ses corrections n’incrémentent pas la version de la réunion et n’invalident pas son consentement. L’idempotence lie organisation, réunion et tâche de transcription. L’ajout d’un segment exige une nouvelle transcription complète et produit un PV distinct pour cet ensemble exact de sources. Une version des marqueurs utilisée est conservée dans la provenance ; une modification ultérieure des marqueurs ne réécrit pas rétroactivement le PV.

Les lecteurs et rédacteurs du brouillon doivent avoir l’accès métier correspondant à la réunion ainsi que la lecture de toutes les sources audio et un consentement courant. Les contrôles RLS pointent explicitement vers les nouvelles fonctions ; renommer une fonction ne suffit pas à remplacer son OID dans une politique. Les partages directs du brouillon sont refusés ; seule la copie relue, avec audience distincte, est diffusée.

Les sources du PV (transcription, marqueurs et ordre du jour) ne peuvent pas être réécrites par la sauvegarde du texte. Le retrait de droits ou du consentement masque les brouillons ordinaires et leur historique direct. Une copie déjà approuvée reste indépendante et révocable conformément à D12. Une modification du PV crée une version non validée, sans altérer les anciennes versions approuvées.

## Limites explicites

Le document source assemblé est borné à 6 Mio ; aucun dépassement n’est silencieusement tronqué. Les limites S08 du contexte IA sont distinctes : le raccordement ne les augmente pas. La progression et le moteur de transcription restent ceux de C. Le modèle peut se tromper ; la recette comporte volontairement une correction de reconnaissance.

Le circuit livré est une publication interne dans l’application, sans e-mail, push externe, signature ou export PDF nouveau. L’édition se fait dans le composant de saisie existant ; aucune nouvelle charte ou route d’éditeur n’est introduite. Conservation, suppression approuvée et restauration des données nouvelles restent au lot E ; qualification de la chaîne complète et des appareils à F. Aucun déploiement de production.
