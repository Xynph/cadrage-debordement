# Extraction groupée ItsRugby — DATA06

L'utilisateur confirme avoir obtenu l'autorisation explicite de collecte automatisée et d'usage dans le jeu (31/10/2026).

**Un seul lancement télécharge des pages d'effectifs complètes, pas des profils individuellement :**

```sh
node tools/data06-itsrugby-bulk.cjs --clubs clermont,toulouse,brive,agen
```

Sur une machine avec accès Internet : sortie `data06-itsrugby-capture/`, un fichier HTML par club et un manifeste JSON avec URL, date, SHA256, erreurs et succès. Temporisation entre requêtes et échec explicite si page de contrôle ou HTML inattendu. **Pas de contournement d'accès, de captcha, de paywall ni de robots.**

GitHub Actions : une fois le workflow présent sur la branche par défaut, utiliser `Actions → DATA06 bulk roster capture → Run workflow` avec les slugs souhaités. Les pages sont disponibles en **artifact** pendant 7 jours. Les tests du script s'exécutent à chaque PR concernée.

**Attention :** capture brute uniquement. Le traitement et le rapprochement ID LNR se font après vérification du contenu, de la période et des homonymes. Pas d'intégration automatique au jeu, pas de compteur augmenté tant que l'audit réel n'a pas été fait. Les slugs ItsRugby doivent être vérifiés pour chaque club ; ne pas supposer qu'ils suivent les identifiants LNR. La liste de 30 clubs n'est pas encore établie.
