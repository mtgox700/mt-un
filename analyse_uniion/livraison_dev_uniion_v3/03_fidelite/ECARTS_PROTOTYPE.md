# Registre des écarts au prototype (proto-v3.0)

Seule exception admise à la fidélité. Chaque écart doit avoir **son rendu dessiné dans le prototype** avant d'être codé (colonne « Dessiné »).

| N° | Section | Prototype | Production | Raison | Dessiné | Décision |
|---|---|---|---|---|---|---|
| E-01 | PAR-IA | Écran « Clé API » saisie par l'utilisateur | Retiré | Clé détenue par la passerelle serveur | n/a (suppression) | ✅ |
| E-02 | MOD-ANON | Aides de démo `anonSendClear` | Retiré | Aide de démonstration | n/a | ✅ |
| E-03 | INT-PUB | `npSimulateApproval` | Retiré | Simulation | n/a | ✅ |
| E-04 | PAR | Réinitialisation de la démo | Retiré | Aide de démonstration | n/a | ✅ |
| E-05 | SIG | « PDF signé » | Attestation imprimable, pas de signature fictive | Valeur juridique | ⬜ | à dessiner |
| E-06 | AUTH | Double authentification optionnelle | Obligatoire pour le trésorier et l'administrateur | Sécurité | ⬜ | à dessiner |
| E-07 | ADH | Effectifs toujours affichés | Masqués sous 5 hors trésorier | Anonymisation | ⬜ | à dessiner |
| E-08 | IA / UNII | Réponse toujours obtenue | Refus si nom résiduel détecté, avec « texte réellement envoyé » | Masquage serveur | ⬜ | à dessiner |
| E-09 | DOS / DOC | Enregistrement sans conflit | Conflit de version signalé | Concurrence optimiste | ⬜ | à dessiner |
| E-10 | PJ | Dépôt immédiat | Attente de l'analyse antivirus | ClamAV | ⬜ | à dessiner |
| E-11 | OFF | Données consultables hors ligne | Coque seule, aucune donnée métier | Sécurité | ⬜ | à dessiner |
| E-12 | MSG | Libellés de chiffrement | « chiffrée en transit et au repos » | Exactitude | ⬜ | à dessiner |
