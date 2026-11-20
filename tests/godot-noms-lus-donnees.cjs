'use strict';
// Écrans avec un pack : noms de compétitions, montées, descentes, stades et villes lus dans les données ;
// une donnée absente est omise, jamais remplacée par un texte inventé. Données fictives uniquement.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{spawnSync}=require('node:child_process');
const ui=f=>fs.readFileSync(path.join(__dirname,'../native/godot/ui',f),'utf8');
// Garde-fous de source (sans Godot) : plus de table de noms figée ni de repli inventé.
assert.doesNotMatch(ui('club_memory_view.gd'),/const DIVISIONS/,'Histoire du club : noms de divisions lus dans les données');
assert.doesNotMatch(ui('immersive08/club_canvas.gd'),/"(Montée|Descente) en [^"]/,'Club : montée et descente nommées par les données');
assert.doesNotMatch(ui('immersive08/nationale_archive.gd'),/"(Montée|Descente|Maintien) en [^"]/,'Archives : divisions nommées par les données');
assert.doesNotMatch(ui('immersive08/club_sheet_canvas.gd'),/Stade non renseigné/,'Fiche club : stade absent omis');
assert.doesNotMatch(ui('club_views.gd'),/à préciser"/,'Territoire : ville ou stade absent omis');
assert.doesNotMatch(ui('game_skin.gd'),/id == 0 and kind == "stadium"/,'Stade de repli sans lien avec un club précis');
for(const f of ['entry_screens.gd','immersive08/palmares_text.gd'])assert.doesNotMatch(ui(f),/label\.to_lower\(\) ==/,f+' : nom de compétition du pack affiché tel quel');
// Création : saison de départ et format lus dans les données (plus de table ni d'année dans l'écran).
assert.doesNotMatch(ui('entry_screens.gd'),/const CREATION_FORMATS|"20\d\d" if |SAISON 20\d\d/,'Création : saison et format lus dans les données');
assert.doesNotMatch(ui('immersive08/creation_canvas.gd'),/CREATION_FORMATS|"20\d\d" if /,'Création (grille) : saison et format lus dans les données');
// Immersion : aucune étiquette de provenance des photos à l'écran.
for(const f of ['immersive08/career_canvas.gd','immersive08/club_canvas.gd','immersive08/office.gd','club_views.gd'])assert.doesNotMatch(ui(f),/(PHOTO|Photo) (DU PACK|du pack|D’ARCHIVE|d’archive)/,f+' : pas de provenance de photo affichée');
const godot=process.env.CD_GODOT_EXE||process.env.CD_GODOT_EXECUTABLE;
if(!godot){console.log('SKIP godot-noms-lus-donnees (partie Godot) : SDK Godot absent.');process.exit(0);}
const run=spawnSync(godot,['--headless','--audio-driver','Dummy','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-noms-lus-donnees.gd')],{encoding:'utf8',timeout:120000,windowsHide:true});
const log=(run.stdout||'')+(run.stderr||'');console.log(log);
if(run.error)throw run.error;assert.equal(run.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|FAIL:/);
console.log('Noms lus dans les données PASS');
