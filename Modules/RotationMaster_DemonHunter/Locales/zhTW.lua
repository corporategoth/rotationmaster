-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.
-- Built In rotation text: each key is the rotation ID plus .Name or .Description.
if GetLocale() ~= "zhTW" then return end
local addon_name = ...
local host = RotationMasterBuiltIns
local L = LibStub("AceLocale-3.0"):GetLocale(host and host.localeName or addon_name:match("^(.-)_[^_]+$") or addon_name)

L["rm.retail.demonhunter.devourer.Name"] = "暴雪戰鬥助手"
L["rm.retail.demonhunter.devourer.Description"] = "推薦噬滅專精使用。醒目提示暴雪戰鬥助手建議的下一個法術，這是在至暗之夜的戰鬥中，遊戲仍允許插件讀取的唯一循環建議；你施法或引導虛無射線時它會等待。同時提醒戰鬥助手留給你處理的部分：戰鬥中一旦就緒就使用的虛無惡魔化身、獵殺追擊與虛無之刃、對可中斷的施法使用干擾，以及戰鬥中只要就緒就使用殘影。敵人的施法在戰鬥中會被隱藏，因此干擾只會在遊戲顯示它們的場合亮起；正式版中生命力是隱藏的，因此何時使用殘影由你決定。"
L["rm.retail.demonhunter.devourer.guide.Name"] = "參考（Icy Veins）"
L["rm.retail.demonhunter.devourer.guide.Description"] = "僅供參考，預設關閉：Icy Veins 的殲滅者優先順序。你大部分的增益效果在至暗之夜的戰鬥中會被隱藏，因此它無法在戰鬥中運作；正式版中狂怒值是隱藏的，因此虛無射線只等待自身的消耗。虛無惡魔化身以外：靈魂驟發觸發時使用吞噬，收割，靈魂獻祭未在燃燒時使用靈魂獻祭，虛無惡魔化身就緒後使用虛無之刃與獵殺追擊，虛無惡魔化身，飢渴斬擊，虛無射線，吞噬。虛無惡魔化身期間：靈魂驟發觸發時使用吞滅，虛無射線，若你有虛無之痕的打擊技能就使用它們，崩陷之星，天擇，吞滅，靈魂獻祭。Rotation Master 無法計算靈魂碎片的數量，因此收割與天擇冷卻結束就使用。提醒：干擾與殘影。"
L["rm.retail.demonhunter.devourer.simc.Name"] = "參考（SimulationCraft）"
L["rm.retail.demonhunter.devourer.simc.Description"] = "僅供參考，預設關閉：SimulationCraft 的殲滅者清單，虛無惡魔化身一就緒就進入。由於戰鬥資料被隱藏，它無法在至暗之夜的戰鬥中運作。變身以外：敵人不超過三個且虛無惡魔化身已蓄滿時，搭配噬滅之咬使用虛無之刃，虛無惡魔化身，靈魂驟發觸發時使用吞噬，收割，虛無射線，對成群敵人使用靈魂獻祭，吞噬。變身期間：單一目標時靈魂驟發觸發則使用吞滅，搭配噬滅之咬使用獵殺追擊與虛無之刃，對成群敵人使用虛無射線，崩陷之星，天擇，虛無射線，靈魂獻祭，吞滅。提醒：干擾與殘影。"
L["rm.retail.demonhunter.havoc.Name"] = "暴雪戰鬥助手"
L["rm.retail.demonhunter.havoc.Description"] = "推薦災虐專精使用。醒目提示暴雪戰鬥助手建議的下一個法術，這是在至暗之夜的戰鬥中，遊戲仍允許插件讀取的唯一循環建議；你施法或引導時它會等待。同時提醒遊戲助手留給你處理的部分：戰鬥中的惡魔化身與獵殺追擊、擁有慣性或能量全開時使用蠻恨撤離、對可中斷的施法使用干擾，以及戰鬥中只要就緒就使用殘影。敵人的施法在戰鬥中會被隱藏，因此干擾只會在遊戲顯示它們的場合亮起；正式版中生命力是隱藏的，因此何時使用殘影由你決定。移動、黑暗與飾品由你自行處理。"
L["rm.retail.demonhunter.havoc.guide.Name"] = "參考（Icy Veins、SimulationCraft 與 Wowhead）"
L["rm.retail.demonhunter.havoc.guide.Description"] = "僅供參考，預設關閉：指南中的災虐優先順序。在至暗之夜的戰鬥中，你的觸發效果、惡魔化身與精華破斬都對插件隱藏，因此這份清單無法在戰鬥中運作；可以閱讀它，或複製後自行實驗。正式版中狂怒值是隱藏的，因此魔刃不會等待空間。奧達奇劫奪者：撕裂打擊與戰刃亂舞都未生效時使用斬掠戰刃，撕裂打擊生效時使用混沌之擊。魔痕：惡魔化身期間使用精華破斬、劍刃之舞與混沌之擊。接著在精華破斬期間使用劍刃之舞與混沌之擊，兩層充能時使用獻祭光環，魔眼光束，使用魔刃觸發慣性，魔眼光束還有 4 秒以上才就緒時使用精華破斬，劍刃之舞，面對兩個敵人時使用獻祭光環，混沌之擊，魔刃，獻祭光環，投擲戰刃，魔化衝刺。提醒：魔眼光束與劍刃之舞都用完後使用惡魔化身、獵殺追擊、蠻恨撤離，以及干擾與殘影。"
L["rm.retail.demonhunter.initial.Name"] = "暴雪戰鬥助手"
L["rm.retail.demonhunter.initial.Description"] = "在你選擇專精之前推薦使用（此時遊戲回報的是惡魔獵人的初始專精）。醒目提示暴雪戰鬥助手建議的下一個法術，這是在至暗之夜的戰鬥中，遊戲仍允許插件讀取的唯一循環建議；你施法或引導時它會等待。同時附上每個惡魔獵人內建循環共用的提醒，各項在你學會對應法術後才會出現。當你在 10 級選擇專精後，該專精的內建循環會接手。"
L["rm.retail.demonhunter.vengeance.Name"] = "暴雪戰鬥助手"
L["rm.retail.demonhunter.vengeance.Description"] = "推薦復仇專精使用。醒目提示暴雪戰鬥助手建議的下一個法術，這是在至暗之夜的戰鬥中，遊戲仍允許插件讀取的唯一循環建議；你施法或引導時它會等待。同時提醒戰鬥助手留給你處理的部分：戰鬥中一旦就緒就使用的惡魔尖刺、熾炎烙印、魔化破滅與惡魔化身、對可中斷的施法使用干擾，以及戰鬥中只要就緒就使用殘影。敵人的施法在戰鬥中會被隱藏，因此干擾只會在遊戲顯示它們的場合亮起；正式版中生命力是隱藏的，因此何時使用殘影由你決定。煉獄轟擊、黑暗、嘲諷與飾品由你自行處理。"
L["rm.retail.demonhunter.vengeance.guide.Name"] = "參考（Wowhead 與 Icy Veins）"
L["rm.retail.demonhunter.vengeance.guide.Description"] = "僅供參考，預設關閉：Wowhead 的復仇施放順序，並採用 Icy Veins 的英雄天賦目標。你的增益效果在至暗之夜的戰鬥中會被隱藏，因此它無法在戰鬥中運作；正式版中狂怒值是隱藏的，因此消耗技能只等待自身的消耗，累積技能也不會避免溢出。奧達奇劫奪者：斬掠戰刃，撕裂打擊生效時使用切裂，戰刃亂舞生效時使用破魂斬。接著充能已滿時使用切裂，三個以上敵人時使用靈魂炸彈，獻祭光環，火焰符印，單一目標時使用破魂斬，魔化破滅，破魂斬，切裂，魔刃，投擲戰刃。Rotation Master 無法計算靈魂碎片的數量，因此靈魂炸彈依敵人數量判斷。提醒：惡魔尖刺未生效時使用惡魔尖刺、惡魔化身、熾炎烙印、忿恨符印、靈魂屠夫（兩層充能時的煉獄轟擊提醒為關閉狀態），以及干擾與殘影。"
L["rm.retail.demonhunter.vengeance.simc.Name"] = "參考（SimulationCraft）"
L["rm.retail.demonhunter.vengeance.simc.Description"] = "僅供參考，預設關閉：SimulationCraft 的復仇清單。由於戰鬥資料被隱藏，它無法在至暗之夜的戰鬥中運作，而且正式版中狂怒值是隱藏的，因此其狂怒值門檻未納入。奧達奇劫奪者：先使用火焰符印與獻祭光環，惡魔化身，搭配魔刃的斬掠戰刃循環，熾炎烙印，忿恨符印，對成群敵人使用靈魂炸彈，熾炎焚身期間使用靈魂屠夫，然後是切裂、破魂斬、魔刃、魔化破滅。殲滅者：虛墜就緒時以靈魂炸彈或破魂斬消耗它，虛墜達到兩層時使用切裂，惡魔化身，靈魂炸彈，忿恨符印，充能已滿時使用切裂，獻祭光環，火焰符印，切裂，破魂斬，魔刃，投擲戰刃。提醒：惡魔尖刺、干擾、殘影。"
