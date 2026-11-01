# Polices auto-hébergées

Le prototype chargeait ses polices depuis Google Fonts (bloquant 1.7 : l'adresse IP de chaque militant part chez un tiers).
En production, déposer ici les fichiers `.woff2` (sous-ensemble latin) et `studio.css` qui les déclare.

Familles utilisées par uniion Studio 1.2.0 (toutes sous licence SIL OFL, redistribution autorisée) :
Anton · Archivo (400/600/800) · Archivo Black · Barlow (400/600/800) · Barlow Condensed (600/800) · Bebas Neue ·
DM Serif Display · IBM Plex Sans (400/600) · Libre Franklin (400/600/800) · Newsreader (400/600/700, 400 italique) ·
Permanent Marker · Playfair Display (700/900) · Source Serif 4 (400/600, 400 italique) · Space Grotesk (400/600/700) ·
UnifrakturMaguntia · Oswald (500/700) · Bangers · Comic Neue (700) · Special Elite

Application : polices de `tokens.css` (Philosopher, Inter, Caveat, Montserrat, Lora — ne garder que celles des présets de marque).

Récupération : `npx google-font-downloader` ou https://gwfh.mranftl.com (sortie woff2 + CSS à chemins relatifs), puis
vérifier qu'aucune URL externe ne subsiste : `grep -r "https://" front/public/fonts`.
