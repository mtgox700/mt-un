// Corpus de référence de l'assistant. Versionné : toute modification change CORPUS_VERSION (tracé dans requete_ia).
// Chaque entrée doit être vérifiée sur Légifrance par un juriste avant la mise en production :
// `verifie_le` reste null tant que ce n'est pas fait, et la passerelle signale alors la réserve.
// Source unique : texte consolidé sur legifrance.gouv.fr (Code du travail, Code général des impôts).

export const CORPUS_VERSION = 'ctrav-2026-10.1';

export type Reference = { ref: string; objet: string; theme: string; verifie_le: string | null };

export const CORPUS: Reference[] = [
  // CSE — attributions, moyens
  { theme: 'CSE', ref: 'C. trav., art. L2312-5', objet: 'Attributions du CSE dans les entreprises de 11 à 49 salariés (réclamations individuelles et collectives)', verifie_le: null },
  { theme: 'CSE', ref: 'C. trav., art. L2312-8', objet: 'Attributions générales du CSE dans les entreprises d\'au moins 50 salariés (information-consultation)', verifie_le: null },
  { theme: 'CSE', ref: 'C. trav., art. L2312-17', objet: 'Consultations récurrentes : orientations stratégiques, situation économique et financière, politique sociale', verifie_le: null },
  { theme: 'CSE', ref: 'C. trav., art. L2312-18', objet: 'Base de données économiques, sociales et environnementales (BDESE)', verifie_le: null },
  { theme: 'CSE', ref: 'C. trav., art. L2315-7', objet: 'Crédit d\'heures de délégation des membres titulaires', verifie_le: null },
  { theme: 'CSE', ref: 'C. trav., art. L2315-14', objet: 'Liberté de déplacement des membres de la délégation du personnel', verifie_le: null },
  { theme: 'CSE', ref: 'C. trav., art. L2315-61', objet: 'Subvention de fonctionnement du CSE', verifie_le: null },
  { theme: 'CSE', ref: 'C. trav., art. L2315-94', objet: 'Recours à un expert habilité (risque grave, projet important modifiant les conditions de travail)', verifie_le: null },
  { theme: 'CSE', ref: 'C. trav., art. L2317-1', objet: 'Délit d\'entrave au fonctionnement du CSE', verifie_le: null },
  // Alertes, santé, sécurité
  { theme: 'Alerte', ref: 'C. trav., art. L2312-59', objet: 'Droit d\'alerte du CSE en cas d\'atteinte aux droits des personnes', verifie_le: null },
  { theme: 'Alerte', ref: 'C. trav., art. L2312-60', objet: 'Droit d\'alerte du CSE en cas de danger grave et imminent', verifie_le: null },
  { theme: 'Santé', ref: 'C. trav., art. L4131-1', objet: 'Droit d\'alerte et de retrait du salarié', verifie_le: null },
  { theme: 'Santé', ref: 'C. trav., art. L4121-1', objet: 'Obligation de sécurité de l\'employeur', verifie_le: null },
  { theme: 'Santé', ref: 'C. trav., art. L4121-2', objet: 'Principes généraux de prévention', verifie_le: null },
  { theme: 'Santé', ref: 'C. trav., art. L1152-1', objet: 'Harcèlement moral', verifie_le: null },
  { theme: 'Santé', ref: 'C. trav., art. L1153-1', objet: 'Harcèlement sexuel', verifie_le: null },
  // Discrimination, protection
  { theme: 'Égalité', ref: 'C. trav., art. L1132-1', objet: 'Principe de non-discrimination', verifie_le: null },
  { theme: 'Syndical', ref: 'C. trav., art. L2141-5', objet: 'Interdiction de prendre en compte l\'activité syndicale dans les décisions de l\'employeur', verifie_le: null },
  { theme: 'Protection', ref: 'C. trav., art. L2411-1', objet: 'Salariés bénéficiant de la protection contre le licenciement', verifie_le: null },
  { theme: 'Protection', ref: 'C. trav., art. L2411-3', objet: 'Licenciement d\'un délégué syndical : autorisation de l\'inspecteur du travail', verifie_le: null },
  { theme: 'Protection', ref: 'C. trav., art. L2411-5', objet: 'Licenciement d\'un membre élu du CSE : autorisation de l\'inspecteur du travail', verifie_le: null },
  // Droit syndical
  { theme: 'Syndical', ref: 'C. trav., art. L2142-1-1', objet: 'Représentant de la section syndicale', verifie_le: null },
  { theme: 'Syndical', ref: 'C. trav., art. L2143-3', objet: 'Désignation du délégué syndical', verifie_le: null },
  { theme: 'Syndical', ref: 'C. trav., art. L2142-3', objet: 'Affichage des communications syndicales', verifie_le: null },
  { theme: 'Syndical', ref: 'C. trav., art. L2142-4', objet: 'Diffusion des publications et tracts syndicaux', verifie_le: null },
  { theme: 'Syndical', ref: 'C. trav., art. L2142-6', objet: 'Communication syndicale par voie numérique (accord d\'entreprise)', verifie_le: null },
  // Procédures disciplinaires, rupture, délais
  { theme: 'Discipline', ref: 'C. trav., art. L1332-2', objet: 'Entretien préalable à une sanction disciplinaire', verifie_le: null },
  { theme: 'Discipline', ref: 'C. trav., art. L1332-4', objet: 'Prescription des faits fautifs (deux mois)', verifie_le: null },
  { theme: 'Rupture', ref: 'C. trav., art. L1232-2', objet: 'Entretien préalable au licenciement pour motif personnel', verifie_le: null },
  { theme: 'Délais', ref: 'C. trav., art. L1471-1', objet: 'Prescription des actions portant sur l\'exécution ou la rupture du contrat', verifie_le: null },
  { theme: 'Délais', ref: 'C. trav., art. L3245-1', objet: 'Prescription des actions en paiement du salaire', verifie_le: null },
  // Fiscalité des adhérents
  { theme: 'Trésorerie', ref: 'CGI, art. 199 quater C', objet: 'Crédit d\'impôt au titre des cotisations syndicales', verifie_le: null },
];

const nonVerifie = CORPUS.some((r) => !r.verifie_le);

export const BLOC_CORPUS = `Références de base (${CORPUS_VERSION}) :
${CORPUS.map((r) => `- ${r.ref} : ${r.objet}`).join('\n')}
Règles de citation : n'invente jamais un numéro d'article. Un article absent de cette liste se cite avec la mention « à vérifier sur Légifrance ». Une convention collective ou un accord d'entreprise ne se cite que si l'utilisateur en a fourni le texte.${
  nonVerifie ? '\nCe corpus n\'est pas encore validé par un juriste : rappelle-le en fin de réponse.' : ''}`;
