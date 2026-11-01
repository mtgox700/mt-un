// Pièces jointes de dossier. Aucun accès direct au bucket « pieces » : tout passe ici.
// Dépôt : contrôle de périmètre → type et taille → analyse antivirus (clamd) → empreinte SHA-256 →
// chiffrement AES-GCM lié à la pièce → stockage. Téléchargement : contrôle → journal d'accès →
// déchiffrement → flux. Le fichier n'est jamais stocké en clair ni servi par URL publique.
import { CORS, journaliser, json, nouvelId, utilisateur } from '../_shared/auth.ts';
import { chiffrerOctets, dechiffrerOctets } from '../_shared/coffre.ts';
import { analyser } from '../_shared/antivirus.ts';

const MAX = 80 * 1024 * 1024;
const TYPES = new Set(['application/pdf', 'image/jpeg', 'image/png', 'image/webp', 'image/heic', 'text/plain', 'text/csv',
  'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/vnd.oasis.opendocument.text', 'application/vnd.oasis.opendocument.spreadsheet', 'message/rfc822', 'audio/mpeg', 'audio/mp4']);

const hex = async (o: Uint8Array) => [...new Uint8Array(await crypto.subtle.digest('SHA-256', o))].map((b) => b.toString(16).padStart(2, '0')).join('');
const nomSur = (n: string) => n.normalize('NFC').replace(/[\\/:*?"<>|\u0000-\u001f]/g, '_').slice(0, 180);

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: CORS });
  const u = await utilisateur(req);
  if (u instanceof Response) return u;
  const accesDossier = async (d: string) => !!(await u.client.from('dossier').select('id').eq('id', d).maybeSingle()).data;

  // ---- Dépôt (multipart/form-data : dossier_id, fichier)
  if ((req.headers.get('content-type') ?? '').startsWith('multipart/form-data')) {
    const form = await req.formData();
    const dossierId = String(form.get('dossier_id') ?? '');
    const fichier = form.get('fichier');
    if (!(fichier instanceof File)) return json({ erreur: 'fichier manquant' }, 400);
    if (!(await accesDossier(dossierId))) return json({ erreur: 'dossier inaccessible' }, 404);
    if (fichier.size > MAX) return json({ erreur: 'fichier trop volumineux (80 Mo au plus)' }, 413);
    if (!TYPES.has(fichier.type)) return json({ erreur: 'type de fichier non accepté' }, 415);

    const octets = new Uint8Array(await fichier.arrayBuffer());
    const av = await analyser(octets);
    if (av === 'infecte') {
      await journaliser(u, 'piece.rejet_antivirus', 'dossier', dossierId, nomSur(fichier.name));
      return json({ erreur: 'Fichier refusé : contenu malveillant détecté.' }, 422);
    }
    const id = nouvelId('pj');
    const chemin = `${u.orgId}/${dossierId}/${id}`;
    const chiffre = await chiffrerOctets(u.orgId, octets, ':' + id);
    const { error: e1 } = await u.admin.storage.from('pieces').upload(chemin, chiffre, { contentType: 'application/octet-stream', upsert: false });
    if (e1) return json({ erreur: 'stockage indisponible' }, 503);
    const { error: e2 } = await u.admin.from('piece_jointe').insert({
      id, dossier_id: dossierId, nom: nomSur(fichier.name), type_mime: fichier.type, taille_octets: fichier.size,
      empreinte: await hex(octets), chemin_chiffre: chemin, antivirus_ok: av === 'ok', depose_par: u.personneId,
    });
    if (e2) { await u.admin.storage.from('pieces').remove([chemin]); return json({ erreur: 'enregistrement impossible' }, 500); }
    // Antivirus indisponible : pièce gardée mais bloquée au téléchargement, réanalyse par la file.
    if (av === 'indisponible') await u.admin.from('tache_file').insert({ id: nouvelId('tch'), organisation_id: u.orgId, nature: 'antivirus',
      charge: { piece_id: id }, idempotency_key: 'av:' + id });
    await u.admin.from('dossier_historique').insert({ id: nouvelId('hist'), dossier_id: dossierId, titre: 'Pièce ajoutée', corps: nomSur(fichier.name), auteur_id: u.personneId });
    return json({ id, antivirus: av });
  }

  const { action, piece_id, motif } = await req.json().catch(() => ({}));
  const { data: piece } = await u.client.from('piece_jointe').select('id, dossier_id, nom, type_mime, chemin_chiffre, antivirus_ok, depose_par').eq('id', piece_id).maybeSingle();
  if (!piece) return json({ erreur: 'pièce inaccessible' }, 404);

  if (action === 'telecharger' || action === 'apercu') {
    if (!piece.antivirus_ok) return json({ erreur: 'analyse antivirus en attente' }, 423);
    const { data: blob, error } = await u.admin.storage.from('pieces').download(piece.chemin_chiffre);
    if (error || !blob) return json({ erreur: 'stockage indisponible' }, 503);
    const clair = await dechiffrerOctets(u.orgId, new Uint8Array(await blob.arrayBuffer()), ':' + piece.id);
    await u.admin.from('piece_acces_log').insert({ piece_id: piece.id, personne_id: u.personneId, action: action === 'apercu' ? 'lecture' : 'telechargement' });
    return new Response(clair, { headers: { ...CORS,
      'content-type': piece.type_mime, 'cache-control': 'no-store', 'x-content-type-options': 'nosniff',
      'content-disposition': `${action === 'apercu' ? 'inline' : 'attachment'}; filename*=UTF-8''${encodeURIComponent(piece.nom)}`,
      'content-security-policy': "default-src 'none'; img-src 'self'; style-src 'unsafe-inline'; sandbox" } });
  }

  if (action === 'supprimer') {
    const { data: d } = await u.client.from('dossier').select('referent_id').eq('id', piece.dossier_id).single();
    if (piece.depose_par !== u.personneId && d?.referent_id !== u.personneId) return json({ erreur: 'réservé au déposant ou au référent' }, 403);
    await u.admin.from('piece_jointe').update({ supprime_le: new Date().toISOString() }).eq('id', piece.id);  // corbeille 30 j
    await journaliser(u, 'piece.supprimer', 'piece_jointe', piece.id, motif ?? null);
    return json({ ok: true });
  }
  return json({ erreur: 'action inconnue' }, 400);
});
