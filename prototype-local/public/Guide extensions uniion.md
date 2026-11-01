# Extensions uniion — Guide de développement

Version de l'API : **1** (révision 1.1) · Hôte : `uniion App v3.dc.html` · Extension de référence : `extensions/uniion-studio.js` 1.1.0

---

## 1. Principe

Une extension est **un fichier JavaScript autonome** qui déclare ce qu'il apporte (styles, blocs, thèmes, sections) dans un **manifeste**. L'application (l'« hôte ») lit ce manifeste et branche les contributions à des **points d'extension** prévus à l'avance. L'extension ne modifie jamais le code, l'état ni l'interface d'uniion : elle **fournit des fonctions pures** que l'hôte appelle quand il en a besoin.

### Garanties de l'hôte

| Garantie | Mise en œuvre |
|---|---|
| Sans extension, uniion est identique à la version précédente | Chaque point d'extension est inactif tant qu'aucune contribution n'est présente : pas d'onglet « Style », pas de carte « Thème », HTML produit au caractère près. |
| Désactiver une extension ne casse rien | Les champs ajoutés (`style`, `theme`…) sont ignorés si la contribution n'existe plus ; les blocs d'extension s'affichent comme des paragraphes et **conservent leur contenu**. |
| Une erreur d'extension ne bloque pas l'application | Chaque appel est isolé (`try/catch`). En cas d'erreur, l'hôte utilise le rendu d'origine et journalise l'erreur dans **Paramètres › Extensions**. |
| Aucune donnée n'est migrée | Les documents et pages existants n'ont pas de champ `style`/`theme` : ils restent en rendu « Classique ». |

---

## 2. Charger une extension

Trois façons, par ordre de préférence :

1. **Extension intégrée** : une balise dans le `<helmet>` de l'application.
   ```html
   <script src="./extensions/mon-extension.js"></script>
   ```
2. **Installation par l'utilisateur** : *Paramètres › Extensions › Installer une extension*, en indiquant un chemin relatif `./…js` ou une adresse `https://…js`. L'adresse est mémorisée et rechargée à chaque ouverture.
3. **Console / tests** : `window.uniion.register(manifeste)`.

### Modèle d'amorçage (obligatoire)

L'extension peut se charger **avant** ou **après** l'hôte. Elle doit donc utiliser ce motif, qui place le manifeste en file d'attente si l'hôte n'est pas encore prêt :

```js
(function () {
  var manifest = { /* … */ };
  var U = window.uniion = window.uniion || {};
  if (typeof U.register === 'function') U.register(manifest);
  else (U.queue = U.queue || []).push(manifest);
})();
```

Encapsulez tout le code dans une fonction immédiatement exécutée. **Aucune variable globale**, à part `window.uniion`, qui appartient à l'hôte.

---

## 3. Le manifeste

```js
{
  id: 'mon-extension',             // obligatoire — minuscules, chiffres, tirets (2 à 41 caractères), unique
  name: 'Mon extension',           // obligatoire — affiché dans Paramètres › Extensions
  version: '1.0.0',                // semver
  apiVersion: 1,                   // obligatoire — version de l'API visée
  author: 'Union départementale FO 59',
  description: 'Une phrase sur ce que l\'extension apporte.',
  minPlan: 'p2',                   // facultatif — offre minimale (p1 Élu 1.0, p2 Élu 2.0, p3, p4)
  permissions: ['documents.styles', 'pages.themes'],   // déclaratif, affiché à l'utilisateur
  assets: { css: ['https://fonts.googleapis.com/css2?family=…'] },  // feuilles chargées une seule fois
  contributes: {
    docStyles:   [ /* §4.1 */ ],
    docBlocks:   [ /* §4.2 */ ],
    pageThemes:  [ /* §4.3 */ ],
    pageSections:[ /* §4.4 */ ],
    pageDevices: [ /* §4.5 */ ]
  }
}
```

Un manifeste sans `id`, sans `name`, sans `contributes` ou avec une version d'API non prise en charge est **refusé**. Le refus apparaît dans *Paramètres › Extensions › Extensions refusées au chargement*.

Si une extension est enregistrée deux fois avec le même `id`, la seconde **remplace** la première (rechargement à chaud).

### Permissions reconnues

| Permission | Libellé affiché |
|---|---|
| `documents.styles` | Mettre en page les documents |
| `documents.blocks` | Ajouter des blocs aux documents |
| `pages.themes` | Habiller les pages web |
| `pages.sections` | Ajouter des sections aux pages |
| `pages.devices` | Aperçus par appareil |
| `unii.hints` | Donner des consignes de rédaction à unii |

Elles servent à **informer** l'administrateur. L'utilisateur peut ensuite désactiver individuellement chaque contribution (un style, un bloc…).

---

## 4. Points d'extension

### 4.1 `docStyles` — styles de documents et tracts

Un style prend la page entière en charge (fond, en-tête, mise en page des blocs). Il apparaît dans l'onglet **Style** de l'éditeur de documents, à côté du style **Classique** (la charte graphique de l'organisation, c'est-à-dire le rendu habituel).

```js
{
  id: 'choc',                       // unique dans l'extension
  label: 'Affiche choc',
  desc: 'Un chiffre géant, un refus, des revendications surlignées.',
  formats: ['a5', 'a4'],            // formats conseillés (a4, a5, wide) — le premier est proposé
  palettes: [{ id: 'rouge', label: 'Rouge FO', colors: { a: '#E3051B', b: '#FFE14D', c: '#5BC4C4', d: '#FFFFFF' } }],
  fonts:    [{ id: 'anton', label: 'Anton', head: "'Anton', sans-serif", body: "'Archivo', sans-serif", hand: "'Permanent Marker', cursive" }],
  suits: ['tract', 'mobilisation', 'nao'],   // mots-clés : unii propose ce style s'ils apparaissent dans le document
  uniiHint: 'Consigne de rédaction transmise à unii quand ce style est choisi.',
  notice: 'Règle affichée à l\'utilisateur (ex. satire : aucune personne reconnaissable).',  // facultatif
  review: 'satire',                 // facultatif — signale un format sensible
  slots: [{ id: 'img0', label: 'Photo de fond', type: 'studio.photo', index: 0, optional: false }],  // API 1.2 — images attendues
  render: function (ctx) { return ctx.h('div', { style: { … } }, …); }
}
```

**Couleurs.** Leur sens est libre, mais la convention suivante facilite la cohérence : `a` = accent, `b` = seconde couleur, `c` = encre/sombre, `d` = fond/papier.

#### Emplacements d'images (`slots`, API 1.2)

Un style qui affiche des images **doit les déclarer** : sans cela, l'utilisateur ne sait pas où les ajouter. Chaque emplacement désigne le *n*-ième bloc d'un type qui accepte une image (`accepts: 'image'`).
- L'onglet **Style** affiche une ligne par emplacement, avec un bouton « Déposer une image ». Si le bloc n'existe pas encore, l'hôte le crée (après le titre principal).
- Tant qu'un emplacement non facultatif est vide, un bandeau « Ce style attend une image » s'affiche en haut du panneau Contenu.
- On peut aussi **glisser une image sur l'aperçu** : elle remplit le premier emplacement vide.
- Dans `render`, lisez l'image avec `ctx.all(type)[index]`, puis `b.img`. Un bloc d'emplacement ne doit pas être affiché une seconde fois dans le flux.

#### `render(ctx)` — appelée une fois par page

Elle doit renvoyer **un seul élément React** qui occupe `100 %` de la page (`position: relative; width: 100%; height: 100%; overflow: hidden`). La page fait `ctx.format.w × ctx.format.h` pixels CSS, sans marge : c'est le style qui gère ses marges intérieures.

| Propriété de `ctx` | Contenu |
|---|---|
| `h` | `React.createElement` — seul moyen de produire du rendu (pas de JSX, pas de HTML brut). |
| `blocks` | Blocs de **la page courante** : `[{ id, type, text }]`. Les sauts de page sont déjà appliqués. |
| `first(type)` / `all(type)` | Premier bloc / tous les blocs d'un type sur la page. |
| `block(b, k)` | Rend un bloc d'extension (§4.2) avec votre kit visuel `k` ; renvoie `null` si le type est inconnu. |
| `lines(s)` / `cells(l)` | Découpe en lignes non vides / en cellules séparées par `|`. |
| `colors` | Palette choisie par l'utilisateur : `{ a, b, c, d }`. |
| `fonts` | Polices choisies : `{ head, body, hand? }`. |
| `format` | `{ id: 'a4' | 'a5' | 'wide', w, h }`. |
| `u` | Facteur d'échelle = `format.w / 420`. Concevez à 420 px de large et multipliez toutes les tailles par `u`. |
| `page` | `{ index, count }` (index commence à 0). |
| `org` | `{ emetteur, section, contact, logo }` — identité de l'organisation, déjà anonymisable. |

**Types de blocs du cœur** que tout style doit savoir afficher, au minimum comme du texte : `tag` (badge), `h1`, `h2`, `h3`, `p`, `ul` (une ligne = un élément), `quote` (encadré), `table` (lignes, cellules séparées par `|`). Les sauts de page (`pagebreak`) sont retirés avant l'appel.

**Règles de rendu**
- Fonction **pure et rapide** : pas d'accès au réseau, au stockage ni au DOM, et pas de minuteur. Elle est appelée à chaque frappe, pour chaque page, et aussi pour les 3 aperçus réduits proposés par unii.
- Styles **en ligne uniquement** (objets `style`), pour que l'impression et le PDF fonctionnent. Ajoutez `WebkitPrintColorAdjust: 'exact', printColorAdjust: 'exact'` sur les fonds colorés.
- Prévoyez le **débordement** : `overflow: hidden` sur les zones de texte, et une taille de titre adaptée à la longueur du texte (voir `fit()` dans uniion Studio).
- Un bloc que le style ne met pas en valeur doit quand même apparaître quelque part. Utilisez un rendu générique (voir `flow()` dans uniion Studio).
- Contraste : texte à au moins 4,5:1 sur son fond. Pour du texte posé sur la couleur d'accent, calculez la couleur lisible (voir `onC()`).

### 4.2 `docBlocks` — nouveaux blocs de document

Ces blocs apparaissent dans la barre « + » de l'éditeur. Ils s'affichent dans le style Classique comme dans tous les styles.

```js
{
  type: 'studio.chiffre',           // OBLIGATOIREMENT préfixé : « <votre-prefixe>.<nom> »
  label: 'Chiffre clé',
  ph: '68 %\nLégende',              // texte d'aide dans la zone de saisie
  rows: 2,                          // hauteur de la zone de saisie
  sample: '68 %\ndes salariés…',    // contenu inséré à l'ajout
  hint: '1re ligne : le chiffre. 2e ligne : la légende.',
  estimateHeight: function (b) { return 120; },   // hauteur estimée (px à l'échelle 1) pour l'alerte de débordement
  accepts: 'image',                 // facultatif (API 1.1) — l'éditeur affiche « Déposer une image »
  render: function (b, k) { return k.h('div', …); }
}
```

`render(b, k)` reçoit le bloc et un **kit visuel** :

| `k` | Contenu |
|---|---|
| `h` | `React.createElement` |
| `u` | Échelle (multipliez vos tailles) |
| `accent`, `accent2`, `ink`, `paper` | Couleurs : celles de la charte en style Classique, celles du style sinon |
| `head`, `body`, `hand` | Polices |
| `lines(s)` | Utilitaire de découpe |

Un style peut ajouter ses propres clés au kit (ex. `mark` pour la couleur des bandeaux surlignés, `stamp` pour celle du tampon).

**Images (API 1.1).** Un bloc qui déclare `accepts: 'image'` reçoit un bouton de dépôt dans l'éditeur. L'hôte réduit l'image (1400 px au plus, JPEG) et la place dans `b.img` (URL `data:`). Votre `render` lit `b.img` en priorité, puis éventuellement une adresse collée dans le texte. Les styles qui affichent une photo doivent faire de même (voir `srcOf()` dans uniion Studio). L'image reste sur l'appareil : elle est enregistrée avec le document et n'est envoyée nulle part, et surtout jamais à unii.

**Contenu = texte.** Toute la donnée d'un bloc tient dans `b.text`, au format lignes / cellules `|`. C'est ce qui garantit la conservation :
- en Markdown, un bloc d'extension s'écrit `:::type`, puis son texte, puis `:::`, et il revient intact après un aller-retour ;
- si l'extension est désactivée, le bloc s'affiche en paragraphe et l'éditeur indique « Bloc … (extension inactive) ».

### 4.3 `pageThemes` — thèmes de pages intranet et internet

Un thème **habille** une page sans modifier sa structure HTML. Il produit une feuille de style **limitée à la page** grâce à l'attribut `data-theme`.

```js
{
  id: 'militant',
  label: 'Militant',
  desc: 'Bandeau plein de couleur, titres condensés.',
  palettes: [{ id: 'r', label: 'Rouge et jaune', colors: { a: '#E3051B', b: '#FFE14D', c: '#14141A', d: '#FFFFFF' } }],
  css: function (ctx) { return '.up-site[data-theme="militant"]{ … }'; }
}
```

- `ctx` = `{ colors, charte }`. `charte` contient la charte du site (accent, titres…) si vous voulez en hériter.
- **Toutes les règles doivent commencer par `.up-site[data-theme="<id>"]`** (vérifié par l'auto-test).
- Le moyen le plus robuste consiste à redéfinir les variables de la feuille du site : `--up-accent`, `--up-head`, `--up-tint`, `--up-tint2`, `--up-r` (arrondi), puis à surcharger quelques classes.
- Classes disponibles : `up-util`, `up-head`, `up-brand`, `up-logo`, `up-search`, `up-nav`, `up-crumb`, `up-hero`, `up-kicker`, `up-chapo`, `up-byline`, `up-main`, `up-article`, `up-callout`, `up-cta`, `up-file`, `up-share`, `up-aside`, `up-card`, `up-btn`, `up-tag`, `up-foot`, `up-legal`.
- La feuille est **intégrée au HTML exporté** (`<style data-uniion-ext="…">`), pour que le webmaster reçoive une page complète. Les balises `<style>` et `<script>` éventuelles sont retirées.

### 4.4 `pageSections` — sections de pages web

Ces sections apparaissent dans « Ajouter une section » de l'éditeur de page.

```js
{
  type: 'studio.faq',               // préfixé, comme les blocs
  label: 'FAQ dépliable',
  rows: 4, sample: 'Question ? | Réponse', hint: 'Une ligne par question : question | réponse.',
  css: '.up-site .ux-faq details{…}',      // feuille commune, intégrée une seule fois si la section est utilisée
  html: function (b, x) { return '  <section class="ux-sec ux-faq">…</section>'; }
}
```

- `x` = `{ esc, lines, cells }`. **Échappez tout texte saisi avec `x.esc()`.**
- Produisez du **HTML sémantique et accessible** (titres, `details/summary`, `aria-label`). L'hôte supprime automatiquement tout `<script>` et tout attribut `on…=`.
- Préfixez vos classes (`ux-…`) pour ne pas entrer en collision avec la feuille du site.
- Les sections s'appuient de préférence sur les variables `--up-accent`, `--up-head` et `--up-r`, pour suivre automatiquement la charte ou le thème.
- Le bloc ajouté est marqué `ext: '<id-extension>'`. Sans l'extension, son texte reste affiché en paragraphe.
- **Génération par unii (API 1.1)** : quand l'utilisateur fait composer une page complète (*Générer la page HTML*), l'hôte transmet à unii la liste des sections disponibles, avec `type`, `label` et `hint`. unii peut en utiliser deux au plus, avec les seules informations fournies par l'élu. Rédigez donc un `hint` qui décrit précisément le format attendu.

### 4.5 `pageDevices` — aperçus par appareil

```js
pageDevices: [{ id: 'desktop', label: 'Ordinateur', width: null }, { id: 'tablet', label: 'Tablette', width: 640 }, { id: 'mobile', label: 'Mobile', width: 360 }]
```

Ces largeurs ajoutent un sélecteur au-dessus de l'aperçu de page. Si plusieurs extensions déclarent le même `id`, le premier déclaré est retenu.

Depuis l'API 1.1, une largeur fixe affiche la page dans un **cadre isolé** à cette largeur. Les règles `@media` de la feuille du site et des thèmes s'y appliquent donc réellement. Les polices déclarées dans `assets.css` y sont chargées. La largeur `null` conserve l'aperçu habituel.

---

## 5. unii et les extensions

- **`uniiHint`** (style) : quand un document utilise ce style, la consigne est ajoutée au contexte envoyé à unii, ainsi que `notice` le cas échéant. Le bouton *Adapter le texte à ce style avec unii* l'utilise aussi.
- **`suits`** (style) : unii propose les 3 styles dont les mots-clés apparaissent le plus dans le document (modèle, titre, texte), avec un aperçu réduit de la page 1.
- Les propositions d'unii suivent les règles de l'hôte : réservées à l'offre Élu 2.0 et au-delà, anonymisation, **rien n'est appliqué sans un clic de l'utilisateur**.
- Une extension **n'appelle jamais unii ni aucun modèle elle-même**. Elle fournit des consignes ; c'est l'hôte qui envoie la demande, anonymisée.

---

## 6. Règles impératives

1. **Aucune donnée ne sort.** Pas de `fetch`, pas de `XMLHttpRequest`, pas d'image de pistage. Les seules ressources externes autorisées sont les feuilles déclarées dans `assets.css` (polices).
2. **Aucun accès au stockage** (`localStorage`, cookies) ni à l'état d'uniion. L'extension ne reçoit que ce que l'hôte lui passe.
3. **Fonctions pures.** Même entrée, même rendu. Pas d'effet de bord, pas de minuteur.
4. **Données personnelles.** Les exemples (`sample`) n'utilisent que des prénoms et une initiale, avec des coordonnées professionnelles. Ne jamais suggérer de numéro ni d'adresse personnels.
5. **Formats satiriques** (`review: 'satire'`) : `notice` est obligatoire. On caricature une décision, jamais une personne. Ni nom, ni visage reconnaissable, ni expression discriminatoire.
6. **Accessibilité.** Contraste suffisant, texte réel plutôt qu'image, HTML web sémantique.
7. **Préfixes.** Les types de blocs et de sections sont préfixés par un identifiant propre à l'extension (`studio.`). Les classes CSS web sont préfixées (`ux-`).

---

## 7. Erreurs et diagnostic

- Toute exception levée par `render`, `css`, `html` ou `estimateHeight` est interceptée. L'hôte utilise alors le rendu d'origine et ajoute l'erreur au journal de l'extension (*Paramètres › Extensions*, encadré rouge).
- `window.uniion.extensions` liste les manifestes chargés, et `window.uniion.errors` les erreurs (40 au plus).
- Après chaque `register()`, l'hôte émet l'événement `uniion:extensions` et se redessine.

### Auto-test intégré

*Paramètres › Extensions › Lancer l'auto-test* vérifie :

1. **Pages web sans thème** : HTML **identique au caractère près**, extensions actives ou désactivées.
2. **Documents** : tous les blocs sont conservés après un aller-retour Markdown.
3. **Blocs d'extension** : leurs types sont conservés en Markdown (`:::type`), même extension désactivée.
4. **Styles** : chaque style est rendu sans erreur sur chaque document, avec tous les blocs d'extension ajoutés.
5. **Thèmes** : la feuille produite est bien limitée à `data-theme`.
6. **Sections** : le HTML produit ne contient ni script ni gestionnaire d'événement.
7. **Journal** : aucune erreur.

---

## 8. Recette de non-régression avant publication

À faire pour chaque nouvelle extension ou version :

- [ ] L'auto-test est entièrement vert.
- [ ] **Extension désactivée** : l'éditeur de documents n'affiche plus l'onglet Style, la page web n'affiche plus la carte Thème, et l'impression PDF d'un document Classique est inchangée.
- [ ] **Style choisi, puis extension désactivée** : le document revient en Classique sans perte de texte. On réactive : le style revient.
- [ ] **Bloc d'extension inséré, puis extension désactivée** : le texte est visible en paragraphe, et l'éditeur indique « extension inactive ».
- [ ] Les trois formats (A4, A5, 16:9) sont lisibles. Un titre long ne déborde pas et un document vide ne produit pas d'erreur.
- [ ] L'impression / PDF reproduit les fonds et les couleurs.
- [ ] Une page web avec thème, envoyée au webmaster, contient bien sa feuille de style intégrée.
- [ ] Les 33 actions unii et les pastilles fonctionnent comme avant.

---

## 9. Versions de l'API

- `apiVersion: 1` : version décrite ici.
- Les ajouts compatibles (nouveaux champs facultatifs dans `ctx`, nouveaux points d'extension) **ne changent pas** le numéro de version.
- Une modification incompatible passera à la version 2. L'hôte continuera alors d'accepter la version 1 pendant au moins une version majeure.
- L'hôte refuse toute extension dont `apiVersion` est supérieure à la sienne.

---

## 10. Exemple minimal complet

```js
/* extensions/ud59-affiche.js */
(function () {
  var manifest = {
    id: 'ud59-affiche', name: 'Affiche UD 59', version: '1.0.0', apiVersion: 1,
    author: 'UD FO 59', description: 'Un style d\'affiche aux couleurs de l\'union départementale.',
    permissions: ['documents.styles'],
    contributes: {
      docStyles: [{
        id: 'ud59', label: 'Affiche UD 59', desc: 'Bandeau, titre, liste.', formats: ['a5'],
        palettes: [{ id: 'base', label: 'UD 59', colors: { a: '#B0001A', b: '#FFD23F', c: '#141414', d: '#FFFFFF' } }],
        fonts: [{ id: 'base', label: 'Archivo', head: "'Archivo Black', sans-serif", body: "'Archivo', sans-serif" }],
        suits: ['tract'], uniiHint: 'Titre de 6 mots maximum, 3 revendications en liste.',
        render: function (ctx) {
          var h = ctx.h, c = ctx.colors, f = ctx.fonts, u = function (n) { return n * ctx.u + 'px'; };
          var t = ctx.first('h1'), ul = ctx.first('ul');
          return h('div', { style: { width: '100%', height: '100%', overflow: 'hidden', background: c.d, color: c.c, padding: u(28), boxSizing: 'border-box', display: 'flex', flexDirection: 'column', gap: u(14) } },
            h('div', { style: { background: c.a, color: '#FFFFFF', fontFamily: f.body, fontWeight: 800, padding: u(8), WebkitPrintColorAdjust: 'exact', printColorAdjust: 'exact' } }, ctx.org.emetteur),
            t ? h('div', { style: { fontFamily: f.head, fontSize: u(40), lineHeight: 1 } }, t.text) : null,
            ul ? h('ul', { style: { fontFamily: f.body, fontSize: u(14) } }, ctx.lines(ul.text).map(function (l, i) { return h('li', { key: i }, l); })) : null);
        }
      }]
    }
  };
  var U = window.uniion = window.uniion || {};
  if (typeof U.register === 'function') U.register(manifest); else (U.queue = U.queue || []).push(manifest);
})();
```

Pour l'installer : *Paramètres › Extensions › Installer*, puis indiquer `./extensions/ud59-affiche.js`.

---

## 11. Référence : uniion Studio 1.0.0

| Point d'extension | Contenu |
|---|---|
| Styles de documents (12) | Affiche choc, Journal syndical, Infographie, Institutionnel sobre, Photo pleine page, Sérigraphie militante, Bulletin d'information, Question / réponse, Journal satirique, Bande dessinée, Petite annonce parodique, Affiche rétro — chacun avec 2 à 4 palettes et 2 à 3 associations de polices. |
| Blocs de documents (12) | Chiffre clé, Comparatif, Frise de dates, Photo, QR code (emplacement), Coupon d'adhésion, Trombinoscope, Tampon, Bandeau surligné, Signature, Bulles de dialogue, Encadré « FO exige ». |
| Thèmes de pages (6) | Éditorial, Moderne à cartes, Militant, Institutionnel, Magazine, Minimal — 3 palettes chacun. |
| Sections de pages (7) | Bandeau d'accroche, Chiffres clés, Frise de la négociation, FAQ dépliable, Cartes des élus, Agenda, Appel à adhérer. |
| Aperçus | Ordinateur, tablette (640 px), mobile (360 px). |

---

## 12. Historique

### API 1.2 · uniion App v3 · uniion Studio 1.2.0
- Déclaration `slots` sur les styles. L'hôte affiche les emplacements dans l'onglet Style, signale les images manquantes et accepte une image glissée sur l'aperçu.
- Studio : emplacements déclarés pour Photo pleine page, Journal satirique (dessin et mascotte), Affiche rétro, Bande dessinée (3 cases), Journal syndical et Bulletin (facultatifs).

### API 1.1 · uniion App v3 · uniion Studio 1.1.0
Évolutions compatibles : toute extension écrite pour la version 1.0 fonctionne sans modification.

| Évolution | Hôte (v3) | Extension (Studio 1.1.0) |
|---|---|---|
| Dépôt d'images | Bouton « Déposer une image » pour les blocs `accepts: 'image'`, réduction automatique, champ `b.img` conservé lors de l'édition en Markdown | Bloc Photo, et styles Photo pleine page, Journal satirique et Affiche rétro alimentés par l'image déposée |
| QR code réel | — | Encodeur intégré (octets, correction M, jusqu'à 213 caractères), rendu vectoriel imprimable, sans service externe |
| Aperçu par appareil | Cadre isolé à la largeur choisie : les `@media` s'appliquent | — |
| Page complète par unii | Choix du thème dans *Générer la page HTML* ; sections d'extension proposées à unii | `hint` des sections rédigés pour unii |

Non-régression : sans extension, aucun de ces ajouts n'est visible. Le cadre isolé ne s'active que sur une largeur choisie, et l'aperçu « Ordinateur » reste l'aperçu habituel.

### API 1.0 · uniion App v2 · uniion Studio 1.0.0
Première version : styles et blocs de documents, thèmes et sections de pages, aperçus par appareil, Paramètres › Extensions, auto-test.
