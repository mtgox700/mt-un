#!/usr/bin/env bash
# Publie une extension dans le registre : empreinte SRI + signature Ed25519 de l'éditeur.
# Usage : infra/publier-extension.sh front/public/ext/uniion-studio-1.2.0.js uniion-studio 1.2.0 "uniion Studio" cle-editeur.pem > registre.sql
# La clé privée ne quitte jamais le poste de l'éditeur (ni dépôt, ni VPS, ni CI).
# Clé publique à placer dans VITE_EXT_CLE_PUBLIQUE :
#   openssl pkey -in cle-editeur.pem -pubout -outform DER | tail -c 32 | base64
set -euo pipefail
fichier="$1"; id="$2"; version="$3"; nom="$4"; cle="$5"
[[ "$(basename "$fichier")" =~ ^[a-z0-9.-]+\.js$ ]] || { echo "nom de fichier invalide" >&2; exit 1; }
sri="sha384-$(openssl dgst -sha384 -binary "$fichier" | base64 -w0)"
sig="$(printf '%s' "$sri" | openssl pkeyutl -sign -inkey "$cle" -rawin | base64 -w0)"
cat <<SQL
insert into extension (id, version, nom, api, fichier, integrite_sri, signature)
values ('$id', '$version', '$nom', 1, '/ext/$(basename "$fichier")', '$sri', '$sig')
on conflict (id, version) do update set integrite_sri = excluded.integrite_sri, signature = excluded.signature;
SQL
