'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {test}=require('node:test');
const godot=process.env.CD_GODOT_EXECUTABLE;
const racine=path.resolve(__dirname,'..');
// Le socle doit rester autonome : ni l'ancien habillage, ni les coordonnées absolues de immersive08.
test('Socle : jetons et tableau sans dépendance à l’ancienne interface',()=>{
 for(const nom of ['jetons.gd','tableau.gd']){
  const source=fs.readFileSync(path.join(racine,'native/godot/ui/socle',nom),'utf8');
  assert.doesNotMatch(source,/res:\/\/ui\/(immersive08\/(?!fonts\/)|game_skin|carnet_skin|theme)/,nom+' ne charge que des polices');
 }
 const ecran=fs.readFileSync(path.join(racine,'native/godot/ui/socle/ecran_effectif.gd'),'utf8');
 assert.doesNotMatch(ecran,/_command\(/,'l’écran ne lance aucune commande du moteur');
 assert.doesNotMatch(ecran,/Color\("/,'les couleurs viennent des jetons');
});
for(const taille of ['1920x1080','1280x720']){
 test('Socle : écran Effectif dans le vrai jeu en '+taille,{skip:!godot&&'SDK Godot requis'},()=>{
  const sortie=process.env.CD_SOCLE_OUTPUT||fs.mkdtempSync(path.join(os.tmpdir(),'rl27-socle-'));
  const profil=fs.mkdtempSync(path.join(os.tmpdir(),'rl27-socle-profil-'));fs.mkdirSync(sortie,{recursive:true});
  const graphique=process.env.CD_SOCLE_GRAPHICS==='1';
  const resultat=spawnSync(godot,[...(graphique?['--display-driver','x11','--rendering-method','gl_compatibility','--windowed','--resolution',taille]:['--headless']),'--audio-driver','Dummy','--path','native/godot','--script',path.resolve(__dirname,'godot-socle-effectif.gd')],
   {cwd:racine,encoding:'utf8',timeout:240000,env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_GODOT_GUIDE_MODULE_TEST:'1',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:profil,CD_SOCLE_EFFECTIF:'1',CD_SOCLE_OUTPUT:sortie,CD_SOCLE_SIZE:taille}});
  const journal=(resultat.stdout||'')+(resultat.stderr||'');fs.writeFileSync(path.join(sortie,'godot-'+taille+'.log'),journal);
  console.log('Preuves du socle : '+sortie);
  if(resultat.error)throw resultat.error;
  assert.equal(resultat.status,0,journal.slice(-3000));
  assert.doesNotMatch(journal,/SCRIPT ERROR|Parse Error/);
  const rapport=JSON.parse(fs.readFileSync(path.join(sortie,'report-'+taille+'.json'),'utf8'));
  assert.deepEqual(rapport.failures,[]);assert.ok(rapport.controles>=30,'au moins 30 contrôles');
 });
}
