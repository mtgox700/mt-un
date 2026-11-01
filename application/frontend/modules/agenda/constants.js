export const AG_TYPES = [
  { id: 'cse', label: 'Réunion CSE', bg: 'var(--acBg)', fg: 'var(--acTx2)', dot: 'var(--ac2)' },
  { id: 'nego', label: 'Négociation', bg: 'var(--infoBg)', fg: 'var(--infoTx2)', dot: 'var(--info)' },
  { id: 'perm', label: 'Permanence', bg: 'var(--okBg)', fg: 'var(--okTx)', dot: 'var(--ok)' },
  { id: 'form', label: 'Formation', bg: 'var(--priBg)', fg: 'var(--pri)', dot: 'var(--pri)' },
  { id: 'ag', label: 'Assemblée', bg: 'var(--warnBg)', fg: 'var(--warnTx)', dot: 'var(--warnTx)' },
  { id: 'ech', label: 'Échéance', bg: 'var(--dangerBg)', fg: 'var(--danger)', dot: 'var(--danger)' }
];
export const AG_VISIB = [
  { id: 'elus', label: 'Élus seulement', note: 'Visible des seuls titulaires et suppléants.' },
  { id: 'adherents', label: 'Élus et adhérents', note: 'Publié dans l\'espace adhérents ; convocation possible par campagne.' },
  { id: 'public', label: 'Tous les salariés', note: 'Repris sur l\'intranet — aucune donnée nominative dans le titre.' }
];
export const AG_MOIS = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
export const AG_JOURS = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
export const AG_JOURS_C = ['lun', 'mar', 'mer', 'jeu', 'ven', 'sam', 'dim'];
export const AG_EVENTS = [
  { id: 'e1', date: '2026-09-02', start: '09:00', end: '12:00', type: 'nego', title: 'NAO — 3ᵉ séance', lieu: 'Salle du conseil, siège', org: 'Delphine Marchand', visib: 'elus', invites: ['Délégation NAO', 'Expert-comptable du CSE'], notes: 'Remise du cahier revendicatif consolidé. Position de repli à arrêter la veille en réunion préparatoire.' },
  { id: 'e2', date: '2026-09-02', start: '12:15', end: '13:15', type: 'ag', title: 'Assemblée des adhérents', lieu: 'Réfectoire, site de Valenciennes', org: 'Karim Benali', visib: 'adherents', invites: ['Tous les adhérents'], notes: 'Compte rendu de la 2ᵉ séance NAO et mandat de négociation.' },
  { id: 'e3', date: '2026-09-03', start: '09:00', end: '12:30', type: 'cse', title: 'CSE ordinaire — septembre', lieu: 'Salle du conseil, siège', org: 'Secrétaire du CSE', visib: 'elus', invites: ['Titulaires', 'Suppléants', 'Représentants syndicaux'], notes: 'Ordre du jour transmis 3 jours avant. Avis différé sur la réorganisation logistique.' },
  { id: 'e4', date: '2026-09-04', start: '12:00', end: '14:00', type: 'perm', title: 'Permanence des élus', lieu: 'Local syndical, bâtiment C', org: 'Élus de permanence', visib: 'public', invites: ['Sur inscription libre'], notes: 'Sans rendez-vous. Deux élus présents, dont un référent SSCT.' },
  { id: 'e5', date: '2026-09-08', start: '', end: '', type: 'ech', title: 'Réponse de la direction — enquête Atelier B', lieu: '', org: 'Référent SSCT', visib: 'elus', invites: [], notes: 'Délai de réponse à la saisine du 26 août. Sans réponse, relance écrite et inscription à l\'ordre du jour.' },
  { id: 'e6', date: '2026-09-10', start: '09:00', end: '17:00', type: 'form', title: 'Formation SSCT — module 2', lieu: 'Centre de formation, Douai', org: 'Organisme agréé', visib: 'elus', invites: ['3 élus inscrits'], notes: 'Prise en charge sur le budget de fonctionnement. Convocation employeur envoyée.' },
  { id: 'e7', date: '2026-09-14', start: '12:00', end: '14:00', type: 'perm', title: 'Permanence des élus', lieu: 'Local syndical, bâtiment C', org: 'Élus de permanence', visib: 'public', invites: [], notes: '' },
  { id: 'e8', date: '2026-09-17', start: '14:00', end: '16:00', type: 'cse', title: 'CSSCT — visite de l\'atelier B', lieu: 'Atelier B', org: 'Référent SSCT', visib: 'elus', invites: ['Commission SSCT', 'Médecin du travail'], notes: 'Visite d\'inspection après accident du 25 août. Rapport à joindre au registre.' },
  { id: 'e9', date: '2026-09-22', start: '09:00', end: '12:00', type: 'nego', title: 'NAO — 4ᵉ séance', lieu: 'Salle du conseil, siège', org: 'Delphine Marchand', visib: 'elus', invites: ['Délégation NAO'], notes: '' },
  { id: 'e10', date: '2026-09-24', start: '', end: '', type: 'ech', title: 'Dépôt du PV de septembre', lieu: '', org: 'Secrétaire du CSE', visib: 'elus', invites: [], notes: 'Délai de 15 jours après la séance.' },
  { id: 'e11', date: '2026-09-29', start: '12:15', end: '13:15', type: 'ag', title: 'Réunion de section — Prouvy', lieu: 'Plateforme de Prouvy', org: 'Section Logistique', visib: 'adherents', invites: ['Section Logistique'], notes: 'Réorganisation logistique : information des adhérents.' },
  { id: 'e12', date: '2026-10-01', start: '', end: '', type: 'ech', title: 'Entrée en vigueur — accord télétravail', lieu: '', org: 'Secrétaire du CSE', visib: 'public', invites: [], notes: 'Note aux adhérents à diffuser la semaine précédente.' }
];