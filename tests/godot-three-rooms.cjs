'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const os=require('node:os');
const path=require('node:path');
const {spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
const repository=path.resolve(__dirname,'..');

function documentWith(text,mutate){
  const document=JSON.parse(text);mutate(document.state);
  const body=JSON.stringify(document.state);let checksum=2166136261;
  for(let i=0;i<body.length;i++)checksum=Math.imul(checksum^body.charCodeAt(i),16777619);
  document.checksum=(checksum>>>0).toString(16).padStart(8,'0');
  return JSON.stringify(document);
}
function prepareFixtures(temporary){
  const directory=path.join(temporary,'fixtures');fs.mkdirSync(directory);
  const {createBridge}=require('../native/engine/worker.cjs');
  const bridge=createBridge({dataDir:path.join(temporary,'fixture-profile'),seed:13,now:1700000000000});
  let sequence=0;
  const good=(command,payload={})=>{
    const response=bridge.handle({id:++sequence,command,payload});
    assert.equal(response.ok,true,'Real fixture worker '+command+': '+response.error);return response.model;
  };
  try{
    let model=good('new_career',{mode:'common',club:29});
    assert.ok(model.clubLife.clubMeetings,'The production persistent meeting domain must be registered');
    for(let step=0;step<24&&model.clubLife.clubMeetings.scene;step++){
      const scene=model.clubLife.clubMeetings.scene;
      if(scene.kind==='board'&&!scene.completed&&!fs.existsSync(path.join(directory,'board.json')))
        fs.writeFileSync(path.join(directory,'board.json'),good('export').meta.exportText);
      if(!scene.completed){
        if(scene.kind==='press')model=good('press_conference',{context:model.clubLife.press.context,answers:model.clubLife.press.conference.questions.map(q=>({questionId:q.id,answerId:q.answers[0].id}))});
        else if(scene.ackAllowed)model=good('club_meeting_ack',{meetingId:scene.id});
        else if(scene.kind==='medical'){
          const row=model.clubLife.clubSupport.medical.players.find(row=>row.id===scene.playerId);
          assert.ok(row&&row.injury>0,'Initial medical meeting needs an actual actionable record');
          model=good('medical_protocol',{context:model.clubLife.clubSupport.context,id:row.id,protocol:row.protocol});
        }else assert.fail('Initial meeting has no authoritative completion path: '+scene.kind);
        assert.equal(model.clubLife.clubMeetings.scene.completed,true);
      }
      model=good('club_meeting_continue',{meetingId:scene.id});
    }
    assert.equal(model.clubLife.clubMeetings.scene,null,'Fixture baseline completed every real introductory meeting');
    assert.ok(fs.existsSync(path.join(directory,'board.json')),'Initial actual board meeting is available as a validated fixture');
    const baseline=good('export').meta.exportText;
    const state=JSON.parse(baseline).state,patientId=state.clubs[state.club].players[0].id;
    fs.writeFileSync(path.join(directory,'baseline.json'),baseline);
    // Imported recorded availability states only. No score, sporting event,
    // recovery history or diagnosis is fabricated by the integration test.
    for(const [name,injury,stage]of [['medical',2,'blesse'],['return',0,'reprise']]){
      const text=documentWith(baseline,state=>{
        delete state.clubMeetings;
        const player=state.clubs[state.club].players.find(player=>player.id===patientId);
        player.injury=injury;player.condition=68;
        player.physicalLoad={version:1,plan:'collective',...player.physicalLoad,fatigue:32};
        player.medicalV68={version:1,protocol:'standard',stage};
      });
      const projected=good('import',{text}).clubLife.clubSupport.medical.players.find(player=>player.id===patientId);
      assert.ok(projected,'Fixture must be accepted and projected by the production importer');
      assert.equal(projected.injury,injury);assert.equal(projected.stage,stage);
      fs.writeFileSync(path.join(directory,name+'.json'),good('export').meta.exportText);
    }
    fs.writeFileSync(path.join(directory,'meta.json'),JSON.stringify({patientId,fixtureKind:'explicit imported availability state',inventedSportingResults:false}));
  }finally{bridge.close();}
  return directory;
}

for(const [name,script]of [
  ['press','godot-press-room.gd'],['medical','godot-medical-room.gd'],
  ['board','godot-board-room.gd'],['flow','godot-three-rooms-flow.gd']
])test('Three contextual rooms: '+name,{
  skip:!godot&&'SDK Godot requis (CD_GODOT_EXECUTABLE)',timeout:name==='flow'?360000:120000
},()=>{
  const temporary=fs.mkdtempSync(path.join(os.tmpdir(),'cd-three-rooms-'+name+'-'));
  const artifacts=process.env.CD_THREE_ROOMS_ARTIFACTS?path.resolve(process.env.CD_THREE_ROOMS_ARTIFACTS,name):path.join(temporary,'artifacts');
  fs.mkdirSync(artifacts,{recursive:true});
  const fixtures=name==='flow'?prepareFixtures(temporary):'';
  const result=spawnSync(godot,[...(process.env.CD_THREE_ROOMS_GRAPHICS==='1'?[]:['--headless']),
    '--audio-driver','Dummy','--max-fps','120','--log-file',path.join(artifacts,'runtime.log'),
    '--path',path.join(repository,'native/godot'),'--script',path.join(__dirname,script)],{
    cwd:repository,env:{...process.env,
      XDG_DATA_HOME:path.join(temporary,'data'),XDG_CONFIG_HOME:path.join(temporary,'config'),XDG_CACHE_HOME:path.join(temporary,'cache'),
      APPDATA:path.join(temporary,'appdata'),LOCALAPPDATA:path.join(temporary,'localappdata'),TEMP:path.join(temporary,'tmp'),TMP:path.join(temporary,'tmp'),
      CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_SELF_TEST:'0',CD_GODOT_SEED:'13',CD_GODOT_DATA_DIR:path.join(temporary,'profile'),
      CD_THREE_ROOMS_ARTIFACTS:artifacts,CD_THREE_ROOMS_FIXTURES:fixtures},
    encoding:'utf8',windowsHide:true,timeout:name==='flow'?345000:105000,maxBuffer:16*1024*1024
  });
  const output=(result.stdout||'')+(result.stderr||'');
  fs.writeFileSync(path.join(artifacts,'godot.log'),output);
  console.log(output.trim());console.log('Three rooms '+name+' artifacts: '+artifacts);
  if(result.error)throw result.error;
  assert.equal(result.status,0,output);
  assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:|instances were leaked/,'No script, engine or lifecycle error is accepted');
  if(name==='flow'){
    const report=JSON.parse(fs.readFileSync(path.join(artifacts,'report.json'),'utf8'));
    assert.deepEqual(report.failures,[]);assert.equal(report.real_worker,true);assert.ok(report.checks>100);
  }
});
