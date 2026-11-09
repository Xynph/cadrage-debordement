'use strict';

const { teams, phases } = window.OVAL_REPLAY;
const byId = id => document.getElementById(id);
const annotations = {
  carry: ['Le porteur avance', 'Repère le cercle jaune. Le ballon est encore en jeu près de l’en-but adverse.'],
  try: ['Essai et transformation', 'Le score change sur cette image. Le cercle jaune marque le point d’arrivée dans l’en-but.'],
  kickoff: ['Renvoi au centre', 'La remise en jeu replace le ballon au milieu. Observe la réorganisation des deux lignes.'],
  reception: ['Ballon réceptionné', 'Le cercle jaune indique le point de réception et le marqueur cerclé désigne le joueur mis en avant.'],
};

const players = new Map();
const motionPreference = matchMedia('(prefers-reduced-motion: reduce)');
const controls = [byId('previous'), byId('play'), byId('next')];
const phaseButtons = phases.map((phase, index) => {
  const button = document.createElement('button');
  button.type = 'button';
  button.textContent = `${index + 1}. ${annotations[phase.kind][0]}`;
  button.addEventListener('click', () => selectManually(index));
  byId('timeline').append(button);
  return button;
});
let selected = 0;
let playing = false;
let timer;
let animation;

function pointAt(before, target, fraction) {
  return {
    x: before.x + (target.x - before.x) * fraction,
    y: before.y + (target.y - before.y) * fraction,
  };
}

function paint(before, phase, fraction) {
  const previous = new Map(before.players.map(player => [player.id, player]));
  const present = new Set(phase.players.map(player => player.id));
  for (const [id, marker] of players) {
    if (present.has(id)) continue;
    marker.remove();
    players.delete(id);
  }
  for (const player of phase.players) {
    let marker = players.get(player.id);
    if (!marker) {
      marker = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
      byId('players').append(marker);
      players.set(player.id, marker);
    }
    const position = pointAt(previous.get(player.id) || player, player, fraction);
    marker.setAttribute('cx', position.x);
    marker.setAttribute('cy', position.y);
    marker.setAttribute('r', player.featured ? '1.85' : '1.25');
    marker.setAttribute('class', `marker ${player.side === 0 ? 'home' : 'away'} ${player.featured ? 'featured' : ''}`);
  }
  const ball = pointAt(before.ball, phase.ball, fraction);
  byId('ball').setAttribute('transform', `translate(${ball.x} ${ball.y})`);
}

function updateControls() {
  controls[0].disabled = selected === 0;
  controls[1].textContent = playing ? 'Pause' : selected === phases.length - 1 ? 'Rejouer' : 'Lire';
  controls[2].disabled = selected === phases.length - 1;
}

function select(index, transition = false) {
  if (!Number.isInteger(index) || index < 0 || index >= phases.length) return;
  const before = phases[selected];
  const phase = phases[index];
  const interpolate = transition && index === selected + 1 && phase.kind !== 'kickoff' && !motionPreference.matches;
  selected = index;
  cancelAnimationFrame(animation);
  const [title, annotation] = annotations[phase.kind];
  byId('progress').textContent = `PHASE ${index + 1} / ${phases.length}`;
  byId('phase-title').textContent = title;
  byId('annotation').textContent = annotation;
  byId('commentary').textContent = phase.commentary;
  byId('score').textContent = phase.score.join(' – ');
  byId('announcement').textContent = `Phase ${index + 1}. ${title}. ${phase.commentary}`;
  phaseButtons.forEach((button, position) => {
    if (position === index) button.setAttribute('aria-current', 'step');
    else button.removeAttribute('aria-current');
  });
  updateControls();
  if (!interpolate) {
    paint(phase, phase, 1);
    return;
  }
  const started = performance.now();
  function render(now) {
    const fraction = Math.min(1, Math.max(0, (now - started) / 520));
    paint(before, phase, fraction);
    if (fraction < 1) animation = requestAnimationFrame(render);
  }
  animation = requestAnimationFrame(render);
}

function pause() {
  clearTimeout(timer);
  cancelAnimationFrame(animation);
  playing = false;
  const phase = phases[selected];
  paint(phase, phase, 1);
  updateControls();
}

function selectManually(index) {
  pause();
  select(index);
}

function toggle() {
  if (playing) {
    pause();
    return;
  }
  if (selected === phases.length - 1) select(0);
  playing = true;
  updateControls();
  function advance() {
    select(selected + 1, true);
    if (selected === phases.length - 1) {
      playing = false;
      updateControls();
    } else {
      timer = setTimeout(advance, 1800);
    }
  }
  timer = setTimeout(advance, 1800);
}

controls[0].addEventListener('click', () => selectManually(selected - 1));
controls[1].addEventListener('click', toggle);
controls[2].addEventListener('click', () => selectManually(selected + 1));
document.addEventListener('keydown', event => {
  if (event.altKey || event.ctrlKey || event.metaKey || event.shiftKey || event.repeat) return;
  if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
    event.preventDefault();
    selectManually(selected + (event.key === 'ArrowLeft' ? -1 : 1));
  } else if (event.key === ' ' && !event.target.closest('button')) {
    event.preventDefault();
    toggle();
  }
});
motionPreference.addEventListener('change', () => {
  cancelAnimationFrame(animation);
  const phase = phases[selected];
  paint(phase, phase, 1);
});
byId('home').textContent = teams[0];
byId('away').textContent = teams[1];
const initial = Number(new URLSearchParams(location.search).get('phase') || 1) - 1;
select(Number.isInteger(initial) && initial >= 0 && initial < phases.length ? initial : 0);
window.__ready = true;
