# Stratégie de fidélité au prototype — uniion App v3

**Référence unique** : `uniion App v3.dc.html`, figée sous l'étiquette **proto-v3.0** (23/10/2026). v1, v2 et `design_handoff_uniion/uniion App.dc.html` sont archivées et ne font plus foi.

**Ordre de priorité en cas de conflit** : 1. sécurité / droit (registre `ECARTS_PROTOTYPE.md`) · 2. **prototype** · 3. `SPECIFICATION.md` · 4. code existant.

## Livrables de cette étape

| Fichier | Rôle |
|---|---|
| `fidelite/INVENTAIRE_V3.md` | 87 sections du prototype, chacune avec ses états, actions, champs et libellés, et ses 6 cases de conformité |
| `fidelite/libelles-v3.json` | Tous les libellés statiques par section : source unique des textes de l'application |
| `fidelite/routes-v3.json` | Section → route du prototype → fichier de production |
| `fidelite/ECARTS_PROTOTYPE.md` | Écarts autorisés (seule porte de sortie à la fidélité) |
| `uniion-prod/front/src/ui/theme-v3.ts` | Moteur de thème **porté à l'identique** : 60 jetons clairs/sombres, 7 palettes, 4 duos de polices, 25 icônes |
| `uniion-prod/front/src/ui/global-v3.css` | Styles globaux du prototype (animations, focus, impression) |
| `uniion-prod/front/tests/fidelite.spec.ts` | Squelette Playwright de comparaison prototype / application |
| Crochet `window.__proto` dans le prototype | Permet aux tests de piloter le prototype (aucun effet visuel) |

## Constat (couverture actuelle de la production)

- **24 sections sur 66** ont un équivalent en production, mais il a été conçu **sans le prototype**. Elles sont à refaire, pas à corriger.
- **42 sections absentes** : ADM-SUP, ADM-ORG, ADM-USR, ADM-KEY, ADM-EDI, ADM-FAC, ADM-LOG, COQ-UNII, LEC, REP, SIG, SON-NEW, SON, SON-DET, REU, REU-DIC, REU-DET, DOC-GEN, RAC, INT, INT-GEN, INT-EDI, INT-PUB, INT-SUI, INT-CHA, NOT, RCH, UNII-CFG, COM, MOB, FOR, CTC, MEM, PAR-NOT, SEC-IA, PAR-RGPD, PAR-MAR, PAR-IA, ONB, ADB, MOD-ANON, UNII.
- `ui/kit.tsx` et `tokens.css` ont été réinventés. Ils sont remplacés par `theme-v3.ts` et `global-v3.css`.

## Méthode de portage (pour chaque section)

1. Ouvrir la section dans `INVENTAIRE_V3.md` et ses lignes dans le prototype.
2. **Copier le balisage** du prototype en JSX : mêmes éléments, mêmes styles inline (`style="a: b"` → `style={{a: 'b'}}`), mêmes `var(--…)`. Aucun composant maison n'est autorisé tant qu'il n'existe pas tel quel dans le prototype.
3. Remplacer chaque `{{ trou }}` par la donnée Supabase équivalente, et chaque `<sc-if>` / `<sc-for>` par une condition ou un `.map`.
4. Tirer les textes de `libelles-v3.json`, jamais en dur.
5. Brancher les actions de la liste « Actions », en gardant le même comportement visible (toast, transition, état suivant).
6. Ajouter l'entrée dans `fidelite.spec.ts` et joindre les captures à la demande de fusion.

Pour aller plus vite, un convertisseur `.dc.html` → JSX (styles et structure) peut être scripté : c'est la prochaine tâche recommandée.

## Contrôle

- **Visuel** : Playwright capture le prototype (piloté par `__proto.setState`) et l'application sur les mêmes données d'amorçage, à trois tailles (1440 × 900, 1024 × 768, 390 × 844). Seuil : 0,5 % de pixels différents. Au-delà, la CI bloque.
- **Libellés** : un test vérifie que chaque texte de `libelles-v3.json` de la section apparaît à l'écran, et qu'aucun texte inconnu n'y figure.
- **Données d'amorçage** : `supabase/seed.sql` reprend les données de démo du prototype (organisation « Section syndicale Métallurgie — Valenciennes », adhérents, dossiers, agenda). Sans cela, aucune comparaison pixel n'est possible.
- **Revue** : la gardienne ou le gardien du design valide chaque demande de fusion. Règle : **pas de case cochée sans capture**.

## Règle d'évolution

Tout besoin nouveau, qu'il s'agisse d'un écran, d'un état, d'un message d'erreur serveur ou d'une contrainte de sécurité visible, est **d'abord dessiné dans le prototype**, qui passe alors en proto-v3.1, puis régénéré (`INVENTAIRE`, `libelles`, `theme`), puis codé. Les développeurs ne conçoivent aucune interface.

## Plan

| Semaine | Contenu |
|---|---|
| 1 | Données d'amorçage alignées, CI de fidélité, convertisseur .dc.html → JSX, remplacement de `kit.tsx` / `tokens.css` |
| 2 | COQ-SB, COQ-MH, COQ-UNII, AUTH, ACC |
| 3 | DOS, DOS-NEW, DOS-DET, PJ, IA, UNII, MOD-ANON, MOD-IAERR |
| 4 | ADH, ADH-IMP, ADH-FIC, ADH-MSG, AGE, MSG |
| 5 | DOC, DOC-EDI, DOC-GEN, REU, SON, SIG, LEC, REP |
| 6 | PAR*, EXT, UNII-CFG, MEM, SEC-IA, CTC, NOT, RCH, OFF, ONB |
| 7 | INT*, COM*, MOB, FOR*, RAC, ADB, ADM* (console super-admin) |

Le backend (Supabase, règles d'accès, Edge Functions, passerelle IA) **ne change pas** : seul le front est reconstruit.
