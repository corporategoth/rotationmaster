import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {decodeImport} from '../Web/codec/import.mjs';
import {toTypedTree,checkPortable} from '../Web/codec/lua-data.mjs';
import {validateEnvelope,indexRotationSteps} from '../Web/schema/rotation.mjs';
import {diffRotations} from '../Web/schema/diff.mjs';
let api;try{api=await import('../Web/catalog/defaults.mjs');}catch(error){if(error.code!=='ERR_MODULE_NOT_FOUND')throw error;}
const root=new URL('..',import.meta.url),catalogURL=new URL('../Web/catalog/defaults.json',import.meta.url);
const declarations=readFileSync(new URL('../Web/schema/catalog.json',import.meta.url),'utf8');
const text=()=>{assert(existsSync(catalogURL),'generated bundled catalog missing');return readFileSync(catalogURL,'utf8');};
const raw=()=>JSON.parse(text());
const parse=(value=text(),schema=declarations)=>{assert.equal(typeof api?.createBundledRotationCatalog,'function','pure bundled catalog API missing');return api.createBundledRotationCatalog(value,schema);};
const ready=()=>{const r=parse();assert.equal(r.ok,true);return r.catalog;};
const reject=doc=>{const r=parse(typeof doc==='string'?doc:JSON.stringify(doc));assert.deepEqual(r,{ok:false,reason:'invalid-bundled-catalog'});};
const bytes=s=>({type:'bytes',hex:Buffer.from(s,'latin1').toString('hex')});
const fields=m=>new Map(m.entries.map(([k,v])=>[Buffer.from(k.hex,'hex').toString('latin1'),v]));
function set(m,k,v){const hex=bytes(k).hex;const row=m.entries.find(([key])=>key.type==='bytes'&&key.hex===hex);if(row)row[1]=v;else m.entries.push([bytes(k),v]);}
const number=n=>{const b=Buffer.alloc(8);b.writeDoubleBE(n);return{type:'number',bits:b.toString('hex')};};

