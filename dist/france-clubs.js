/* Identités de jeu originales ; territoires du snapshot projet, sans données joueurs. */
(function(root,build){'use strict';const api=build();if(typeof module==='object'&&module.exports)module.exports=api;if(root)root.CDFranceClubs=api;})(typeof globalThis==='object'?globalThis:null,function(){
 'use strict';
 const catalogue='france-territories-2026-10-31-v1';
 // Puissances, trésoreries et objectifs sont des paramètres FICTIFS de simulation.
 const rows=[
  ['toulouse','Toulouse','Toulouse Capitole XV','TCX','#d43e47','Stade Ernest Wallon',86,7.5,'Jouer le titre'],
  ['bordeaux-begles','Bordeaux','Bordeaux Estuaire Rugby','BER','#823752','Stade Jacques Chaban Delmas',84,6.4,'Jouer le titre'],
  ['la-rochelle','La Rochelle','La Rochelle Océan XV','LOX','#d4b340','Stade Marcel Deflandre',81,5.8,'Top 4'],
  ['toulon','Toulon','Toulon Rade Rugby','TRR','#d14043','Stade Mayol',81,5.6,'Top 4'],
  ['pau','Pau','Pau Béarn XV','PBX','#359a66','Stade du Hameau',78,4.6,'Top 6'],
  ['bayonne','Bayonne','Bayonne Nive Rugby','BNR','#79b7d7','Stade Jean Dauger',77,4.3,'Top 6'],
  ['clermont','Clermont-Ferrand','Clermont-Ferrand Volcans XV','CVX','#d4b340','Stade Marcel Michelin',78,4.8,'Top 6'],
  ['lyon','Lyon','Lyon Confluences XV','LCX','#d1494c','Matmut Stadium Gerland',77,4.5,'Top 6'],
  ['montpellier','Montpellier','Montpellier Garrigues XV','MGX','#5a8ec4','Septeo Stadium',77,4.9,'Top 6'],
  ['castres','Castres','Castres Tarn Rugby','CTR','#5c8fbd','Stade Pierre Fabre',76,3.7,'Top 8'],
  ['racing-92','Nanterre','Nanterre Ciel XV','NCX','#8fc2df','Plenitude Arena',79,5.7,'Top 6'],
  ['paris','Paris','Paris Deux-Rives XV','PDX','#dd89b0','Stade Jean Bouin',76,4.6,'Top 8'],
  ['perpignan','Perpignan','Perpignan Catalan XV','PCX','#d88042','Stade Aimé Giral',72,2.8,'Maintien'],
  ['vannes','Vannes','Vannes Morbihan XV','VMX','#6f9ac9','Stade de la Rabine',71,2.5,'Maintien'],
  ['beziers','Béziers','Béziers Orb XV','BOX','#c75259','Stade Raoul Barrière',70,2.8,'Top 6'],
  ['biarritz','Biarritz','Biarritz Côte Basque XV','BCX','#d9565a',"Parc des Sports d’Aguilera",68,2.5,'Top 8'],
  ['brive','Brive-la-Gaillarde','Brive Corrèze XV','BCV','#d6d8d9','Stadium Municipal',74,3.6,'Jouer le titre'],
  ['colomiers','Colomiers','Colomiers Colombe XV','CCX','#6ba0d9','Stade Michel Bendichou',70,2.6,'Top 6'],
  ['grenoble','Grenoble','Grenoble Alpes XV','GAX','#d24d56','Stade des Alpes',74,3.4,'Jouer le titre'],
  ['nice','Nice','Nice Riviera XV','NRX','#d95358','Stade Marcel Volot',64,2.0,'Maintien'],
  ['oyonnax','Oyonnax','Oyonnax Haut-Bugey XV','OHX','#cb424a','Stade Charles Mathon',72,3.0,'Top 6'],
  ['provence-rugby','Aix-en-Provence','Aix Provence XV','APX','#d0ad62','Stade Maurice David',73,3.5,'Top 4'],
  ['narbonne','Narbonne','Narbonne Aude XV','NAX','#dd8a43',"Parc des Sports et de l’Amitié",65,2.1,'Maintien'],
  ['agen','Agen','Agen Garonne XV','AGX','#6c9ed0','Stade Armandie',69,2.8,'Top 8'],
  ['angouleme','Angoulême','Angoulême Charente XV','ACX','#b291d5','Stade Chanzy',68,2.4,'Top 8'],
  ['aurillac','Aurillac','Aurillac Cantal XV','ACV','#cf4a51','Stade Jean Alric',66,2.1,'Maintien'],
  ['dax','Dax','Dax Adour XV','DAX','#d45054','Stade Maurice Boyau',66,2.2,'Maintien'],
  ['montauban','Montauban','Montauban Tarn XV','MTX','#57a67a','Stade Sapiac',69,2.7,'Top 8'],
  ['nevers','Nevers','Nevers Loire XV','NLX','#d3bb4c','Stade du Pré Fleuri',70,2.7,'Top 6'],
  ['valence-romans','Valence','Valence Romans Drôme XV','VDX','#cad0d3','Stade Georges Pompidou',67,2.3,'Maintien']
 ];
 const clubs=Object.freeze(rows.map(([slug,city,name,abbr,color,stadium,base,cashMillions,goal],id)=>Object.freeze({id,slug,division:id<14?'elite':'accession',city,name,abbr,color,stadium,base,cashMillions,goal,cityImage:'assets/club-atlas/'+slug+'-city.webp',stadiumImage:'assets/club-atlas/'+slug+'-stadium.webp'})));
 const realOrder=['clermont','bayonne','castres','lyon','montpellier','toulon','vannes','racing-92','pau','paris','la-rochelle','toulouse','perpignan','bordeaux-begles'];
 function get(value){return clubs.find(c=>c.id===value||c.slug===value)||null;}
 function division(key){return clubs.filter(c=>c.division===key);}
 function forCareer(state,id){
  if(!state||!Number.isInteger(id)||!state.clubs?.some(c=>c.id===id))return null;
  if(state.franceMode?.version===1&&state.franceMode.catalogue===catalogue)return get(id);
  if(id<0||id>=14)return null;
  return state.lnrMode?get(realOrder[id]):get(id);
 }
 return Object.freeze({catalogue,clubs,get,division,forCareer});
});
