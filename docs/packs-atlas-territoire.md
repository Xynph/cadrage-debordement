# Photos de territoire des packs Monde

Depuis Windows 0.7.6, le registre Monde + Champ reçoit aussi un pack de
présentation `cd-identity-pack-v3`. Les packs v1/v2 et les carrières des
éditions précédentes gardent leur format et leurs contraintes. Le pack v3
n’ajoute aucun champ à une sauvegarde : il projette des images et des crédits
sur la fiche du club piloté, sous l’identifiant déjà utilisé pour ses noms et
son blason.

Dans `clubs`, la clé facultative `photos` contient `city` ou `stadium`.
Chaque photo référence un identifiant déjà déclaré dans `assets` et fournit
le texte de crédit, la page source et la page de licence HTTPS.

```json
{
  "id": 30,
  "photos": {
    "stadium": {
      "asset": "atlas-30-stadium",
      "credit": "Vue de l’enceinte · auteur · licence",
      "source": "https://example.org/photo",
      "license": "https://example.org/licence"
    }
  }
}
```

Les images sont bornées à 2 Mio chacune, au moins 320 × 160 et au plus
2 400 px sur chaque côté. Les empreintes, les chemins ZIP, les fichiers
installés et les champs d’attribution sont validés. La limite globale
d’archive et le nombre maximal d’entrées restent ceux des packs Monde.
L’activation ou le retrait ne change ni les identifiants, ni la progression,
ni les résultats. Une photo altérée rend le pack indisponible et la carrière
reste chargeable dans sa présentation de base.

Club → Territoire affiche les crédits et les adresses au survol du crédit ;
les deux aperçus du Bureau reprennent les photos disponibles. L’atlas intégré
des 30 clubs français reste le repli. Hors atlas, la fiche indique qu’aucune
photo d’archive n’est disponible. Les dates d’une photo et du calendrier de
stade peuvent différer ; les manifestes privés gardent le détail.

`tests/world-venue-media.cjs` couvre la projection, le retrait, la reprise,
les refus et l’altération d’une photo. Les contrôles Windows utilisent un
pack privé en profil jetable. Aucun média nouveau de ce pack ne fait partie
du dépôt ou de l’exécutable.
