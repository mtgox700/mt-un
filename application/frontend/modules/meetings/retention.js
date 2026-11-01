// Existing conservation card, backed by server metadata only.
export function retentionView(value,now=Date.now()){
 if(!value)return {retentionBadge:'Conservation à vérifier',retentionText:'État de conservation indisponible. Aucun effacement confirmé.',retentionPct:'100%'};
 const batches=value.batches||[],states=batches.map(x=>x.state),due=value.due?new Date(value.due):null;
 if(states.includes('executing'))return {retentionBadge:'Suppression en cours',retentionText:'Lot approuvé. Accès audio bloqué ; effacement des fichiers en cours de confirmation.',retentionPct:'100%'};
 if(states.includes('approved'))return {retentionBadge:'Suppression approuvée',retentionText:'Inventaire approuvé par le super admin. Exécution et confirmation d’effacement encore attendues.',retentionPct:'100%'};
 if(states.includes('held'))return {retentionBadge:'Conservation prolongée',retentionText:'Conservation autorisée sur un lot identifié. À échéance, une nouvelle approbation de suppression reste nécessaire.',retentionPct:'100%'};
 if(states.includes('pending')||(due&&due.getTime()<=now))return {retentionBadge:'Échéance dépassée',retentionText:'Délai de 30 jours atteint. Audio conservé en attente de validation du super admin ; aucune purge automatique.',retentionPct:'100%'};
 if(states.includes('done')&&!due&&value.remaining===0)return {retentionBadge:'Audio supprimé',retentionText:'Effacement serveur confirmé pour les lots approuvés. PV diffusés distincts conservés ; sauvegardes et appareils hors ligne suivis séparément.',retentionPct:'0%'};
 return {retentionBadge:'Audio conservé',retentionText:due?'Demande de suppression à partir du '+due.toLocaleDateString('fr-FR')+', 30 jours après validation. Approbation du super admin obligatoire.':'Aucune validation de PV enregistrée pour cet audio. Le délai de conservation n’a pas commencé.',retentionPct:'100%'};
}
