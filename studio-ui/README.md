# Cadrage Débordement — Studio UI Premium PC

Atelier **indépendant** React 19 + Vite 7 + Tailwind 4 + architecture compatible shadcn/ui + Lucide + Storybook + Playwright. Ne charge pas le moteur du jeu. Toutes les informations affichées sont des fixtures fictives. Aucune sauvegarde ni comportement sportif modifié.

## Développer

Prérequis : Node.js 22+ et npm 10+.

```bash
cd studio-ui
npm install
npm run dev
npm run check
npm run build
npm run storybook
npm run build-storybook
npx playwright install chromium
npm run test:e2e
```

## shadcn/ui

Le fichier `components.json`, les alias `@/*`, Tailwind v4 et une primitive `src/components/ui/button.tsx` de structure shadcn sont intégrés. Pour générer d'autres composants : `npx shadcn@latest add dialog table tabs` depuis `studio-ui/`. L'outil CLI n'est pas exécuté dans cet environnement ; ne pas confondre cette structure compatible avec un scaffold CLI validé.

## Isolation et livraison

- Racine autonome `studio-ui/` : ne jamais importer `../dist` ni modifier `dist/**`.
- Penpot = conception ; composants React = réalisation en fixtures ; Storybook = variantes ; Playwright = captures Chromium aux résolutions 1920×1080 et 1440×900.
- Première page = démonstrateur original du **Bureau manager**, pas une refonte livrée au jeu.
- Pas de fusion sans validation GitHub requise. `npm install` sans lockfile est un amorçage : ajouter un lockfile reproductible dès que la résolution du registre npm est accessible.
