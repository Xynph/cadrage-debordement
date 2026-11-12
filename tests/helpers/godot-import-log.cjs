'use strict';
// Journal d'un import éditeur Godot d'une copie du projet (sans dossier .godot) : les textures PNG
// extraites des glTF embarqués (gabi.glb, ballon) produisent, au premier import, des lignes
// « ERROR: Failed loading resource: res://….png/.jpg. The file doesn't seem to exist. » suivies d'un
// « WARNING: glTF … It will be loaded directly instead » : le moteur recharge l'image directement,
// l'import réussit (statut 0) et le jeu s'ouvre. Ces lignes (apparues avec la tête 2K de Gabi,
// #593/#595) ne sont pas une erreur du projet : on les retire avant de chercher de vraies erreurs.
const EXTRACTION = /^ERROR: Failed loading resource: res:\/\/[^\n]*\.(?:png|jpe?g|webp|exr|hdr)[^\n]*\n\s+at: [^\n]*\n/gm;
const GLTF_WARNING = /^WARNING: glTF: Image index [^\n]*couldn't be imported\. It will be loaded directly instead[^\n]*\n\s+at: [^\n]*\n/gm;
function importLogErrors(log) {
  return String(log).replace(/\x1b\[[0-9;]*m/g, '').replace(/\r/g, '').replace(EXTRACTION, '').replace(GLTF_WARNING, '');
}
module.exports = { importLogErrors };