const fixtureURL=new URL('./fixtures/web_defaults.json',import.meta.url);
const SAMPLE='rm.tbc.shaman.enhancement.icyveins',SAMPLE_SOURCE='Defaults/tbc/shaman-enhancement-icyveins.lua';
// The packaged premades of every edition (TBC Anniversary, WoW Forever and
// Retail), frozen in catalog order: [id, step rows, sha256 of
// JSON.stringify([catalog pack object, wire fixture record])]. Re-freeze only
// alongside a deliberate pack change (regenerate with the repo's generators).
// The wire half pins the committed fixture bytes: the codec serialises in
// pairs() order, which LuaJIT varies run to run, so a fresh --fixtures run
// differs byte-wise while staying semantically equal (see the last test).
// Never regenerate it to go green. (The Retail regeneration rewrote every
// TBC/Forever wire this way: catalog objects, expected trees and row counts
// were unchanged, only wire bytes moved, so those digests were re-frozen.)
const PREMADES=[
 ["rm.forever.druid.balance",28,"10b9260228a096271961ad5614a2a723bf2d00df2332f7539df641d44fbd4680"],
 ["rm.forever.druid.balance.tavern",14,"42f14547b14908b6d83c14fa6b76e0348d8fcb00eb3f832f363636f5a7fe6e6f"],
 ["rm.forever.druid.feral",44,"dd3dc8a28a5af0fad1ac2cc26882091e3f074de3d1df8b7c23035c11309caa03"],
 ["rm.forever.druid.restoration",23,"ee937de30c79b3b4f30515ad76add43dbec950786433eda530424ecf0124129d"],
 ["rm.forever.druid.restoration.icyveins",23,"60fd1a02ea6bed2f75416909a9f4a51ebee205ccc6493b322ce6b16578cc3349"],
 ["rm.forever.hunter.ranged",45,"e857331a657aa619f93d282927393f3832f77cb6d05b06195cc14906079a2f7f"],
 ["rm.forever.hunter.ranged.mobalytics",40,"211067e4710c5f208b628a624359ebdf715ac25bbd7a277fbb263735769133a6"],
 ["rm.forever.hunter.survival",30,"a43fefbc2831c185b3202f473e2055eff2e46ae70bed415d3163a5f024f9a283"],
 ["rm.forever.hunter.survival.weave",31,"3ee92da386ed6e373c9639b9f8020107b626e1f425d838b93267869ce10533e9"],
 ["rm.forever.mage.arcane",38,"a5df0cc32c5092770164f2a3249842f6f6a73305bbd674fd15609f015d6a67ff"],
 ["rm.forever.mage.fire",40,"d991320cd13fadd1bdbb28bf511080dadb865b4f268548acc134b645d3aa7a08"],
 ["rm.forever.mage.fire.icyveins",32,"95363989252e9b6634981791e08ef84ec136208bd7bd3e55888206f86d2f04f6"],
 ["rm.forever.mage.frost",42,"b628d55d480bdffb0dbf60c69653e96dce281993e699115876cbad40e81b467b"],
 ["rm.forever.paladin.holy",28,"7d1c4988a832c697f9365e9ade99f964a0f500b816de70a412035222f93be9a7"],
 ["rm.forever.paladin.holy.wowhead",26,"b8f50e51ce3880907521fcb1925b96d6b773fb01bfcc580a9c9fc664859800fc"],
 ["rm.forever.paladin.protection",24,"e23bab8934295d6769ad994db6df942f33faa9529fb0ccc44e2de7f20370e3b2"],
 ["rm.forever.paladin.protection.icyveins",18,"8c08cb2436efd9a4e06e53de3b6b3942d4584141e45f96fc3706b8763899143a"],
 ["rm.forever.paladin.retribution",30,"16253a292b4ac40457dae8a1334fcfdf8d4574917271e894e7e795d428d4fc36"],
 ["rm.forever.priest.dps",60,"35f00f8826aa43d28ff90ee68beb2bb9d3b9d274861e39294d466a50605d87b0"],
 ["rm.forever.priest.dps.mobalytics",44,"b467f4e8af23c87a5d8370c8b5893e0f72d0bb440a26fd7a221ceef9b3ba7060"],
 ["rm.forever.priest.healer",45,"9f6c658c730df0f4e6e12778d06ee664340507a7e3b7ff947266592d534c075c"],
 ["rm.forever.rogue.dps",39,"1ba6023b49c4db3051e70ec34cced3b6e15192f9bd3b02fad760fe3276bee3a8"],
 ["rm.forever.rogue.subtlety.warcrafttavern",30,"ef3a19572147c9ae0c8e43ce0450c041bd59bc292d5e8762bb7899033a0d3f20"],
 ["rm.forever.rogue.subtlety.wowhead",29,"516d1594de7b187e4d09b2c166072d8c873d95bd0608f6d2f0dccd700f0c3bed"],
 ["rm.forever.shaman.elemental",35,"cb13926ea2082c981d042773c8577b3646225f54b9eb8afedbb60ac5c1f36235"],
 ["rm.forever.shaman.enhancement",30,"70fb3a63c1db180d633bbe11f1772321018684306ace393ddeb9ca577d35724b"],
 ["rm.forever.shaman.enhancement.wowhead",17,"95dc54c576cbae7d29ccf6d7ffb25421884e4233ade2cda9c501b128fc278f38"],
 ["rm.forever.shaman.restoration",27,"427c4f8ecbbf55bf7eb82c1daf032303369c1e13f94a91a5cd9f0a175f1ec3e3"],
 ["rm.forever.warlock.dps",64,"ea52323b3dc525f73c999dad354de466efe9b15859a2b314ec2406e1f700f6e3"],
 ["rm.forever.warlock.dps.icyveins",67,"bf55f4f840749276eba782c48877102401f64a9c2f580cda19b29bb5a7ce22e3"],
 ["rm.forever.warlock.dps.wowhead",57,"9b0654b616afbdf17e912847e83bd88a0fb9e14cad4c886089b0bb0b6b1acdac"],
 ["rm.forever.warrior.dps",36,"7bdf1a3a6decff83d61fd8b9ff4368ed30f71567858ca602ca98622512fda3d3"],
 ["rm.forever.warrior.dps.warcrafttavern",23,"d884276396c0acf98d61b44d5a634ed6d273e38a32a9ed3074bf4724df36028b"],
 ["rm.forever.warrior.protection",31,"b445e499fa81777d9c947ec4340435c8a156db81e3dfb1571252f79a7233e95e"],
 ["rm.forever.warrior.protection.warcrafttavern",17,"8d37257e7c4ab8d5fb6800c387ef1bd0edd0db7ffbde677885d58f6fb2668fc3"],
 ["rm.retail.deathknight.blood",11,"260fb76ad8103b3230383d6af9829ba80126d8fe3d332a588ec4816cfcb6b3cc"],
 ["rm.retail.deathknight.blood.guide",30,"2cd4532872f2e9ec04680da57ca28f0627e10a0ba6259a06e1384f7891a51ff7"],
 ["rm.retail.deathknight.blood.simc",26,"c017e226f65e9370417035856e269e68db2dd839ddcbb843d878eab38594ae96"],
 ["rm.retail.deathknight.frost",11,"fa55303f31c50599db5582f1cc80dfb9ec6f686058a02e5c0e1211dd49668373"],
 ["rm.retail.deathknight.frost.guide",33,"0c84d6dd04037f8a0eb05d19810389c993e24bd031d3a00e4a4e27767be45d9d"],
 ["rm.retail.deathknight.frost.wowhead",34,"c5834bbe9b00f7defbb9ce950ba3576755d9a3017af3e727f32fa29b8b7f9ef1"],
 ["rm.retail.deathknight.unholy",9,"ed24d8547f942f71533b46de6c061618272ef7682b715801b5578789e17e5c74"],
 ["rm.retail.deathknight.unholy.guide",21,"18bba8a88e9b370a665fa0be641747af6f8ef2b7fd032b2059a7ddc0c34f94a2"],
 ["rm.retail.deathknight.unholy.simc",30,"bc58729322c4cfe9dcaf3e8b2c26f8f775a7ada3f5e0471234f06087768f4115"],
 ["rm.retail.demonhunter.devourer",8,"a5492126a32f4031b4ab0a2a67d9c48d21f799b00f716a4da557ed5b13f281c0"],
 ["rm.retail.demonhunter.devourer.guide",23,"3a654ca03b2b43bf896baa61d8da5ce21f1962a6535691cc6de32dfec3b841f4"],
 ["rm.retail.demonhunter.devourer.simc",21,"8b53de0989da71d021a1b84975f902826bf7e1d7b1fa25ff958aa23fbfab842f"],
 ["rm.retail.demonhunter.havoc",8,"23a49b5235fd08026811d63ddad14e69b8d397e5e49dab490901cb9f947af24d"],
 ["rm.retail.demonhunter.havoc.guide",24,"be92b9bdc73eb141ad4ba60c2b5d07d7acd6b17f7680013a2bbb01594202a6c9"],
 ["rm.retail.demonhunter.vengeance",9,"34ab92c34db226ba610af9ca0722d2fe4575baa8c84dff6956af3723dd39f671"],
 ["rm.retail.demonhunter.vengeance.guide",24,"67c52423d36391d820a5eb90d7fcdbfa2062bc458939bbb77eddb17a10f3a495"],
 ["rm.retail.demonhunter.vengeance.simc",36,"57e2ad21284fe185696139453a82a446607dff453a9679c012c3c124d651d6ef"],
 ["rm.retail.druid.balance",11,"690d6f3fe5c9d5d57535a281975ad1fa1b4a47eeb39e4b866d0e50483f628509"],
 ["rm.retail.druid.balance.guide",29,"272b69482e970f72d47e80b0edcefafed08cacf20a4d2f1b877025ca230c2810"],
 ["rm.retail.druid.feral",12,"b27752532ccb3cd46513776c0153d8eb619d8b402697d4863a0f3cc8077a6815"],
 ["rm.retail.druid.feral.guide",30,"8750eafd629438b3bc403752031b4de1b1b5fd065f05967b85e5ca666e617525"],
 ["rm.retail.druid.guardian",15,"b3aa03caf6b2694cbd099555ad85d5dbb64b5966aec893feb5cb10a1128f4d80"],
 ["rm.retail.druid.guardian.guide",24,"57681686da78395231661bb4b7f2e6fce59065aab25df46e047787b7ce008ddb"],
 ["rm.retail.druid.guardian.simc",25,"2f2ede96ce13cd1019e5212a3d355fb9f8c938b5a5aaaa132b2be010396d43d1"],
 ["rm.retail.druid.restoration",15,"605e54a5c31f2f8ec931f8bd6cde30f6db5d809a7490773769e3448b7223b67a"],
 ["rm.retail.evoker.augmentation",22,"bef50eaa90fddad1b7fd05bfa2fe51fe4a03f467f448c528c3c40da8ce684e11"],
 ["rm.retail.evoker.augmentation.assisted",11,"16261e0f77f2caf1f6f990d2aab32e5d801bb4f85bc8398ff8467a344de5356b"],
 ["rm.retail.evoker.devastation",10,"5bb836c610f68d59e9186ca739e3813fca3fd9fd6152c72d1a070d15b42036fe"],
 ["rm.retail.evoker.devastation.guide",33,"46809f35611fb21db5708672b3d99d22b1df3d5de3304edc2e1fb92441304b60"],
 ["rm.retail.evoker.preservation",12,"bb10307dbba670eff737f5b965320ff7d61fafe0a64c9e38a341cfbe95b9cb90"],
 ["rm.retail.hunter.beastmastery",13,"fbad98b965a0bf1260055740713260a5b35c67997d17937ad70e0686fd1549af"],
 ["rm.retail.hunter.beastmastery.guide",44,"89e29877a9e2533d62d317173fe1bd235f0a8934c82d4dd3bca70f8ab64eb224"],
 ["rm.retail.hunter.marksmanship",13,"5b5d0d27ce606eedd500a0e9e44ac1f81afa889cbfd51ab7ac64bc382fcd2f69"],
 ["rm.retail.hunter.marksmanship.guide",52,"7efb0fd2010e6207b421683c06911f69645415b515933428230b1ce11e5c1035"],
 ["rm.retail.hunter.survival",13,"2b0ca86059f8af50c92ee773d4efd36f38d6e7357989667544abc95fe5c78cad"],
 ["rm.retail.hunter.survival.guide",45,"2f574b0fa15a6d039a0d536761507a152989144fe4e2ded294084015645a1d1b"],
 ["rm.retail.mage.arcane",12,"466c9d496d4eb95db6db348fa774c518b93f448a9aa49fa5226ada309bf6cd42"],
 ["rm.retail.mage.arcane.guide",33,"10371cd6e9b1ebc1131e880b6cbf82f5f4dcb23bccf0d37d8a0bce886c4b1c33"],
 ["rm.retail.mage.fire",12,"c3d18f9c1df3e5f6f3cede358201eff2c97d482ff0168529cb04256c869a7a4f"],
 ["rm.retail.mage.fire.guide",34,"e4555c335f2fc7e657fdf0d978487ebb7b8a91d926d1c301d956fba0f64924b4"],
 ["rm.retail.mage.frost",12,"96b38cf1f95d8b4003396fa3c5f0c66da6dfe9f5f6fe6d90e0d504de5dfa8794"],
 ["rm.retail.mage.frost.guide",47,"9366cf0e55d0560dbd94510227817b068704258884cb5e55e92bd3b5078af628"],
 ["rm.retail.monk.brewmaster",15,"15c9e67066801b6079058eab24ecf0e3428e4b6f8204289aa7d704090156534d"],
 ["rm.retail.monk.brewmaster.guide",31,"1efda6b189dfceea11c753ddcbf04bd95e87c6205c7f9709f96fa22876077690"],
 ["rm.retail.monk.mistweaver",12,"5bf65d4450fea896d3593eedd7919b9b7809c173643430790838b6f6c7ef4e55"],
 ["rm.retail.monk.windwalker",13,"353f1d6b013660a849d62685ba1025618684888115b5eee94d41f91d7ac45e84"],
 ["rm.retail.monk.windwalker.guide",30,"7b3f4e20fff136afd09cb6fb0f3abed4493b6024b9fd36f839d1411a677c7597"],
 ["rm.retail.paladin.holy",24,"145e934a9403a278af06175ef41d176b5ca62f7d0894dd2cb22a803f3b126213"],
 ["rm.retail.paladin.protection",8,"9c765be07c6f9f3c21f8a3bbbb648543fd2395de4edd0cc5dfb1733523a0aa8c"],
 ["rm.retail.paladin.protection.icyveins",26,"4279cc33b66ed7037a181e202a286d7a561858ec4086495d312b3a79643d849d"],
 ["rm.retail.paladin.protection.wowhead",19,"68a6f3a558d34e3fb7d2dce1490c88d4dde863cee77b1e276bed29fa5efc052f"],
 ["rm.retail.paladin.retribution",7,"fc12cc0789e7f0e66e3cc7a26cf3f1bf7306415870daeea7045660ec2c50c9c1"],
 ["rm.retail.paladin.retribution.icyveins",24,"484002fd23e67312db84b8564fc8f8be059dd6402718417462f05298dfa6c54a"],
 ["rm.retail.priest.discipline",23,"9103b097f505d31bd72912b5e2f6e242c779d2e84189dc5ac1fd74e52592338c"],
 ["rm.retail.priest.discipline.wowhead",19,"159c6715828671ee6a2d791882bd55a00190bdb4e086f2769f59d746dff8b9a7"],
 ["rm.retail.priest.holy",25,"0bbfb7b17efe4248cc28703d45c7e6e515dbdefab170141a341fea31ae839b73"],
 ["rm.retail.priest.shadow",8,"35c0d7bbe97598c7585d31a5fd5a6500bf562aa1438c3c899ea99a4894792ff7"],
 ["rm.retail.priest.shadow.icyveins",30,"783b125f22dcb8e4b4be978b5a1874824dd852e5fe1cfa5a5d63b1b5f2a56992"],
 ["rm.retail.rogue.assassination",10,"b063632b620740d182e3a083cc9e103d6d7937f0f474b64490c1caa6fee6c5b6"],
 ["rm.retail.rogue.assassination.icyveins",26,"20e40382e8f2d0503124b00f247c3c82e4169f62dfbc0a764abdeded88bd9c59"],
 ["rm.retail.rogue.outlaw",10,"563d849d1daaf16f42af5d0f05c55c891cb1ee6414b363c539ead5c04238140c"],
 ["rm.retail.rogue.outlaw.icyveins",25,"9813a2fcc15ba5d65487c80531e6e11ec5d367639aafc1c1d2e85772be355232"],
 ["rm.retail.rogue.subtlety",9,"7cc1a87c835aef6c84ad0be2b42fc7bee07799bdf0031b7b06f9d7e29162f524"],
 ["rm.retail.rogue.subtlety.icyveins",25,"695719d60101074b7dcfbf27daf3d857f1490ef7d643ea1485e03e2b93c1cc1a"],
 ["rm.retail.shaman.elemental",12,"083486637e26b5921a08b388ef472511f2a340f5de0650b2f8e8e398155e90c1"],
 ["rm.retail.shaman.elemental.icyveins",40,"6549715212885542913a41a1c9648ee20db039783ff5cc6ddddc6c7683ee9c0e"],
 ["rm.retail.shaman.enhancement",10,"f9099565db88538f8cc9b3029ad0728409a121869e93f81f6b9b100a7c650e18"],
 ["rm.retail.shaman.enhancement.stormbringer",34,"0fa086b85f1713dfeda1903b96546279e826b9139caf0a879fef707328f0de3e"],
 ["rm.retail.shaman.enhancement.totemic",28,"95ece5113979d414018312de0549676485247b2bdc505db3c08c213b07bc330f"],
 ["rm.retail.shaman.restoration",22,"a80ab18aee1a600446688d55d435b8fefa35dfbd73cec9f4086442975cf06f79"],
 ["rm.retail.warlock.affliction",8,"f9d1320a381f7d3d758837e85f8b5c591251dbb81ac75d95c035eb9ae23087e2"],
 ["rm.retail.warlock.affliction.icyveins",23,"f48ed26aacefcf26b1e23b69841a595735d171cedaa38f2e3c1062fd4d239624"],
 ["rm.retail.warlock.demonology",11,"6d9470acade807bcbca5450ccf0c88fab67a01ff61c75639ba7bb5101d938592"],
 ["rm.retail.warlock.demonology.icyveins",23,"c62465bfe5ee92c0420254aaf8531aaa47ab7bd8015aa4c5bbdbaf7b5bb49a6f"],
 ["rm.retail.warlock.destruction",8,"3b660b528aac2c854bc1672badbf518c6ef6b5579c1beffb2c10cfd24f6c65e4"],
 ["rm.retail.warlock.destruction.icyveins",20,"ae3391caa732b1fb98afb2e731bb78c8986811abd284db93f61755a7e051b474"],
 ["rm.retail.warlock.destruction.simc",25,"a591fc2f0d00576219da8eb698824992cd32ac361a8414f8b96e0f86e3a37f8b"],
 ["rm.retail.warrior.arms",9,"03213a2e723fdaab5b0355faa966c0ba55338f03cdeb2e00b48fe6a6f33d9902"],
 ["rm.retail.warrior.arms.colossus",24,"f47961a212421ca23c834ead8d0f4ab72afb40a448b180c314422367137f4059"],
 ["rm.retail.warrior.arms.slayer",22,"82261a0130993590c3b8b58928ae3e1e2b9748674d06357be5c5612089bb0144"],
 ["rm.retail.warrior.fury",9,"8d99f1d4cd6caa24bc59868724824126e3930bc61387fd0933126a9355d56028"],
 ["rm.retail.warrior.fury.slayer",26,"3a612bd9b57f755ed9c30cf304906dd8d74fd227cec436bb0a118261057e8474"],
 ["rm.retail.warrior.fury.thane",26,"fbbc4a760517763d8bc7bdec8be139348979c62ee82dce925635ce40640d4d9c"],
 ["rm.retail.warrior.protection",13,"c2fa6ef231b739234f7d569292ac027f3ec512fa357ea3c18c905ee41b06cce4"],
 ["rm.retail.warrior.protection.icyveins",24,"9731a9e9f140534d0cb98748ca2849936442c6b11080a0f0eb4c2236874db4e8"],
 ["rm.tbc.druid.balance",25,"25a57e8f1e73008f1151fa483bce5efca03d3b41fd3cae640c3da2ff6a847ab0"],
 ["rm.tbc.druid.feral.icyveins",44,"4d0dc72da52b456f09679e113f5509e4018894f635a7c414f38f3ddcd334903b"],
 ["rm.tbc.druid.feral.wowhead",44,"37635e109f5f85b6453a9683e9f9e8767aa43f8555b2cb1ac3b9be98f7b9759d"],
 ["rm.tbc.druid.restoration",25,"a68396cdb04d424d12fd913a0b0f00ad0f18e334b54a895160e4b6c703b58f85"],
 ["rm.tbc.hunter.ranged.wowhead",40,"1f610a06176ea4a19e8d543d37b4ccb505559e5183626d96318fbdc840419b77"],
 ["rm.tbc.hunter.ranged.wowsims",44,"0eac99c8d06c7f5ae3b39209d2036f35b162a89e23b367d629f201c794c0ed88"],
 ["rm.tbc.mage.arcane",43,"b244cce943d980a373008a44f7ba750fabfedc01ee8af22f96f9fd3de66f1eaf"],
 ["rm.tbc.mage.fire.icyveins",39,"57640e17855bd6ae5241d677b24807c235cee7e586ac79469f7e8af3cfe55c07"],
 ["rm.tbc.mage.fire.wowhead",39,"e4ece431258bd2162713b8087b239ec142fde561ddf68ec8cbc9252bb67e01c8"],
 ["rm.tbc.mage.frost",43,"4557d9ff03b84e0788aa27d196fae3346e1b42618c61564e1521e69f6ab98d5c"],
 ["rm.tbc.paladin.holy",19,"1a9855f13236304b9c31f4b8ecc11d2206e8eaa66ca2114d7b3f625413e482ae"],
 ["rm.tbc.paladin.holy.wowhead",18,"370736b1901e220ba575247f66365e6d8518189c08465b15aeb57ff442defe19"],
 ["rm.tbc.paladin.protection.icyveins",19,"01bde68cf6f3c0c396bd7a15f2775067815a797246a47afc4b52fbc983d27426"],
 ["rm.tbc.paladin.protection.wowhead",26,"3ca28a49f4cade5fde1ca09226c871b145c74118e029f9f4478c3826065fcdf3"],
 ["rm.tbc.paladin.retribution.icyveins",24,"b89c4770e9cfc7cda18674240647fc293d40b92017ad709e646eada3063f1216"],
 ["rm.tbc.paladin.retribution.twist",32,"03dd5d12bce95c38f44077dffa82fb7a48a3cbd1bd8ee8c18678a59372c16e97"],
 ["rm.tbc.paladin.retribution.wowhead",23,"a197608a4384737ea763e0a14894332fd39603bc6fc46bc18c1e3185a8a1972b"],
 ["rm.tbc.priest.dps.icyveins",49,"d8953c2bd37cc1e0d4f23b2d61684f02823aa1668cf28acccd9119e970c4d60d"],
 ["rm.tbc.priest.dps.wowhead",46,"8577e01c69227963adbf2ab66da3a5098a05d0a76f50691256bce50bb8de46cd"],
 ["rm.tbc.priest.healer.icyveins",35,"6c5514a9b58fa323b97d2acf8d8452969a95d64dbc6deefdca3510e085e5f472"],
 ["rm.tbc.priest.healer.wowhead",40,"645411ba6a91b3da4230686af8dbb16ff17c3b9873ba290563262b44f0c70f24"],
 ["rm.tbc.rogue.dps.wowhead",30,"3c9bad9be40780d1bc968f8b0f68f2f50135ca53616ed013629aedadb657e59d"],
 ["rm.tbc.rogue.dps.wowsims",32,"3e8196a652b69e7a1f5a8f41ab3a328010a8d5d2e15cb35599dbb811ea228dd5"],
 ["rm.tbc.shaman.elemental.icyveins",26,"1685f968747d0204b09ffa39b216c0a7e4bfd6c96d3586b2e3cd0dbcfa07314b"],
 ["rm.tbc.shaman.elemental.nextaction",14,"10a268ae7660259095430132e44d45d3f035132ac27304c59b0543f517914ea8"],
 ["rm.tbc.shaman.elemental.wowhead",26,"be19ed26f97da14bef93e5da45b1bd5c3f25a0736b8471422deeb456d3f0d054"],
 ["rm.tbc.shaman.enhancement.icyveins",31,"14037487ec2f84568dcdb0a0eeecd7175b90ff1fb906f706ba28c63c9a128937"],
 ["rm.tbc.shaman.enhancement.wowsims",31,"434517fc161656f80651ab93010b83d6cb6a8d8865c9aac5b15179cb54d58752"],
 ["rm.tbc.shaman.restoration",24,"12058a5de408ab8da48d809b331cce4738aa5854671dbc462886b519bde54472"],
 ["rm.tbc.warlock.dps.icyveins",59,"113d57b781e0dd72e0b35b9eac9e2835242a9979f3dd2b27df0700b485143a0f"],
 ["rm.tbc.warlock.dps.wowhead",56,"115cd2b3f6c2d9f7cd6a19a5c346f1700f114215336e0d8cf9a3ae436e2fb76e"],
 ["rm.tbc.warrior.dps.icyveins",32,"3140b733b765edcf6ab7aed13b17d19c6432c5111d07e418c22d641a8f08480b"],
 ["rm.tbc.warrior.dps.wowsims",34,"f0de28efcede594ea93edf6fb40574a43c114ea814a90599e7dd399b30ebc21c"],
 ["rm.tbc.warrior.protection.icyveins",22,"4a65d70e07dbfb4fd80bf2175693c3694afe2def95cbc0edc21f9209d5706c9a"],
 ["rm.tbc.warrior.protection.wowhead",24,"19bccf416cbd664c47219905d6522d69e370524a76518ab1c7af9ea92712a40e"]
];
const FAMILIES=['forever','retail','tbc'];
const FIXTURE_SHA='b60b42304f7b9af5fe4ff75582ddccb854d5b8992fd494d60677a03a79152f59';
// Generator stdout: the catalog and the fixtures each run to several MiB now
// that Retail is bundled; 4 MiB overflowed (ENOBUFS).
const GENERATOR_OUTPUT=64*1024*1024;
// Every pack whose body is disabled as a whole, in catalog order: the Retail
// reference variants and the TBC seal-twisting premade.
const TWIST='rm.tbc.paladin.retribution.twist';
const DISABLED=[
 'rm.retail.deathknight.blood.guide','rm.retail.deathknight.blood.simc','rm.retail.deathknight.frost.guide',
 'rm.retail.deathknight.frost.wowhead','rm.retail.deathknight.unholy.guide','rm.retail.deathknight.unholy.simc',
 'rm.retail.demonhunter.devourer.guide','rm.retail.demonhunter.devourer.simc','rm.retail.demonhunter.havoc.guide',
 'rm.retail.demonhunter.vengeance.guide','rm.retail.demonhunter.vengeance.simc','rm.retail.druid.balance.guide',
 'rm.retail.druid.feral.guide','rm.retail.druid.guardian.guide','rm.retail.druid.guardian.simc',
 'rm.retail.evoker.devastation.guide','rm.retail.evoker.preservation','rm.retail.hunter.beastmastery.guide',
 'rm.retail.hunter.marksmanship.guide','rm.retail.hunter.survival.guide','rm.retail.mage.arcane.guide',
 'rm.retail.mage.fire.guide','rm.retail.mage.frost.guide','rm.retail.monk.brewmaster.guide',
 'rm.retail.monk.mistweaver','rm.retail.monk.windwalker.guide','rm.retail.paladin.protection.icyveins',
 'rm.retail.paladin.protection.wowhead','rm.retail.paladin.retribution.icyveins','rm.retail.priest.discipline.wowhead',
 'rm.retail.priest.shadow.icyveins','rm.retail.rogue.assassination.icyveins','rm.retail.rogue.outlaw.icyveins',
 'rm.retail.rogue.subtlety.icyveins','rm.retail.shaman.elemental.icyveins','rm.retail.shaman.enhancement.stormbringer',
 'rm.retail.shaman.enhancement.totemic','rm.retail.warlock.affliction.icyveins','rm.retail.warlock.demonology.icyveins',
 'rm.retail.warlock.destruction.icyveins','rm.retail.warlock.destruction.simc','rm.retail.warrior.arms.colossus',
 'rm.retail.warrior.arms.slayer','rm.retail.warrior.fury.slayer','rm.retail.warrior.fury.thane',
 'rm.retail.warrior.protection.icyveins',
 TWIST
];

