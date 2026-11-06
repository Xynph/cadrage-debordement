import type { Meta, StoryObj } from "@storybook/react-vite";
import { Button } from "./button";
const meta={title:"Fondations/Commande",component:Button,args:{children:"Préparer le match"},parameters:{layout:"centered"}} satisfies Meta<typeof Button>;
export default meta;
type Story=StoryObj<typeof meta>;
export const Primary:Story={args:{variant:"default"}};
export const Outline:Story={args:{variant:"outline"}};
export const Disabled:Story={args:{disabled:true}};
