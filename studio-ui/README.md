# Cadrage Débordement — Studio UI Premium PC

Atelier **indépendant** React 19 + Vite 7 + Tailwind 4 + architecture compatible shadcn/ui + Lucide + Storybook + Playwright. Ne charge pas le moteur du jeu. Toutes les informations affichées sont des fixtures fictives. Aucune sauvegarde ni comportement sportif modifié.

## Développer

Prérequis : Node.js 22+ et npm 10+.

```bash
cd studio-ui
npm ci
npm run dev
npm run check
npm run build
npm run storybook
npm run build-storybook
npx playwright install chromium
npm run test:e2e
```

## shadcn/ui

Le CLI officiel shadcn a été exécuté avec succès en CI (`shadcn init --yes` puis `shadcn add badge --yes`). Le composant `src/components/ui/badge.tsx`, la primitive bouton, `components.json` et les alias sont présents. Ajouter les futurs composants via `npx shadcn@latest add dialog table tabs` depuis `studio-ui/`. Toute évolution des dépendances doit mettre à jour `package-lock.json`.

## Isolation et livraison

- Racine autonome `studio-ui/` : ne jamais importer `../dist` ni modifier `dist/**`.
- Penpot = conception ; composants React = réalisation en fixtures ; Storybook = variantes ; Playwright = captures Chromium aux résolutions 1920×1080 et 1440×900.
- Première page = démonstrateur original du **Bureau manager**, pas une refonte livrée au jeu.
- Pas de fusion sans validation GitHub requise. `package-lock.json` est versionné. La CI utilise exclusivement `npm ci` et un jeton GitHub en lecture seule.
