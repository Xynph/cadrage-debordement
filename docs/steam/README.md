# Sortie sur Steam — préparation (19/11/2026)

Ce dossier rassemble ce qui est prêt côté jeu et dépôt, et ce qui revient à Léo.
Rien n'a été créé chez Valve : aucun compte, aucun paiement, aucune condition acceptée, aucun envoi.

## Ce qui est prêt

| Élément | Où |
| --- | --- |
| Réglage d'export dédié (version, éditeur et copyright dans l'exécutable, fichiers de recette exclus) | `native/godot/steam-release.cfg` |
| Build local du dossier Steam | `scripts/build-steam.py` |
| Modèles steamcmd (App ID et Depot ID à renseigner, build jamais publié automatiquement : `SetLive` vide) | `tools/steam/*.vdf.template` |
| Emplacement Steamworks (succès, sauvegardes cloud, packs Workshop), inactif tant que non configuré | `native/godot/steam/`, `native/godot/addons/godotsteam/` |
| Écran Crédits et mentions légales (menu d'accueil et fiche club) | `native/godot/legal/credits.json`, `native/godot/ui/credits_view.gd` |
| Page magasin : liste de contrôle et textes FR/EN | [`page-magasin.md`](page-magasin.md) |

## Produire le build Steam

Depuis un checkout propre (aucune modification suivie, commit exact) :

```powershell
. E:\Cadrage-Debordement\environnement.ps1
$env:CD_NODE_EXECUTABLE = 'E:\Cadrage-Debordement\outils\node.exe'
python scripts/build-steam.py --sdk E:\Cadrage-Debordement\outils\godot --output E:\Cadrage-Debordement\temp\steam-<date> --source-commit (git rev-parse HEAD)
```

Sortie :

- `steam/content/` : le jeu tel qu'il sera installé chez le joueur (`RugbyLegacy27.exe`, `runtime/`, `engine/`, `Licences/`, `Packs/`) ;
- `steam/scripts/app_build.vdf` et `depot_build_windows.vdf` ;
- `steam/TELEVERSER.txt` : la commande steamcmd à lancer soi-même et la liste de ce qui manque.

Variables facultatives : `CD_STEAM_APP_ID`, `CD_STEAM_DEPOT_ID` (identifiants donnés par Steamworks),
`CD_SIGN_CERT_SHA1` (empreinte d'un certificat de signature de code installé dans Windows), `CD_SIGN_TIMESTAMP_URL`, `CD_SIGNTOOL`.
Sans certificat, l'exécutable n'est pas signé : Steam l'accepte, Windows SmartScreen peut avertir au premier lancement hors Steam.

## Activer Steamworks plus tard

1. Copier l'extension GodotSteam (GDExtension pour Godot 4.7) dans `native/godot/addons/godotsteam/` et l'inscrire au [registre des ressources](../ressources-utiles.md).
2. Dans `native/godot/steam/steam.json` : `app_id`, `enabled: true`, puis `achievements` et/ou `cloud_saves`.
3. Succès : les déclarer dans Steamworks, puis appeler `steam_service.gd` → `unlock_achievement("ID")` aux moments choisis.
4. Sauvegardes cloud : le plus simple est le « Steam Auto-Cloud » réglé côté Steamworks sur `%APPDATA%/CadrageDebordement/PrototypeGodot` (aucun code) ; l'API cloud n'est utile que pour un contrôle plus fin.

## Workshop : packs de données téléchargeables

Voie prévue pour diffuser des packs (dont, éventuellement, le pack « Rugby Réel », qui n'entre jamais dans le jeu de base).

- **Format** : celui des packs d'identités déjà importables à la main (ZIP avec `pack.json` à la racine, schémas `cd-identity-pack-v1`/`v2`, voir [packs du monde](../world-identity-pack-20261109.md)). Le format de référence reste celui défini par le chantier données réelles ; le Workshop ne fait que transporter le ZIP.
- **Objet Workshop** : un dossier contenant un ou plusieurs `.zip` au premier niveau. Steam le télécharge dans `steamapps/workshop/content/<AppID>/<ItemID>/`.
- **Côté jeu** : avec `enabled` et `workshop` à `true`, `steam_service.workshop_packs()` liste les ZIP des objets abonnés et installés ; l'écran Packs affiche un bouton « Workshop · <nom> » par pack, qui suit exactement le chemin d'un import manuel (analyse puis installation validées par le moteur, empreinte comprise). Rien n'est chargé sans cette validation.
- Tant que Steamworks n'est pas configuré, la liste est vide et l'écran Packs est inchangé.
- Droits : publier sur le Workshop des noms, photos ou logos réels suppose d'en détenir les droits ; c'est une décision de Léo, hors de ce dépôt.

Le build refuse `enabled: true` sans App ID ni extension, et refuse tout `steam_appid.txt` ou `override.cfg` dans le contenu.

## À faire par Léo (dans l'ordre)

1. Créer le compte Steamworks (partenaire), remplir les informations fiscales et bancaires, accepter l'accord de distribution.
2. Payer les frais d'application Steam Direct (100 $ par jeu, récupérables après 1 000 $ de recettes).
3. Choisir le nom d'éditeur et le renseigner dans `native/godot/legal/credits.json` (nom, forme, adresse, contact) — il apparaît dans Crédits et dans l'exécutable.
4. Donner l'App ID et le Depot ID (pour remplir les scripts), décider succès, sauvegardes cloud et Workshop (à activer aussi côté Steamworks).
5. Décider le prix, la date (accès anticipé ou non) et valider les textes de la page magasin.
6. Remplir le questionnaire de contenu et la déclaration d'IA (portraits, illustrations, voix de Gabi).
7. Facultatif : acheter un certificat de signature de code.
8. Téléverser avec steamcmd (identifiants saisis par lui) et soumettre la page puis le build à la revue de Valve.
