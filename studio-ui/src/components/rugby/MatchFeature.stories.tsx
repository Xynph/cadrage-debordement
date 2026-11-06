import type { Meta, StoryObj } from "@storybook/react-vite";
import { MatchFeature } from "./MatchFeature";
const meta={title:"Rugby/Prochain match",component:MatchFeature,parameters:{layout:"fullscreen"},args:{match:{opponent:"Stade Armorique",competition:"Championnat professionnel",date:"Samedi 14 novembre · 20 h 45",venue:"Stade des Docks"}}} satisfies Meta<typeof MatchFeature>;
export default meta;
type Story=StoryObj<typeof meta>;
export const Default:Story={};
