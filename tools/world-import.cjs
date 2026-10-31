'use strict';
const fs=require('node:fs');
const {importCatalog,validateCatalog}=require('../world-data/r1/catalog.cjs');
function main(args=process.argv.slice(2)){
 if(args.length<1||args.length>2)throw Error('Usage: node tools/world-import.cjs catalogue.json [sortie.json]');
 const source=JSON.parse(fs.readFileSync(args[0],'utf8'));
 const result=validateCatalog(source);
 if(!result.valid)throw Error(result.errors.join('\n'));
 if(args[1])fs.writeFileSync(args[1],JSON.stringify(importCatalog(source),null,2)+'\n');
 process.stdout.write(JSON.stringify({valid:true,counts:result.counts,source:args[0]})+'\n');
 return result;
}
if(require.main===module){try{main()}catch(e){console.error(e.message);process.exitCode=1}}
module.exports={main};