test('pure catalog exposes every actual source definition without runtime facts',()=>{
 const c=ready(),rows=c.list(),n=raw().packs.length;assert(n>0);assert.equal(rows.length,n);assert.equal(new Set(rows.map(r=>r.id)).size,n);
 const editions=new Map(FAMILIES.map(f=>[f,0]));
 for(const row of rows){const families=row.applicability.get('families');assert.equal(families.size,1,row.id);const family=families.get(1);assert(editions.has(family),row.id+' family '+family);assert(row.id.startsWith('rm.'+family+'.'),row.id);editions.set(family,editions.get(family)+1);assert.equal(row.validation.nativeAvailability,'unverified');for(const k of ['eligible','enabled','runtimeKey','spellName','icon'])assert.equal(Object.hasOwn(row,k),false);const value=c.get(row.id);assert(value.ok&&checkPortable(value.envelope).ok);const report=validateEnvelope(value.envelope,declarations);assert(report.valid&&report.supported&&report.resolved);assert(indexRotationSteps(value.envelope.get('body')).ok);}
 for(const[family,count]of editions)assert(count>0,'no '+family+' premades');
 assert.deepEqual(c.get({toString(){throw Error('no coercion');}}),{ok:false,reason:'unknown-default'});
});
test('production generator is deterministic/current BOTH and source inputs exact',()=>{
 const expected=text();for(const vm of ['lua5.1','luajit'])for(let i=0;i<2;i++)assert.equal(execFileSync(vm,['tools/export_web_defaults.lua'],{cwd:root,encoding:'utf8',maxBuffer:GENERATOR_OUTPUT}),expected);
 const doc=raw();for(const[path,sha]of Object.entries(doc.sourceFiles))assert.equal(createHash('sha256').update(readFileSync(new URL('../'+path,import.meta.url))).digest('hex'),sha,path);
 const toc=readFileSync(new URL('../RotationMaster.toc',import.meta.url),'utf8').split(/\r?\n/).filter(s=>/^Defaults\/.+\.lua$/.test(s)&&!s.startsWith('Defaults/blocks/'));assert.deepEqual([...doc.packs.map(p=>p.sourcePath)].sort(),toc.sort());
});
test('every catalog pack has one pinned actual codec wire decoding to its exact Map with strict diff equality',()=>{
 const fixture=JSON.parse(readFileSync(fixtureURL)),c=ready();assert.equal(fixture.format,'RotationMasterBundledDefaultWireFixtures');assert.deepEqual(fixture.records.map(r=>r.id),c.list().map(r=>r.id));
 let rows=0,expected=0;for(const row of c.list())expected+=indexRotationSteps(c.get(row.id).envelope.get('body')).index.rows.length;for(const record of fixture.records){const decoded=decodeImport(record.wire);assert(decoded.ok&&decoded.kind==='envelope');const selected=c.get(record.id);assert(selected.ok);assert.deepEqual(toTypedTree(decoded.value),record.expected);assert.deepEqual(toTypedTree(selected.envelope),record.expected);assert.equal(selected.source.sha256,record.sourceSHA);rows+=indexRotationSteps(decoded.value.get('body')).index.rows.length;const diff=diffRotations(decoded.value,selected.envelope);assert(diff.valid&&diff.complete&&diff.changes.length===0);}assert(rows>0);assert.equal(rows,expected);
});
test('packaged premades are frozen: ordered ids, catalog objects, wire records and raw fixture bytes',()=>{
 const wire=readFileSync(fixtureURL),records=JSON.parse(wire).records,packs=raw().packs,c=ready();
 assert.deepEqual(packs.map(p=>p.id),PREMADES.map(([id])=>id));assert.deepEqual(records.map(r=>r.id),PREMADES.map(([id])=>id));
 const changed=PREMADES.filter(([id,rows,sha],i)=>indexRotationSteps(c.get(id).envelope.get('body')).index.rows.length!==rows||createHash('sha256').update(JSON.stringify([packs[i],records[i]])).digest('hex')!==sha).map(([id])=>id);
 assert.deepEqual(changed,[]);
 assert.equal(createHash('sha256').update(wire).digest('hex'),FIXTURE_SHA);
});
test('the retired level-bracket packs are gone from the catalog, wires and source list',()=>{
 const doc=raw(),records=JSON.parse(readFileSync(fixtureURL)).records,bracket=/\.starter(\.|$)|\.\d+-\d+$/;
 for(const id of [...doc.packs.map(p=>p.id),...records.map(r=>r.id)])assert(!bracket.test(id),id);
 for(const path of Object.keys(doc.sourceFiles))assert(!/starter/.test(path),path);
 for(const id of ['rm.tbc.shaman.starter','rm.tbc.warlock.starter.40-49','rm.tbc.priest.shadow.50-59'])assert.deepEqual(ready().get(id),{ok:false,reason:'unknown-default'});
});
// Pack-level body.disabled, derived from the data rather than from an id
// list alone. A pack is off as a whole exactly when its own description says
// it is off by default: the TBC seal-twisting premade ("Off by default; enable
// it if you twist seals") and the Retail reference variants, guide and
// SimulationCraft orders that read combat data Midnight hides from addons.
// Each of those is named "... reference ..." and described "Reference only,
// off by default", and no other Retail pack is named a reference. WoW Forever
// ships none. Many packs of every edition carry disabled STEPS (situational
// rows); those are not pack-level. DISABLED lists the set so a change shows.
test('pack-level disabled is exactly the twist premade plus the Retail reference variants, each saying so',()=>{
 const c=ready(),off=/^(Reference only, )?off by default\b/i;
 assert.deepEqual(c.list().filter(r=>c.get(r.id).envelope.get('body').get('disabled')!==undefined).map(r=>r.id),DISABLED);
 for(const row of c.list()){
  const v=c.get(row.id),disabled=v.envelope.get('body').get('disabled'),family=row.applicability.get('families').get(1),{name,description}=v.display;
  assert(disabled===undefined||disabled===true,row.id+' disabled must be absent or true');
  assert.equal(disabled===true,off.test(description),row.id+': body.disabled must match a description that says off by default');
  if(family==='retail'){const reference=/\breference\b/i.test(name);assert.equal(reference,disabled===true,row.id+': Retail references, and only they, are disabled');if(reference)assert(description.startsWith('Reference only, off by default'),row.id);}
  else if(disabled)assert.equal(row.id,TWIST);
  if(disabled){const report=validateEnvelope(v.envelope,declarations);assert(report.valid&&report.supported&&report.resolved,row.id);}
 }
 const twist=c.get(TWIST);assert(twist.ok);assert.equal(twist.envelope.get('body').get('disabled'),true);
});
test('get/list outputs never expose private manifest, facets or declaration state',()=>{
 const c=ready(),first=c.list()[0],before=toTypedTree(c.get(first.id).envelope),one=c.get(first.id);one.envelope.get('body').get('rotation').clear();one.envelope.get('sources').get(1).set('url','poison');one.display.name='poison';one.source.sha256='poison';one.validation.diagnostics?.push('poison');first.applicability.set('class','poison');first.tags?.clear();first.display.name='poison';assert.deepEqual(toTypedTree(c.get(first.id).envelope),before);assert.notEqual(c.list()[0].display.name,'poison');assert.notEqual(c.get(first.id).source.sha256,'poison');
});
test('input is bounded JSON text only, schema failure fixed and no error/source echo',()=>{
 let calls=0;for(const value of [null,{},new String(text()),{toString(){calls++;throw Error('PRIVATE');},toJSON(){calls++;throw Error('PRIVATE');}},'x'.repeat(8388609),'{bad'])assert.deepEqual(parse(value),{ok:false,reason:'invalid-bundled-catalog'});assert.equal(calls,0);assert.deepEqual(parse(text(),'{bad'),{ok:false,reason:'schema-unavailable'});
});
test('closed root/record/display fields, stable identifiers and source hash links',()=>{
 const transforms=[d=>d.extra=true,d=>d.version=2,d=>d.nativeAvailability='ready',d=>d.packs[0].extra=true,d=>d.packs[0].display.extra=true,d=>d.packs[0].id='!',d=>d.packs[0].sourceSHA='0'.repeat(64),d=>d.packs[0].sourcePath='../evil.lua',d=>d.packs[0].display.nameKey='mismatch',d=>d.packs.push(d.packs[0])];for(const change of transforms){const d=raw();change(d);reject(d);}
});
test('typed marker closure, duplicate and rounded key aliases refuse before exposure',()=>{
 const transforms=[m=>m.extra=1,m=>m.type='unknown',m=>m.entries.push(m.entries[0]),m=>m.entries.push([number(1),bytes('x')],[{type:'number',bits:'3ff0000000000000'},bytes('y')]),m=>m.entries.push([number(0),bytes('bad')]),m=>m.entries.push([bytes('future'),{type:'bytes',hex:'xyz'}]),m=>m.entries.push([bytes('future'),{type:'number',bits:'7ff0000000000000'}])];for(const change of transforms){const d=raw();change(d.packs[0].envelope);reject(d);}
});
test('typed numeric and byte keys, null and inert source payload retain exact data',()=>{
 const d=raw(),m=d.packs[0].envelope;set(m,'customPayload',{type:'table',entries:[[number(1),{type:'boolean',value:false}],[bytes('1'),bytes('raw\x00\xff <script>throw 1</script>')],[bytes('nil'),{type:'nil'}]]});const r=parse(JSON.stringify(d));assert(r.ok);const x=r.catalog.get(d.packs[0].id).envelope.get('customPayload');assert.equal(x.get(1),false);assert.equal(x.get('1'),'raw\x00\xff <script>throw 1</script>');assert.equal(x.get('nil'),null);assert.equal(globalThis.pwned,undefined);
});
test('JSON deep unchecked markers and typed depth limits fail without recursion overflow',()=>{
 const d=raw();d.packs[0].envelope.type='DEEP';reject(JSON.stringify(d).replace('"DEEP"','['.repeat(12000)+'0'+']'.repeat(12000)));
 const x=raw();let v={type:'nil'};for(let i=0;i<66;i++)v={type:'table',entries:[[bytes('x'),v]]};set(x.packs[0].envelope,'future',v);reject(x);
});
test('aggregate and per-manifest resource limits remain explicit',()=>{
 let d=raw();d.packs=Array.from({length:257},()=>d.packs[0]);reject(d);
 d=raw();set(d.packs[0].envelope,'future',{type:'bytes',hex:'78'.repeat(262145)});reject(d);
 d=raw();const many={type:'table',entries:Array.from({length:10001},(_,i)=>[number(i+1),{type:'boolean',value:false}])};set(d.packs[0].envelope,'future',many);reject(d);
});
test('future envelope schema, invalid branch and mismatched declared identity fail catalog',()=>{
 for(const mutate of [m=>set(m,'schemaVersion',number(2)),m=>set(m,'id',bytes('other')),m=>{const body=fields(m).get('body');set(body,'rotation',{type:'table',entries:[[number(1),{type:'table',entries:[[bytes('id'),bytes('bad')],[bytes('type'),bytes('branch')],[bytes('onTrue'),{type:'table',entries:[]}]]}]]});}]){const d=raw();mutate(d.packs[0].envelope);reject(d);}
});
test('provenance hashes do not pretend to authenticate arbitrary well-formed payload content',()=>{
 const d=raw(),p=d.packs.find(p=>p.id===SAMPLE),m=p.envelope;const b=fields(m).get('body'),steps=fields(b).get('rotation');const spell=steps.entries.map(x=>x[1]).find(s=>fields(s).get('action'));set(spell,'action',number(123));const r=parse(JSON.stringify(d));assert(r.ok);assert.equal(r.catalog.get(p.id).source.sha256,p.sourceSHA);
});
test('display labels remain Unicode text while symbolic keys stay ASCII bytes',()=>{
 const d=raw();assert(d.packs.some(p=>/[^\x00-\x7f]/.test(p.display.name+p.display.description)),'some packaged display text is non-ASCII');const c=ready();for(const p of d.packs){assert.equal(c.get(p.id).display.name,p.display.name);assert.equal(c.get(p.id).display.description,p.display.description);}
 d.packs[0].display.name='Localized – Δ 😀';assert.equal(parse(JSON.stringify(d)).catalog.list()[0].display.name,'Localized – Δ 😀');
 d.packs[0].display.nameKey='nonASCIIé';set(d.packs[0].envelope,'nameKey',bytes('nonASCIIé'));reject(d);
});
test('record/source maxima and UTF8 text cap are enforced independently',()=>{
 let d=raw();d.packs=[];d.sourceFiles={};for(let i=0;i<512;i++)d.sourceFiles['safe/'+i+'.lua']='0'.repeat(64);assert(parse(JSON.stringify(d)).ok);d.sourceFiles['safe/extra.lua']='0'.repeat(64);reject(d);
 const base=text();assert(parse(base+' '.repeat(8388608-Buffer.byteLength(base))).ok);reject(base+' '.repeat(8388609-Buffer.byteLength(base)));
 reject(base+' '.repeat(8388608-Buffer.byteLength(base)-2)+'éé');
 d=raw();const p=[...d.packs].sort((a,b)=>JSON.stringify(a).length-JSON.stringify(b).length)[0];d.packs=[];// smallest pack, so 257 copies stay under the text cap
 for(let i=0;i<256;i++){const row=structuredClone(p);row.id='test.'+i;row.sourcePath='Defaults/test/'+i+'.lua';set(row.envelope,'id',bytes(row.id));d.sourceFiles[row.sourcePath]=row.sourceSHA;d.packs.push(row);}assert(parse(JSON.stringify(d)).ok);d.packs.push(structuredClone(d.packs[0]));reject(d);
});
test('trusted producer refuses native queries, duplicate registration and invalid declarations BOTH',()=>{
 const scripts=[
  ["local _,a=...; local x=UnitLevel('player')",'unsupported pack global UnitLevel'],
  ["local _,a=...; a:RegisterDefaultRotation({id='bad'})",'invalid-envelope'],
 ];
 for(const vm of ['lua5.1','luajit']){
  for(const [script,reason] of scripts){
   const body="local original=loadfile;local replacement="+JSON.stringify(script)+";loadfile=function(path)if path=='"+SAMPLE_SOURCE+"'then return assert(loadstring(replacement))end;return original(path)end;local m=dofile('tools/export_web_defaults.lua');local ok,why=pcall(m.build);assert(not ok and tostring(why):find("+JSON.stringify(reason)+",1,true),tostring(why))";
   execFileSync(vm,['-e',body],{cwd:root,encoding:'utf8',maxBuffer:4*1024*1024});
  }
  const duplicate="local original=loadfile;local scope,set=setfenv,getfenv;loadfile=function(path)local f=original(path);if path=='"+SAMPLE_SOURCE+"'then return function(...)scope(f,set(1));f(...);f(...)end end;return f end;local m=dofile('tools/export_web_defaults.lua');local ok,why=pcall(m.build);assert(not ok and tostring(why):find('duplicate-default-id',1,true),tostring(why))";
  execFileSync(vm,['-e',duplicate],{cwd:root,encoding:'utf8',maxBuffer:4*1024*1024});
 }
});
test('fresh actual LuaJIT fixture generation stays semantically equal without wire-order claims',()=>{
 const fresh=JSON.parse(execFileSync('luajit',['tools/export_web_defaults.lua','--fixtures'],{cwd:root,encoding:'utf8',maxBuffer:GENERATOR_OUTPUT}));const c=ready();assert.deepEqual(fresh.records.map(r=>r.id),c.list().map(r=>r.id));for(const r of fresh.records){const decoded=decodeImport(r.wire);assert(decoded.ok);assert.deepEqual(toTypedTree(decoded.value),toTypedTree(c.get(r.id).envelope));}
});
