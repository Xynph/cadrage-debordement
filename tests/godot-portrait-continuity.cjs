'use strict';
const {test}=require('node:test'),a=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{spawnSync}=require('node:child_process');
test('Native academy promotion keeps bank2 portraits in small/large squad and training views after reopening',{skip:!process.env.CD_GODOT_EXECUTABLE&&'SDK Godot requis'},()=>{
 const directory=fs.mkdtempSync(path.join(os.tmpdir(),'cd-portrait-continuity-')),graphics=process.env.CD_REGEN_UI_GRAPHICS==='1';
 const r=spawnSync(process.env.CD_GODOT_EXECUTABLE,[...(graphics?['--display-driver','x11','--rendering-method','gl_compatibility']:['--headless']),'--audio-driver','Dummy','--max-fps','120','--path','native/godot','--script',path.resolve(__dirname,'godot-portrait-continuity.gd')],{cwd:path.resolve(__dirname,'..'),env:{...process.env,CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_SELF_TEST:'0',CD_GODOT_DATA_DIR:path.join(directory,'PrototypeGodot'),CD_REGEN_UI_OUTPUT:directory},encoding:'utf8',timeout:90000});
 const text=(r.stdout||'')+(r.stderr||'');fs.writeFileSync(path.join(directory,'godot.log'),text);console.log(text.trim());console.log('Preuves continuité : '+directory);if(r.error)throw r.error;a.equal(r.status,0,text);a.doesNotMatch(text,/SCRIPT ERROR|Parse Error|ERROR:|instances were leaked/);
});
