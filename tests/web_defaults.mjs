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
const SAMPLE='rm.tbc.shaman.enhancement.icyveins',SAMPLE_SOURCE='Modules/RotationMaster_Shaman/tbc/shaman-enhancement-icyveins.lua';
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
// (Moving the packs into load-on-demand modules re-froze every digest: only each
// sourcePath changed, Defaults/<edition>/ to Modules/RotationMaster_<Class>/<edition>/.)
const PREMADES=[
 ["rm.forever.druid.balance",28,"ef5d2da8123a81e13ba78ff8c1754934ae10584d60860f53038fb2e89b42e531"],
 ["rm.forever.druid.balance.tavern",14,"bc9e74c84e27e6fe3950fc3fb1e5436dae8f0ba6e846e6de36d466b9aa68cfb2"],
 ["rm.forever.druid.feral",44,"f4e5d3e0eeb2cbe5576bc3831a653fb667793619e24eee18adbfb996bd43de97"],
 ["rm.forever.druid.restoration",23,"097addfbe201e6a37f051f2ba8216b745589f39905ca464fc9d3aa857763e562"],
 ["rm.forever.druid.restoration.icyveins",23,"85b14bd523a226b407e8ecce4d1baf722b8459b8331a3c11df22f2ec58cb985b"],
 ["rm.forever.hunter.ranged",45,"4ba3dc2f17e82092018873df16c1f1aefaae786afaac0eab708ab9dacf95512a"],
 ["rm.forever.hunter.ranged.mobalytics",40,"06f2125d5384f82727bec04fc9c9624bb9a4aedba684bbbb19448d77ca50fcfa"],
 ["rm.forever.hunter.survival",30,"6aaf5b313359de05a3f099cb35527b21c38231c6b13590722e2ccb8e3c232e2a"],
 ["rm.forever.hunter.survival.weave",31,"a9275ef1761d235b96576489239eed358cf851c84e191fbaed5d3a3300e4ef10"],
 ["rm.forever.mage.arcane",38,"67969e57a0f2d2a9202b68110ae06f29e93e4452150126236e6f9ea9b4fec24c"],
 ["rm.forever.mage.fire",40,"abc30fbda717d5e5591643db0519b825d8f4926e7a60692364c1241287531a50"],
 ["rm.forever.mage.fire.icyveins",32,"3f0e39a2403fb2465410451fe6a2c969437c08d329f69978f56ae7c322a99a03"],
 ["rm.forever.mage.frost",42,"c815c1ab062f61b69f05c4d9c02487da94b7411f010646ee355147d18c62c156"],
 ["rm.forever.paladin.holy",28,"453537441ec0d9b72bed002f5043aeb7e1ee43a3be7dfbbf0194f28e8d82fa63"],
 ["rm.forever.paladin.holy.wowhead",26,"be82f39b484b4867b79721bfe6476c8a09d039a93d64e9bdc2c1436a97fb07de"],
 ["rm.forever.paladin.protection",24,"8d6bb2eb18c7fd26fd42c136152eb466e92436f80717e4ecc497651475500f2a"],
 ["rm.forever.paladin.protection.icyveins",18,"afca11055b8c813d0554af527f52751b97406c8238ec591a0ed1603869b618ee"],
 ["rm.forever.paladin.retribution",30,"b13c1bfc1925c346d4b0ecb35cf9093f59a53ef3ce57da4a0c283e57e54bb948"],
 ["rm.forever.priest.dps",60,"7a318c2c4c179a497affd867d2cd883974d78054fdd62abb4556673f145666b1"],
 ["rm.forever.priest.dps.mobalytics",44,"04603b72662d09011b58f452b8af31ef50e79c656b3d320bd492085ee45f1b0a"],
 ["rm.forever.priest.healer",45,"2c53d440b58715c8a9843f6e42aaaabd56524f1f89cd18fe6a11c04516a35ed6"],
 ["rm.forever.rogue.dps",39,"57fa333e94c3b99d1edcb91d2ec77af7c8f7beac73acb42c11071c73eee2b278"],
 ["rm.forever.rogue.subtlety.warcrafttavern",30,"a65707b063b490d36be8219e7a2e340fde0df37a3739e84ced3d6cfd9b75a663"],
 ["rm.forever.rogue.subtlety.wowhead",29,"036dea70ef37d3dd19c6739305ab0b9fe3fa176dedb2842bc5889efbbdc99367"],
 ["rm.forever.shaman.elemental",35,"8f1f5c033fdefeba68d30829b27e361d15f9b860cbb9dba6007e2d17e256128f"],
 ["rm.forever.shaman.enhancement",30,"b3fbbbdada1bac7d06ce3d01e784027a5954e0340661c7d1654737fb0c3f2027"],
 ["rm.forever.shaman.enhancement.wowhead",17,"bbaeb8223aad48b361dd96106f37ac5a52801ac6073c655cbd1d321be6d8e9e7"],
 ["rm.forever.shaman.restoration",27,"776279aed81e79a0370cf882181c746d4628c1a2ee36de4ec317cd00c7152719"],
 ["rm.forever.warlock.dps",64,"1837df4d04addda1c4da13808e964961d04fcf67a53a0b169fb5b03a93c4b6f6"],
 ["rm.forever.warlock.dps.icyveins",67,"ab12cf657b3cc7daa6a380932dda0d3b79113f599fabf0d9e30edab0e07e15cd"],
 ["rm.forever.warlock.dps.wowhead",57,"67de52e44827ce25269d150c6e6fbfff4111dc3527c4be7b2c8466ad7cc3ddc9"],
 ["rm.forever.warrior.dps",36,"4c712295ad3393bc73c6e1a26a7bbb9d073672ffecf9c9edd2a01e7496c64a0b"],
 ["rm.forever.warrior.dps.warcrafttavern",23,"5d8e1f37ea612ad63779aa53195a25bada601d7c795103311b67715d7e42dd3e"],
 ["rm.forever.warrior.protection",31,"9ad072dacdc85edae67f92f253f6388dc7174e37336db903dae54895cd570a78"],
 ["rm.forever.warrior.protection.warcrafttavern",17,"0fdb37a29e49807897cf6a9f312b550bd8e17e122e01f5a78064c3e74dc70383"],
 ["rm.retail.deathknight.blood",11,"f5eb5ed4bd9b3d379c08ca0fb996678dece2d9049308ceb2d359284b208e00b5"],
 ["rm.retail.deathknight.blood.guide",30,"730efd56e28d105ef57447d6a7344e086e1e05be325dca0118747329cc80d267"],
 ["rm.retail.deathknight.blood.simc",26,"3a1f56a7ef01ff3a9c1e31ecda4e49f65b48c59e0109e181d3b293afc67df38d"],
 ["rm.retail.deathknight.frost",11,"eebd5631b77b9e8635a23efdb9ce9fb1f377c5c621ccffc04260915aa6ff6803"],
 ["rm.retail.deathknight.frost.guide",33,"d72f5a21d8daed5e80b88252bc994a1bbfc8baf99c677e53757b5bd70a53f03d"],
 ["rm.retail.deathknight.frost.wowhead",34,"d3e85073c0e171991210e441515ff321ca890fd1fbd43e90402caeecfe88cce1"],
 ["rm.retail.deathknight.unholy",9,"7c71bb23f323b18371597b4507ce53ff12c09aeed6f8b5b5e4ca836eb641b294"],
 ["rm.retail.deathknight.unholy.guide",21,"44e7a64ddaec5b341488e71c8f9ee547208a4063e6cfcf0ed10d866cf689684c"],
 ["rm.retail.deathknight.unholy.simc",30,"5bf03a43d264a7cead44271dd4b53c1e183c796f1fddb5194b9eaf3274159aa9"],
 ["rm.retail.demonhunter.devourer",8,"0111999798dc04c13518713268f626877eb353bf9b22c6e82fb2c2b1bc10add7"],
 ["rm.retail.demonhunter.devourer.guide",23,"7889d447eaf78844578d6b2a2080cca23cebbb1bb8f61f3a86a8098537e45c69"],
 ["rm.retail.demonhunter.devourer.simc",21,"0c267cbd996c7c688965c1d9806fb4a0699c11bdc0f2af21f8a93bcddc2ee0b2"],
 ["rm.retail.demonhunter.havoc",8,"09977850ec3c2932d410737428d0610132900708114a6643c9c8a77c72a3e04c"],
 ["rm.retail.demonhunter.havoc.guide",24,"20795a542087337e7cc668b9b54fb4ab6c09e530d8efafdad82a655847e08e17"],
 ["rm.retail.demonhunter.vengeance",9,"21101ba492f19b9f173abdeaa83d25082f6ad0996b938f45276f380fbe7b2179"],
 ["rm.retail.demonhunter.vengeance.guide",24,"e263f24f4cf7a686560053793d638298e2bf46b017551ae4c28db9184c885925"],
 ["rm.retail.demonhunter.vengeance.simc",36,"4fc636c15211b04da7326449b9c972fbb1dc8386b185d4c7a7a5ad622cd8c846"],
 ["rm.retail.druid.balance",11,"8f8815600dd980e81928e21b796bc0cdb27a919c2ef4e667f8e0d6e692139ad5"],
 ["rm.retail.druid.balance.guide",29,"1d2a9fca64ad04a25b8b0b7ea35b5d0ec8ec7dd46a83ef4becd1e6bd29e55485"],
 ["rm.retail.druid.feral",12,"0ccdfb738826f568c376c4f2b16047aebc881368b6685d28e4c579339543bdd7"],
 ["rm.retail.druid.feral.guide",30,"a0c4a16c5b240f37e03cd6192f32209e7287619eb1fd3d553427abc470f183f2"],
 ["rm.retail.druid.guardian",15,"a0ea762f9af1995bca919477950a6e41a7d23fc0a4bce2868c4a4c06ba9bc183"],
 ["rm.retail.druid.guardian.guide",24,"de1fc45adb54e078ad2102a51a25132514ed3b39e83674a9f5d90e8209a7b91c"],
 ["rm.retail.druid.guardian.simc",25,"cd01355289001cba67476b139d0aa247f100db124083957e1331e14690881ef2"],
 ["rm.retail.druid.restoration",15,"4abbbfd891d53c1a75857e6061399565477324b089ab4c5a46c0e1070b253cc5"],
 ["rm.retail.evoker.augmentation",22,"134ae108d374813455cd55d3c9b8831f6ecff6b237cee1a5e80decc3c3fa82ad"],
 ["rm.retail.evoker.augmentation.assisted",11,"de8617bad98e741bc4deb31c4c1666a6b4e019531231450de2b1ca2d9fa1d606"],
 ["rm.retail.evoker.devastation",10,"8f268df0273d35d280f73fddcd5ba66866f5a88c9f57b14806b30ef5ea304f3f"],
 ["rm.retail.evoker.devastation.guide",33,"3c6b2cf7853c83901b65f8924b017cee15798e78bb6e315cf199fdc8f825a038"],
 ["rm.retail.evoker.preservation",12,"6b18e5bf2947cf1dba683bff7adcbcb0890dfd26b24ca55682e23a03608c6d20"],
 ["rm.retail.hunter.beastmastery",13,"a7a4b288df63374c26f50308b46865dee03afa6955c18088c28e00602918a469"],
 ["rm.retail.hunter.beastmastery.guide",44,"07494df2122c18cd750f2a9fe0b5c9a094ec40d7f401c537f61ddbe34c0fb2ba"],
 ["rm.retail.hunter.marksmanship",13,"3a44401b49cb0f95ac0a5507e38d5145447d06a922dc683004044a855aaebbd0"],
 ["rm.retail.hunter.marksmanship.guide",52,"2a657a5a022ef191e020759caa823c2e8e590314029f2f54cceb965e0444f80a"],
 ["rm.retail.hunter.survival",13,"276d6b48c2ca325411e4a8480208696c0d5111a08eb13a47290367d2944a0eaf"],
 ["rm.retail.hunter.survival.guide",45,"dd4169346191a533d883dea96d70e09520e4c52fc4f91cfbf1428ffe3c891748"],
 ["rm.retail.mage.arcane",12,"4dfddce024b84153a3851599c25d76f954aa3fa30de724e0873bde2c84f05111"],
 ["rm.retail.mage.arcane.guide",33,"3bc6edc48385e2086db1a80aef40dfdf841f39aa00f53fabc06a38036405fdda"],
 ["rm.retail.mage.fire",12,"23136baef4b31045eef975a4c8802cdf924dac74c1adf7777d4bc7d6150b3714"],
 ["rm.retail.mage.fire.guide",34,"27868ab42f7ea86eec00734f6724c423b00a0907e45795d4415dd172eaad0be7"],
 ["rm.retail.mage.frost",12,"7a9b614f17ace02b76d44ab7065293394aa72aa18a328f9874c00ed258952abe"],
 ["rm.retail.mage.frost.guide",47,"244d7be36047467c01aed70d184336447a532419c97673fa70c425a7012c91bc"],
 ["rm.retail.monk.brewmaster",15,"eb1b8e71aa02f8e5962ae071c826bba49e01a0319d806807d2210842b6688cc1"],
 ["rm.retail.monk.brewmaster.guide",31,"378a51a366ae18ece8aee0fe9074c22752ec2f9830d1d70430ca4371c644a720"],
 ["rm.retail.monk.mistweaver",12,"df4a9dffb0a295f4f56b03b868b4181f69f14bb3b729173f65c58ffc94d7fc4e"],
 ["rm.retail.monk.windwalker",13,"06fb686a498413940cb870db639f4fa80fe20c43b9b9f7c45130c77c932de173"],
 ["rm.retail.monk.windwalker.guide",30,"adfe35bb27a745f642c8330d159df8ade799c79a04c11becfb234e69767f4757"],
 ["rm.retail.paladin.holy",24,"53861798f830d8285425834ac6081e5fe1b370569242fd4258409db1f2d5f528"],
 ["rm.retail.paladin.protection",8,"eb941dae3e4237de5d717fa23462c360b40aab3247ebd2ae19e411e44b4bfaa0"],
 ["rm.retail.paladin.protection.icyveins",26,"d22ec28381953b44766027366c12e657c4a5ee8d6bcab158c9fb435685b52d9e"],
 ["rm.retail.paladin.protection.wowhead",19,"a4a30c48e9a496cc35e8c6d016597db8fc161b9f44990b54ecc88e2a77383e75"],
 ["rm.retail.paladin.retribution",7,"34d5d59ede78a33599123f1bb7bdc88ada5f7131b338d4123bccf8abae05699a"],
 ["rm.retail.paladin.retribution.icyveins",24,"345adb9288872dc4ee5b4ceaffd024b2bf8f96bf887b746ba4d02d8bedb24591"],
 ["rm.retail.priest.discipline",23,"0bd5532d4d4babd903496f04b9ad4653d5d737f4e007d8fa5a6fa2b3268b957c"],
 ["rm.retail.priest.discipline.wowhead",19,"8549afea95efe1e41afbf221be94df6a3dc838037bb5f65806eb52c18b57e763"],
 ["rm.retail.priest.holy",25,"0d822baeff3499cd250c98895015e50fe5875a05e8815afa211d27e60f4b0a15"],
 ["rm.retail.priest.shadow",8,"b6c6ce2b1e3008e6d97d1d7c20ebd0fdbcff39e3e9e740bcb16830e979a0166d"],
 ["rm.retail.priest.shadow.icyveins",30,"f99034409ed4a16bcc247a9e2be86e522f678fb1777e6385b68c1f303885ed60"],
 ["rm.retail.rogue.assassination",10,"69bae7e61df7c69c282aa9bf50d5730241bffef90fb5fd54f77c97ca40e2d54c"],
 ["rm.retail.rogue.assassination.icyveins",26,"ad1826d8a49180d6d2ed1488d0f362e6a3afb8ec032c57ab970e4331f6fd8048"],
 ["rm.retail.rogue.outlaw",10,"7449da7a1d961984ef7824417de527e1dc2b19e9f65a47f99afd8c1c06dcf80b"],
 ["rm.retail.rogue.outlaw.icyveins",25,"1ff7f64eaf644e3147068ce42c0c8471c050e74a393b08d212a92cbc950be810"],
 ["rm.retail.rogue.subtlety",9,"d21d6b50842ea9ea4b7674fb234bd3ab7392a92b3d960f457c2d090fe3997240"],
 ["rm.retail.rogue.subtlety.icyveins",25,"6fe48e03b88d5d71a08a6b696c1497b5f60d51b3513301ff2389b7aaeab34971"],
 ["rm.retail.shaman.elemental",12,"9d5cf7b89ea509a962c364e1b3f5b5f47d8f005f368ae6691ec4aebdd9b20c89"],
 ["rm.retail.shaman.elemental.icyveins",40,"eb4103e1de59c21bfe13626a430a51d3b8187b9e9422d83ed350da65d9c8fb28"],
 ["rm.retail.shaman.enhancement",10,"30282f3a139cbcbae8fe0b2eb68c64da2d134a9bd6bf125e1cb30d71c71d4820"],
 ["rm.retail.shaman.enhancement.stormbringer",34,"a5af4e9a74f9944ce658db629df6c42fe27a0da75bfacbc5d5beef766e62f569"],
 ["rm.retail.shaman.enhancement.totemic",28,"5c690b42fe32579654ef91b300385fbb0f60fc2db481e2885f5de7be3bf609d1"],
 ["rm.retail.shaman.restoration",22,"38b042023df24318789367af92acb2969091e9c0864565568d4dfb6c25de0fee"],
 ["rm.retail.warlock.affliction",8,"8685c5e864aa11075e72dc2e491cf55d64ad215ba4166459185668cad78036e4"],
 ["rm.retail.warlock.affliction.icyveins",23,"f6e6de31f3f2a9833791c5d1d084537aa8c3b603e16a10ae44662f3db2d0094f"],
 ["rm.retail.warlock.demonology",11,"1129ce4ed4404d22ed71aafb55e10404a52a383ce3df9dc2220c91d4286dfb1f"],
 ["rm.retail.warlock.demonology.icyveins",23,"6d8d4f21d96b904d5860c58287f2ce70802c7d685d8b3bdbdefb36bbe1dd74c4"],
 ["rm.retail.warlock.destruction",8,"bfe2e40f1b8c13b873ef5dceb745dcfaf3dcf43a6d539966124d6832a449e566"],
 ["rm.retail.warlock.destruction.icyveins",20,"b2317c59df79e79f6fadf8ea4bde4d09a858b274a0b6fd6e260d3e2cbdfca4a4"],
 ["rm.retail.warlock.destruction.simc",25,"0864d535a126035963ebf56587aca85bd57213b15aeddf442ea846114d9e4589"],
 ["rm.retail.warrior.arms",9,"a4d019ffc685f48a0c4c24ad0d15d6353a8c8d5a3b0bf4de7415c12497356ff5"],
 ["rm.retail.warrior.arms.colossus",24,"4e93b117474934a1bd2f34ee29f954384fc9f825186cc90863c3dae4c1aa9660"],
 ["rm.retail.warrior.arms.slayer",22,"77b70b1580db46fc464d43c5608f3d4bb0f8170ab2838aa68efcbb0107827ae9"],
 ["rm.retail.warrior.fury",9,"d110f67dfa5e0b776d57f98c449a79040ee7f210fc2a52a0cfb659bcb6f4fd5d"],
 ["rm.retail.warrior.fury.slayer",26,"a31e2a6611af7ea80f31e7a32f36c6dd171d447889197c6720c3c9b1cf12e4ae"],
 ["rm.retail.warrior.fury.thane",26,"e47f5b19a4b273efcd2335f186a7b87b67fcc1f99744a77b0eed939d9fc71e4c"],
 ["rm.retail.warrior.protection",13,"295e29216fafe04aef37fedeb3856103014fa6ceca4811599fb0cf0e1f4589c0"],
 ["rm.retail.warrior.protection.icyveins",24,"3f21667d575824399202a7ab834243a9ed5c4026bd2682d90d62eb359e18f9af"],
 ["rm.tbc.druid.balance",25,"6e7d47f87f459e83319e692430d070d5604c7a389d524cad11ad4d8f1ac8ec0e"],
 ["rm.tbc.druid.feral.icyveins",44,"a908f85161a93839cb39b10839cb9d7c74f9641056951b9158db6ba9faeb6511"],
 ["rm.tbc.druid.feral.wowhead",44,"b00fa7889e67b55c2c6e1a90d15bf9a01db30f5d180ca303daa5d3a2632cd257"],
 ["rm.tbc.druid.restoration",25,"6f328dd95c140916b98fae8ad5d07855cb2c25fc52e40f8452991016e6c425ea"],
 ["rm.tbc.hunter.ranged.wowhead",40,"50c086b4ac64dccff491efa4830d51101394420b26717f0150ba511b738f45f8"],
 ["rm.tbc.hunter.ranged.wowsims",44,"e29910d2c01d84921809e67c72351fdff8804997c661225589d0baa37fd152ab"],
 ["rm.tbc.mage.arcane",43,"1d797dbdb38dd81406ce7ca2a4b0115fa0faf0fdde1e5be6ed4f1a6b023ad8e6"],
 ["rm.tbc.mage.fire.icyveins",39,"0bed323ce4a68b9e2c688fcbd50e775390533660785986036beb18512b4143a5"],
 ["rm.tbc.mage.fire.wowhead",39,"df5d0605fe8ca378cdb0e2314d90846c32fb85bbfee8de1975a013f6dc742036"],
 ["rm.tbc.mage.frost",43,"799b9213395bc766245bd506f6be5c41bea9037972421c3e84ee419b71961d1d"],
 ["rm.tbc.paladin.holy",19,"9c201d8158a61112773da4ae75bf206fa6ac31f9de9f13490e00f6000cbcd9e2"],
 ["rm.tbc.paladin.holy.wowhead",18,"b8f571dc6f9bb1e67ba451adbb80d970895df63b49f1a2b305334d68e5fec1a8"],
 ["rm.tbc.paladin.protection.icyveins",19,"6f02a19551a11bc792e82b2fafa8a5a1d2bd08fb7b553e298557d92f00b6fb4f"],
 ["rm.tbc.paladin.protection.wowhead",26,"ea1c3bb4c936d38192e3ffb8a0f24d0a8acb26ae5a897308c40dd4ab2b873be1"],
 ["rm.tbc.paladin.retribution.icyveins",24,"11244c2f0e45819dbbeece6c084be1fbc5871a5ffe5a5bf73e0ceaa7133966ef"],
 ["rm.tbc.paladin.retribution.twist",32,"e093b0efb3fbfb52a5809470c001ab3289276a2572176abc5b3bd1b500315257"],
 ["rm.tbc.paladin.retribution.wowhead",23,"6a385f45d82f7a404207a3ce1c01c52c295b8a466bec1d61a04505f3f78f4216"],
 ["rm.tbc.priest.dps.icyveins",49,"8e84810ffd943f912e1aac646c5620df5c406807334e8d10318206986f25f54b"],
 ["rm.tbc.priest.dps.wowhead",46,"d815ac648d654e3406584714d5fec7c79ed438c23731df9f8f0a90be50bebbf5"],
 ["rm.tbc.priest.healer.icyveins",35,"271f0d1b98253e02b6ddb7e192a8e23c1f201ed2ae553a81f0b6571c35415c5b"],
 ["rm.tbc.priest.healer.wowhead",40,"bf5c87c9f4095828e0a8f6de2d677b9df69b8cf1d883546f64d675a409cdeac2"],
 ["rm.tbc.rogue.dps.wowhead",30,"078d680791c3afb063c2866c594e7750104ce107e787a851c2c79ddf8e491579"],
 ["rm.tbc.rogue.dps.wowsims",32,"e9cfc2f7a9f4145484d5ad55384d03e4d629a7c1ccee5dfb41c77220d94033a5"],
 ["rm.tbc.shaman.elemental.icyveins",26,"ae98bdc920019b6c3e633e10a598ab29345d4bb361fab8718fbf0e0e16212d1b"],
 ["rm.tbc.shaman.elemental.nextaction",14,"ff96873aba2c8b23da523d5d4d140820f76d27a2ba6ed7014eff6db1c169b390"],
 ["rm.tbc.shaman.elemental.wowhead",26,"5a5757b8260f06d894ce0ab74d34ac66997381ed2b155a4c690593fd39a2eaf5"],
 ["rm.tbc.shaman.enhancement.icyveins",31,"c177e18dc9a209d5d0461b1e579e96a1c387f51bd6f3832b8d87751f357b9309"],
 ["rm.tbc.shaman.enhancement.wowsims",31,"a5c8c58d7a038c16d55bb176365f16031ca1dbd34b1cb6cc86dbd4ac38f7106b"],
 ["rm.tbc.shaman.restoration",24,"8d34a4fd6c1cc206ba8447b322227b02c08f0d324d6000f0c54498fbc5c2ff13"],
 ["rm.tbc.warlock.dps.icyveins",59,"fa8977aa4d69c3dbbdbec79803d21e36d6a138aa292fbc3eeec49a139881db8e"],
 ["rm.tbc.warlock.dps.wowhead",56,"0ba03e03665ff745ca7bb032c9e720b4dd8379a54290ba1bd93fa0f02fd76cf1"],
 ["rm.tbc.warrior.dps.icyveins",32,"5ca649775112a1e67445de5b9b9f2da56c4f9f7b801a7ac8c5706c1883075da2"],
 ["rm.tbc.warrior.dps.wowsims",34,"570f957ce9a393061b9795042f3c22c21f8b30d09a8cb3062f1fc9f365076426"],
 ["rm.tbc.warrior.protection.icyveins",22,"b61ad78a77cc3b3224e3ea1acd58e52d8f8a559e8ed2d72bb7a4d8e5742c0a1f"],
 ["rm.tbc.warrior.protection.wowhead",24,"24bc08a8f0a1c82a58209edf31cb7b832a4dbfee41fc0a54d51b537354a97c28"]
];
const FAMILIES=['forever','retail','tbc'];
const FIXTURE_SHA='8931f62ade424dc3d70e536b7f73111e275dcb3fd27e49d339762b0a39a47ae0';
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
 // Every pack file the Built In modules' flavour TOCs list, once (Forever's _Camelot and
 // _Forever TOCs are identical; bind.lua and blocks.lua register no pack).
 const tocs=Object.keys(doc.sourceFiles).filter(p=>/^Modules\/[^/]+\/[^/]+\.toc$/.test(p));assert(tocs.length>0);
 const listed=[...new Set(tocs.flatMap(toc=>readFileSync(new URL('../'+toc,import.meta.url),'utf8').split(/\r?\n/).filter(s=>/^[^#].*\.lua$/.test(s)&&s!=='bind.lua'&&!s.endsWith('/blocks.lua')).map(s=>toc.replace(/[^/]+$/,'')+s)))];
 assert.deepEqual([...doc.packs.map(p=>p.sourcePath)].sort(),listed.sort());
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
 d=raw();const p=[...d.packs].sort((a,b)=>JSON.stringify(a).length-JSON.stringify(b).length)[0];d.packs=[];d.sourceFiles={};// smallest pack, so 257 copies stay under the text cap; only their sources, so the 512-source cap is not what rejects
 for(let i=0;i<256;i++){const row=structuredClone(p);row.id='test.'+i;row.sourcePath='Modules/test/'+i+'.lua';set(row.envelope,'id',bytes(row.id));d.sourceFiles[row.sourcePath]=row.sourceSHA;d.packs.push(row);}assert(parse(JSON.stringify(d)).ok);d.packs.push(structuredClone(d.packs[0]));reject(d);
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
