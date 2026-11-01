# S09 — reste à faire après le lot B

## B — terminer et qualifier

1. Valider une capture produisant des octets sur un navigateur équipé de l’encodeur adéquat, puis lecture après sauvegarde/rechargement. Le navigateur de recette actuel produit zéro octet, y compris hors application. Tester permissions micro, interruption, pause/reprise et changement d’appareil avec des signaux fictifs.
2. Couvrir les séances longues au-delà du profil actuel 150 s/5 Mio : segments média assemblables, conversion bornée en mémoire, reprises et marqueurs sur la chronologie complète. Ne pas confondre segmentation du transfert HTTP déjà livrée avec segmentation d’une longue séance.
3. Qualifier les formats MediaRecorder/import (navigateurs et codecs réellement disponibles), conserver les originaux non-WAV aussi côté serveur selon un contrat sécurisé explicite.
4. Compléter D08 : durée d’accès locale 24 h configurable, verrouillage/renouvellement, quotas et concurrence multi-onglets ; ne jamais supprimer automatiquement un original non sauvegardé.
5. Rejouer la chaîne UI finale complète, les habilitations/retraits à deux acteurs et la matrice 360/390/768/1024/1440 px, faible hauteur, clavier et appareils. L’override de viewport n’a pas été appliqué ici. Vérifier plus particulièrement les modales et écrans de capture/fiche.

## C — transcription

Jobs durables, moteur réel local de recette, versions de résultats, erreurs/reprise/idempotence, droits hérités des sources. Aucun fournisseur externe implicitement autorisé.

## D — procès-verbal

Transcription et marqueurs → projet de PV → corrections → validation d’une version → diffusion via S06/S08. Respect de D12/D13 ; un PV diffusé ne donne pas accès à l’audio. Le PV actuel repose seulement sur les notes.

## E — conservation et restauration

Échéance à 30 jours après validation, inventaire des originaux, WAV, blocs base, transcriptions, dérivés, brouillons et sauvegardes. Demande de suppression puis validation super admin avant exécution ; aucune purge automatique. Restauration testée avec réapplication des retraits et révocations.

## F — recette complète et clôture

Chaîne réelle de bout en bout, sécurité/adverses, erreurs réseau/quota, formats/appareils, fidélité UI, documentation et transmission. Consolidation des réserves de B–E avant clôture S09. Production, fournisseurs et décisions d’exploitation restent à S16.

**Prochaine étape : lever les réserves de B, en commençant par un environnement de capture fonctionnel et les longues séances.** Le socle de C peut ensuite s’appuyer sur les WAV serveur déjà contrôlés, sans prétendre que B est clos.
