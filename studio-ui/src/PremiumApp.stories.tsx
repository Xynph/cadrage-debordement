import type {Meta,StoryObj} from "@storybook/react-vite";
import {App} from "./PremiumApp";
import "./premium.css";
const meta={title:"Écrans premium/Navigation et quatre vues",component:App,parameters:{layout:"fullscreen"}} satisfies Meta<typeof App>;
export default meta;
type Story=StoryObj<typeof meta>;
export const Studio:Story={};
