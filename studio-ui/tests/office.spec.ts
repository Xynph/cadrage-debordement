import {expect,test} from "@playwright/test";
const pages=[["Bureau manager","Tout se joue"],["Effectif","L'effectif"],["Tactiques","Le plan"],["Recrutement","Les talents"]];
for(const [name,heading] of pages){
  test("capture "+name,async({page},testInfo)=>{
    await page.goto("/");
    await page.getByRole("navigation",{name:"Navigation principale"}).getByRole("button",{name}).click();
    await expect(page.getByRole("heading",{level:1})).toContainText(heading);
    await page.evaluate(async()=>{
      await document.fonts.ready;
      await Promise.all(Array.from(document.images).map(img=>img.decode()));
      await Promise.all(["/assets/premium/portraits/players-atlas-p3.webp","/assets/premium/backgrounds/stadium-night-p3.webp"].map(src=>new Promise<void>((resolve,reject)=>{const img=new Image();img.onload=()=>resolve();img.onerror=()=>reject(new Error(src));img.src=src;})));
    });
    const viewport=page.viewportSize()!;
    const documentSize=await page.evaluate(()=>({width:document.documentElement.scrollWidth,height:document.documentElement.scrollHeight}));
    expect(documentSize.width).toBeLessThanOrEqual(viewport.width);
    expect(documentSize.height).toBeLessThanOrEqual(viewport.height);
    await page.screenshot({path:"test-results/"+testInfo.project.name+"-"+name.toLowerCase().replace(/\s+/g,"-")+".png",fullPage:true});
  });
}
test("sélection joueur et prospect",async({page})=>{await page.goto("/");await page.getByRole("button",{name:"Effectif"}).click();await page.getByRole("button",{name:/Gabriel Moreau/}).click();await expect(page.getByRole("heading",{name:/Gabriel/})).toBeVisible();await page.getByRole("button",{name:"Recrutement"}).click();await page.getByRole("button",{name:/Milan Bernard/}).click();await expect(page.getByRole("heading",{name:"Milan Bernard"})).toBeVisible();});
test("XV et choix de plan",async({page})=>{await page.goto("/");await page.getByRole("button",{name:"Tactiques"}).click();await expect(page.locator(".marker")).toHaveCount(15);await page.getByRole("button",{name:"Joueur numéro 9"}).click();await expect(page.getByRole("heading",{name:"Numéro 9"})).toBeVisible();await page.getByRole("combobox",{name:"PLAN DE JEU"}).selectOption("Conquête");await expect(page.getByText("Fixer la défense")).toBeVisible();});

test("assets premium originaux servis en local",async({page})=>{await page.goto("/");const paths=["/assets/premium/crests/atlantique.svg","/assets/premium/crests/armorique.svg","/assets/premium/portraits/eliott.svg","/assets/premium/backgrounds/bureau-ai-preview.webp","/assets/premium/backgrounds/effectif-ai-preview.webp","/assets/premium/backgrounds/tactiques-ai-preview.webp","/assets/premium/backgrounds/recrutement-ai-preview.webp"];for(const path of paths){const response=await page.request.get(path);expect(response.ok(),path).toBeTruthy();expect(response.headers()["content-type"],path).toMatch(/image\/|octet-stream/);expect((await response.body()).length,path).toBeGreaterThan(100)}await expect.poll(()=>page.locator("img").evaluateAll(els=>els.every(el=>(el as HTMLImageElement).naturalWidth>0))).toBeTruthy()});

test("préparer la rencontre ouvre les tactiques au clavier",async({page})=>{
  await page.goto("/");
  await page.getByRole("button",{name:"PRÉPARER LA RENCONTRE"}).focus();
  await page.keyboard.press("Enter");
  await expect(page.getByRole("heading",{level:1})).toContainText("Le plan");
  await expect(page.getByRole("button",{name:"Joueur numéro 10"})).toBeFocused();
});

test("la recherche sans résultat permet de retrouver le groupe",async({page})=>{
  await page.goto("/");await page.getByRole("button",{name:"Effectif",exact:true}).click();
  const search=page.getByRole("textbox",{name:"Rechercher un joueur"});
  await search.fill("inexistant");
  await expect(page.getByRole("status")).toContainText("Aucun joueur");
  await page.getByRole("button",{name:"Effacer la recherche"}).click();
  await expect(search).toBeFocused();await expect(search).toHaveValue("");
  await expect(page.locator(".player-row")).toHaveCount(6);
});

test("portraits et attributs suivent réellement le dossier sélectionné",async({page})=>{
  await page.goto("/");await page.getByRole("button",{name:"Effectif",exact:true}).click();
  const portraits=new Set<string>();
  for(const name of ["Gabriel Moreau","Noah Leclerc","Mathis Lavigne","Sacha Perrin","Eliott Garnier","Léo Valette"]){
    const row=page.getByRole("button",{name:new RegExp(name)});await row.click();
    const picture=page.getByRole("img",{name:"Portrait fictif de "+name,exact:true});
    await expect(picture).toBeVisible();
    const position=await picture.evaluate(el=>getComputedStyle(el).backgroundPosition);
    expect(await row.locator(".portrait").evaluate(el=>getComputedStyle(el).backgroundPosition)).toBe(position);
    portraits.add(position);
  }
  expect(portraits.size).toBe(6);
  await page.getByRole("button",{name:/Gabriel Moreau/}).click();
  await expect(page.locator(".attributes>div").filter({hasText:"Vision"})).toContainText("65");
  await page.getByRole("button",{name:/Eliott Garnier/}).click();
  await expect(page.locator(".attributes>div").filter({hasText:"Vision"})).toContainText("91");
  await page.getByRole("button",{name:"Recrutement",exact:true}).click();
  const recruits=new Set<string>();
  for(const name of ["Théo Briand","Milan Bernard","Rayan Diallo"]){
    const row=page.getByRole("button",{name:new RegExp(name)});await row.click();
    const picture=page.getByRole("img",{name:"Portrait fictif de "+name,exact:true});
    await expect(picture).toBeVisible();
    const position=await picture.evaluate(el=>getComputedStyle(el).backgroundPosition);
    expect(await row.locator(".portrait").evaluate(el=>getComputedStyle(el).backgroundPosition)).toBe(position);
    expect(portraits.has(position)).toBe(false);recruits.add(position);
  }
  expect(recruits.size).toBe(3);
});

test("les photos nettes sont chargées et utilisées",async({page})=>{
  await page.goto("/");
  const sizes=await page.evaluate(async()=>Promise.all(["/assets/premium/portraits/players-atlas-p3.webp","/assets/premium/backgrounds/stadium-night-p3.webp"].map(src=>new Promise<{width:number;height:number}>((resolve,reject)=>{
    const img=new Image();img.onload=()=>resolve({width:img.naturalWidth,height:img.naturalHeight});img.onerror=()=>reject(new Error(src));img.src=src;
  }))));
  expect(sizes[0].width).toBeGreaterThanOrEqual(1200);expect(sizes[0].height).toBe(sizes[0].width);
  expect(sizes[1].width).toBeGreaterThanOrEqual(1600);
  await expect(page.locator(".hero")).toHaveCSS("background-image",/stadium-night-p3/);
  await page.getByRole("button",{name:"Effectif",exact:true}).click();
  const portrait=page.getByRole("img",{name:"Portrait fictif de Eliott Garnier",exact:true});
  await expect(portrait).toHaveCSS("background-image",/players-atlas-p3/);
  const box=await portrait.boundingBox();expect(box).not.toBeNull();expect(box!.width).toBeLessThanOrEqual(sizes[0].width/3);
});
