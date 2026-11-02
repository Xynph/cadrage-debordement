'use strict';
// V64 : tactical observatory derived from an already simulated scene.
// Presentation-only: no RNG, career writes, or speculative ball positions.
function tacticalVisualSummary(scene) {
 const players=Array.isArray(scene?.players)?scene.players:[];
 const possession=scene?.possession===1?1:0;
 const attack=players.filter(p=>p.side===possession&&Number.isFinite(p.x)&&Number.isFinite(p.y));
 const defence=players.filter(p=>p.side===1-possession&&Number.isFinite(p.x)&&Number.isFinite(p.y));
 const ball=scene?.ball||{};
 const distance=p=>Math.hypot(p.x-ball.x,p.y-ball.y);
 const near=(arr,metres)=>Number.isFinite(ball.x)&&Number.isFinite(ball.y)?arr.filter(p=>distance(p)<=metres).length:0;
 const wings=[0,1,2].map(i=>({label:['Aile gauche','Axe','Aile droite'][i],attack:attack.filter(p=>Math.min(2,Math.floor(p.y/23.34))===i).length,defence:defence.filter(p=>Math.min(2,Math.floor(p.y/23.34))===i).length}));
 const line=arr=>arr.length?arr.reduce((sum,p)=>sum+p.x,0)/arr.length:null;
 const pressure=near(defence,12)>near(attack,12)?'Pression adverse':near(attack,12)>near(defence,12)?'Soutien offensif':'Zone disputée';
 const longitudinalGap=line(attack)===null||line(defence)===null?null:Math.round(Math.abs(line(attack)-line(defence))*10)/10;
 return {pressure,longitudinalGap,possession,attackCount:attack.length,defenceCount:defence.length,attackNear:near(attack,12),defenceNear:near(defence,12),wings,attackLine:line(attack),defenceLine:line(defence),eventKind:String(scene?.kind||'message'),hasActualEvent:!!scene?.event?.scene};
}
function tacticalVisualHtml(scene) {
 const v=tacticalVisualSummary(scene);
 const escape=typeof visualEscape==='function'?visualEscape:s=>String(s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
 const rows=v.wings.map(w=>'<tr><th scope="row">'+escape(w.label)+'</th><td>'+w.attack+'</td><td>'+w.defence+'</td><td>'+((w.attack-w.defence)>0?'+':'')+(w.attack-w.defence)+'</td></tr>').join('');
 return '<section class="card match-tactical-observatory" aria-label="Observatoire spatial tactique"><h2>Espaces et soutiens</h2>'+
 '<p>Lecture des '+v.attackCount+' joueurs en possession et '+v.defenceCount+' défenseurs affichés. '+
 'Soutiens dans un rayon schématique de 12 m autour du ballon : <strong>'+v.attackNear+'</strong> contre <strong>'+v.defenceNear+'</strong>.</p>'+
 '<p><strong>'+escape(v.pressure)+'</strong> · Écart longitudinal moyen : '+(v.longitudinalGap===null?'indisponible':v.longitudinalGap.toFixed(1)+' m')+'.</p>'+ 
 '<table><caption>Répartition latérale estimée des joueurs affichés</caption><thead><tr><th>Zone</th><th>Attaque</th><th>Défense</th><th>Écart</th></tr></thead><tbody>'+rows+'</tbody></table>'+
 '<p class="v40-data-note">Observations dérivées des positions du rendu 2D, pas du moteur de collision. '+
 (v.hasActualEvent?'Action native synchronisée.':'Aucune géométrie historique enregistrée : positions schématiques.')+
 ' Aucune décision tactique ni sauvegarde modifiée.</p></section>';
}
if(typeof module!=='undefined')module.exports={tacticalVisualSummary,tacticalVisualHtml};
