# Revue des contrats de l'effectif — 1440p

**Effectif → Contrats** ouvre un tableau dense des échéances. Les lignes montrent
le portrait existant, le nom, le poste principal, l'âge, la fin de saison du
contrat, le salaire hebdomadaire, les minutes projetées, le statut et l'état de
prolongation. Les actions **Fiche** et **Prolonger / Discussion** ciblent un
identifiant joueur, jamais le seul nom affiché.

Les filtres combinent recherche accentuée, saison, prolongations accessibles,
discussions en cours ou closes, échéance renseignée et poste. La recherche, le
filtre et le focus sont conservés au retour de la fiche complète. La commande de
prolongation reste celle du jeu : ouvrir le formulaire ne signe aucun contrat.
Les discussions déjà présentes utilisent la même API que le chantier négociation.

## Repères visuels et sens des données

- Les barres d'échéances par saison comptent les seuls contrats projetés.
- La couverture par poste compte les fins de contrat jusqu'à l'horizon choisi,
  les contrats au-delà et les échéances inconnues séparément. Cliquer un poste
  filtre le tableau. Aucune polyvalence ou feuille de match n'est supposée.
- La couleur or distingue les horizons de la saison courante, le vert les
  suivants et le gris les inconnues. Une fin de saison n'est pas assimilée à
  une urgence quotidienne ou à un départ certain, même pour 25 joueurs.
- Le total hebdomadaire est la somme des salaires effectivement projetés. Les
  montants manquants sont signalés, sans être remplacés par zéro ni extrapolés
  en coût annuel. Ce total n'est pas une prévision de trésorerie.
- Aucune date d'expiration exacte n'est inventée : **Fin S1**, par exemple,
  désigne une saison. Les dates précises ne sont pas fournies par la projection.

La présentation 2560 × 1440 utilise des textes de 16–18 px, des données de
18–20 px, des titres de 24–28 px, des lignes compactes et les portraits déjà
livrés. Les noms longs restent accessibles par infobulle et fiche, sans élargir
le tableau hors écran. Les autres définitions ne sont pas reçues dans ce lot.

## Périmètre et réception

Base `272bd7f`, branche dédiée au-dessus de la PR #510. Nouveau
`ui/contract_review.gd`, raccord de cinq lignes dans
`ui/immersive08/squad_canvas.gd`, banc dédié et cette notice. Aucun moteur,
contrat, règle, salaire, prix ou format de sauvegarde modifié. La prolongation
appelle `SquadViews.contract(app,p,false)` maintenu par le chantier négociation.

**30 contrôles sans fenêtre et 34 en rendu X11 réussis**, Node 22.23.4 et Godot
4.7.2. Le banc crée une vraie carrière, ouvre l'onglet, filtre les bons joueurs,
revient sur la bonne fiche avec son focus, ouvre une proposition sans signature,
reçoit les filtres vides, la remise à zéro et un nom long de recette. Il compare
le total hebdomadaire aux seules valeurs projetées et vérifie l'empreinte
inchangée du profil sportif. Des cas de projection couvrent 25 échéances, les
inconnues et le verrou de prolongation. La capture initiale montre 61 joueurs
réellement projetés par la carrière de recette, sans hypothèse fixe d'effectif.
Aucune validation native Windows ou CI distante verte revendiquée ici.

Pour rejouer : `CD_GODOT_EXECUTABLE=/chemin/Godot4.7.2 node --test
 tests/godot-contract-review.cjs`. Pour les captures, définir également
`QA_RESOLUTION=2560x1440`, `CD_CONTRACT_REVIEW_GRAPHICS=1` et éventuellement
`CD_CONTRACT_REVIEW_OUTPUT`, sur un écran X11 2560 × 1440. Les profils sont
créés automatiquement sous le dossier temporaire, hors de l'application.
