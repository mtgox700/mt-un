# S07 — Lot C : pièces et classement

30 octobre 2026 — lot techniquement validé en local ; S07 reste ouvert.

## Périmètre réalisé

Demande couverte : pièces et classement manuel dans Dossiers, à partir des lots A/B. Application locale sur 5068, Supabase et Storage locaux, ClamAV réel et moteur de rendu isolé existants. Données et comptes de recette fictifs. Les spécifications du package n’ont pas été traitées comme une autorisation de déploiement.

Le bouton Joindre crée un message de pièce durable et son objet immuable. Le coffre existant gère dépôt, quarantaine, antivirus et aperçu inerte. L’auteur voit les états bloqué ou à reprendre ; aucun faux succès n’est affiché. Un rejeu conserve le même message et le même objet. Le même fichier peut reprendre un dépôt inachevé après rechargement et après expiration de la fenêtre initiale d’insertion.

Les menus existants permettent de classer le message entier ou sa pièce dans un dossier accessible. Le classement persiste une référence ; le texte source n’est pas copié dans le corps du dossier. Les listes, compteurs, historique et passerelles de fichiers recalculent les droits source/destination.

La corbeille source réutilise le circuit D07 : demande de l’auteur habilité, validation super admin sans contenu, retrait effectif des octets et des références, restauration explicite. Rien n’est détruit physiquement ; une restauration ne restitue pas un accès révoqué.

## Sécurité et architecture

Migrations 126–130 appliquées. message_files privée sous RLS et clés cohérentes d’organisation/message/ressource. Le coffre reconnaît les ressources de pièces Messages et exige les droits du message courant ; ni grants génériques ni partage générique ne contournent l’historique. Aucune lecture métier implicite du super admin.

MFA, appartenance/suspension, module, droit commercial, read, période de participation ou ouverture historique sont cumulés. Write et qualité d’auteur sont requis pour reprendre une pièce. Download reste distinct de l’aperçu. La passerelle contrôle l’intégrité et revérifie les droits après transfert/rendu ; les octets ne passent pas par une URL publique ou signée. Une génération de scan périmée est refusée.

Le nouveau service frontal messaging/files.js possède les opérations de pièces, les clés de reprise et l’aperçu. Navigation et changement d’identité invalident les réponses tardives. Les adaptateurs message_files.py et cases.py raccordent les contrôles serveur au pipeline existant. Aucune persistance métier locale supplémentaire.

## Tests exécutés

| Commande / suite | Résultat | Preuve |
| --- | --- | --- |
| python3 -B -m unittest discover -s tests -p 'test_*.py' | 155 tests réussis | python-tests.log |
| node --test state/*.test.mjs, depuis frontend/ | 152 tests réussis | frontend-tests.log |
| tests/s07_files.py | 73 contrôles réussis, exécution finale sur 126–130 | integration.json |
| tests/s07_file_edges.py | 20 contrôles réussis | edges.json |
| tests/s07_c_regressions.py s07_messaging | 47 contrôles réussis | regression-A/integration.json |
| tests/s07_c_regressions.py s07_members | 54 contrôles réussis | regression-B/integration.json |
| tests/s07_c_regressions.py s05_files | 27 contrôles réussis | regression-coffre/integration.json |
| tests/s07_c_regressions.py s05_classification | 26 contrôles réussis | regression-classement/integration.json |
| node build.mjs, depuis frontend/ | Compilation réussie | build.log |
| python3 -B scripts/check_boundaries.py | Frontières conformes | boundaries.log |
| Empreintes protégées | 834 inchangées | integrite-apres.json |

93 contrôles C, 154 contrôles de non-régression. Ces nombres incluent les vérifications de connexion/MFA et ne sont pas des nombres de parcours UI.

Cas vérifiés : EICAR réellement détecté ; mauvais format ; quarantaine refusée ; interruption simulée du transport et du scan suivie de reprise réelle ; quatre préparations concurrentes donnant un seul objet ; reprise après une heure ; génération de scan périmée ; téléchargements identiques ; refus Storage direct et tables privées ; retrait de download pendant la récupération des octets ; autre organisation ; utilisateur hors conversation ; destinataire tardif ; ouverture puis retrait d’historique ; source ou destination révoquée ; suspension ; module et commercial retirés ; version de dossier périmée ; corbeille source et restauration sans retour des anciens droits.

Les suites tournent depuis application/ avec le runtime du projet et les services locaux. Elles utilisent les fixtures ignorées .local-auth. La recette finale principale conserve séparément sa fixture s07-c-final-check.json ; la recette UI et les cas limites utilisent s07-c-fixture.json. Le lanceur de régressions préserve les anciens dossiers de preuves. La recette Agenda livre uniquement dans Mailpit local.

## Interface et fidélité

Voir ui.json. Dépôt par le sélecteur de fichiers, aperçu auteur, classement via le menu de la pièce, navigation vers le coffre Dossiers et téléchargement réellement effectués. Les octets téléchargés par le navigateur sont identiques à piece-recette.png. Connexion distincte du lecteur : aperçu autorisé, téléchargement refusé et capturé à 390×844, 768×1024 et 1440×1000.

La recette a révélé l’absence de carte de pièce dans la branche des messages reçus ; le composant existant des messages envoyés y est maintenant réutilisé. L’aperçu du lecteur et les refus finaux ont été vérifiés après cette correction. Les premières captures auteur précèdent cette correction et l’ajout du choix explicite de reprise, sans différence sur leur parcours affiché.

Comparaison avec preuves/S02-messagerie/thread-390.png et preuves/S05-coffre/mobile-apercu.png : coque, bulles, bouton Joindre, menus, fenêtre et typographie conservés. Les états de scan apparaissent dans la carte existante. Les mesures observées restent dans le viewport : 382/390, 760/768 et 1440/1440. Recette sur viewports de navigateur, aucun appareil physique ; acceptation visuelle produit distincte.

## Limites et suite

- Une pièce par message, 5 Mio maximum. PDF/PNG/JPEG : aperçu inerte ; TXT/DOCX/XLSX : dépôt et téléchargement sous validation, sans aperçu promis par le coffre actuel.
- Le dépôt réserve un message avant le transfert ; un échec laisse un état de quarantaine traçable. Reprendre le même fichier ou demander sa corbeille ; aucune purge automatique.
- Le classement manuel traite un message entier ou une pièce. Qualification IA/création automatique de dossier, classement automatique d’extraits et signature restent explicitement indisponibles.
- Les droits s’appliquent à chaque requête ; l’invalidation spontanée d’un écran déjà affiché relève d’E. Aucune file durable hors ligne.
- La notification Agenda pour les comptes sans droits Agenda est indépendante de C. Les réserves S03 restent distinctes.
- D : transfert et recherche ; E : temps réel/notifications ; F : installation neuve, restauration, charge et clôture S07. Aucune réussite de restauration n’est déduite des lots antérieurs.

Lot C livré et vérifié localement. Prochaine étape : lot D. Aucun déploiement ni envoi externe.
