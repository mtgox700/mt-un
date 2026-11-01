# S08 F final — parcours observés

31 octobre 2026, application locale 5068, données et acteurs fictifs, navigateur IAB. Générations via le connecteur Codex autorisé.

| Scénario | Attendu et résultat observé | Preuve |
| --- | --- | --- |
| Message → dossier | Source sélectionnée, génération puis dossier privé ouvert, retrouvé après nouvelle session | message-vers-dossier.png |
| Auto-attribution | Refus serveur de modification de ses propres rôles, sans attribution nouvelle | role-auto-attribution-refusee.png |
| Document spécialisé | Brief fictif puis résultat enregistré ouvert dans l’éditeur natif ; correction de l’ancien mauvais point d’entrée | document-specialise-enregistre.png |
| Page Intranet | Deux paragraphes générés ; fausses métadonnées du prototype détectées et corrigées ; chapô réouvert en version 3 | intranet-apercu-corrige.png |
| Options de sondage | Question fictive → « Le matin » / « L’après-midi » ; aucune collecte/diffusion déclenchée | options-sondage-codex.png |
| Projet de PV | Contenu enregistré version 2 accessible après rechargement ; faits et manques distingués, aucune décision inventée | pv-enregistre-consultable.png |
| Mobile | Panneau PV 360×800 lisible, défilant, commandes accessibles | pv-mobile-360.png |
| Tablette | Panneau PV 1024×768, contexte réunion conservé, commandes accessibles | pv-tablette-1024.png |

Les captures bureau ont été prises à 1440×1000. Les preuves E complètent la couverture formation, communication, publication à deux acteurs, révocation, mobile 390×844 et tablette 768×1024. Les tests frontend vérifient aussi le retrait du PV quand les données autorisées disparaissent ; ce refus n’est pas revendiqué comme nouveau parcours UI.

`intranet-generation-avant-correction-apercu.png` documente le défaut initial, pas un état final accepté. Le projet de PV était déjà enregistré au retour dans la séance ; la présente preuve porte sur sa consultation persistante. La qualification réelle de sa génération figure dans E. Les aperçus de sites restent des maquettes locales dans les limites S11 décrites au registre.
