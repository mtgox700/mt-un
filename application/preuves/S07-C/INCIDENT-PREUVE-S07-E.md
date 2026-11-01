# Incident de classement des preuves — lot E, 30 octobre 2026

Le lanceur de régression E a modifié le texte d’un remplacement avant la lecture imbriquée de s07_files.py. Ce remplacement ne correspondait plus au chemin original ; la recette D a donc écrit ses 75 contrôles dans S07-C/integration.json. Ce fichier décrit désormais une exécution D sous le schéma E, et ne doit pas être utilisé comme résultat original du lot C.

La sortie fautive est conservée telle quelle ici et dans ../S07-E/regression-D/integration-premiere-execution.json. Le fichier original détaillé C n’a pas pu être récupéré à l’identique ; aucune reconstitution n’est présentée comme preuve historique. Le bilan C, les cas limites C et les captures ne sont pas modifiés. Deux régressions C de 73 contrôles restent disponibles dans ../S07-D/regression-C/integration.json et ../S07-E/regression-C/integration.json, avec leur contexte respectif.

Le lanceur tests/s07_e_regressions.py est corrigé. La nouvelle exécution D écrit exclusivement dans S07-E/regression-D/integration.json.
