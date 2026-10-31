# DATA-06 — Audit de postes sur pages d'effectif LNR

Lot de **90 entrées** couvrant Clermont, Provence Rugby, Toulouse et Brive. Chaque club conserve son URL LNR et le poste tel qu'il a été précédemment relevé ; les correspondances avec les 1592 identités existantes exigent une concordance stricte club+nom et excluent toute création approximative.

**Correction critique au 31/10/2026 :** les pages LNR actuellement consultables pour Toulouse et Brive présentent les matchs, minutes et points à zéro, contrairement aux chiffres relevés antérieurement. Impossible de garantir ces totaux à la date annoncée : **les trois champs sont remis à null pour les 90 entrées**, avec `statsVerification: unverified-as-of-snapshot`, et le validateur refuse toute nouvelle valeur chiffrée sans vérification documentaire reproductible. Un changement de poste affiché selon le moment de consultation doit également être traité comme un conflit de source, pas silencieusement remplacé.

Sources : https://top14.lnr.fr/club/toulouse/effectif-staff ; https://prod2.lnr.fr/club/brive/effectif-staff ; https://top14.lnr.fr/club/clermont/effectif-staff ; https://prod2.lnr.fr/club/provence-rugby/effectif-staff .

`node --test tests/data06-roster-batch.cjs` ; `node tools/data06-roster-batch.cjs` (ne fait aucune collecte). Cette PR n'enrichit pas automatiquement les biographies ou les carrières. Pas de chiffres financiers ni de notes sportives inventés.
