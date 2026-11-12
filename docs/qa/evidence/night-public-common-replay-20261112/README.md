# Replay public Common 0 — Analyse, Club et Bureau

Source exacte `0e644e61ef3f78a6df4346f8d14d5ea33515c097` : **72 contrôles, zéro
échec, sortie 0**, durée wrapper 72,938245 s (TAP total 73,006040 s). Cette variante
`public-career-node` crée réellement une carrière Common, club 0 ; elle n’utilise
aucun checkpoint externe. La préparation Node prend 20,682 s, comprise dans le
budget global inchangé de 180 s. Aucun SDK/import n’a été relancé pour ces preuves.

## Préparation réelle et journal public

Les 20 commandes acceptées sont conservées dans le JSON et le journal JSONL,
avec leurs payloads et réponses de date/semaine. Elles avancent du 7 au 14 septembre
2026 par les journées réelles, traitent la presse et les rendez-vous, composent
l’équipe, ouvrent et délèguent le match, puis clôturent la semaine. Le vrai
résultat archivé est `s1-elite-league-0-0`, clubs 0/13, score 15–20, saison 1.
Le helper ferme son bridge avant la réouverture du profil dans le client.

`source-copy.json` identifie cette préparation publique : source et hashes de
source externe sont null. Ce n’est donc pas une preuve de copie « source
inchangée », contrairement au checkpoint WorldChamp précédent. Le hash du
profil produit est conservé dans public-preparation.json, sans publier le profil.
Les journaux ne contiennent aucun profil entier ni export sportif complet.

## Trois images originales inspectées

- [Analyse du vrai résultat](images/analyse-rencontre-reelle-2560.png).
- [Fiche exacte et statistiques collectives conservées](images/fiche-rencontre-reelle-2560.png).
- [Bureau et contexte réel](images/bureau-liens-reels-2560.png).

Captures natives 2560×1440, copiées sans retouche. La zone archive Common 0 garde
sa présentation claire préexistante ; aucune nouvelle charte n’est proposée.
Les vues Analyse et Bureau montrent des bulles textuelles Gabi. L’assertion
du test vérifie requested/started et identifiant de parole nuls, avec audio
Dummy ; elle passe dans les 72 contrôles. Ces valeurs ne sont pas sérialisées
dans report.json et aucun silence n’est déduit de l’image seule.

Les visites par ID et activation réelle couvrent score→rencontre, adversaire→club,
joueur→fiche, staff→profil, cash/wages→finances, puis Bureau→adversaire/date/
joueur surveillé/résultat. Les assertions vérifient les retours, choix joueur,
focus et scroll, aucune commande/écriture pendant la consultation et l’état
sportif/registre/RNG inchangé après export de contrôle. Le coût et le RNG des
commandes de préparation restent distincts de ces consultations.

## Scopes distincts et rouges conservés

- WorldChamp29 copié : 72/0 sur bd6, [preuves distinctes](../night-analysis-club-office-20261112/README.md).
- Reader-history frais : 115/0 sur bd6 selon réception intégrateur ; autre suite,
  autre préparation. Ce dossier ne lui substitue aucun de ses PNG ni rapports.
- WorldChamp29 graphique frais sur bd6 :timeout enfant 150 s pendant la préparation,
  sans rapport UI ni capture. Journaux conservés dans history/world-graphics-timeout.
- WorldChamp29 Node frais sur 89244201 :timeout 60 s, 23 commandes acceptées ; match
  délégué/confirmé mais semaine non clôturée. Aucun replay UI ni résultat UI
  n’est inventé. JSONL et journaux conservés dans history/world-node-timeout.

Ces échecs ne sont ni supprimés ni transformés en réussite par le changement
explicite vers Common 0. Deux variantes 72/0 ne constituent pas 144 contrôles de
couverture distincte. Ce dossier ne prétend ni recevoir WorldChamp fraîchement
préparé sous ses délais, ni qualifier une campagne SDK globale ou Windows.

[Contrat de préparation publique](../../office-public-preparation-20261112.md).
Le manifeste donne origines, tailles et hashes ; la provenance hache neuf
sources exactes. Vérification : `sha256sum --check SHA256SUMS`. Pour le registre
SDK, le pointeur concret de ce cas est qualified/report.json, complété par
qualified/public-preparation.json, qualified/run.log et provenance.json.
