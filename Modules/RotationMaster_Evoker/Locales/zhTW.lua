-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.
-- Built In rotation text: each key is the rotation ID plus .Name or .Description.
if GetLocale() ~= "zhTW" then return end
local addon_name = ...
local host = RotationMasterBuiltIns
local L = LibStub("AceLocale-3.0"):GetLocale(host and host.localeName or addon_name:match("^(.-)_[^_]+$") or addon_name)

L["rm.retail.evoker.augmentation.Name"] = "Icy Veins"
L["rm.retail.evoker.augmentation.Description"] = "推薦強化專精使用：Icy Veins 的黯黑力量優先順序。黯黑力量是至暗之夜戰鬥中遊戲仍向插件顯示的少數增益效果之一，因此在戰鬥中也能維持它。脫戰時：對沒有極熾鱗片的友方隊伍目標施放極熾鱗片，對敵人使用生命烈焰。接著黯黑力量消失或剩餘不到 4 秒時使用黯黑力量，除非亙古吐息已就緒，否則冷卻結束就使用；先見；火焰之息；地裂崩引；黯黑力量期間或有兩層龍能爆發時使用爆發；蒼藍打擊；生命烈焰。被隱藏的增益效果在戰鬥中只會跳過各自的步驟。提醒：亙古吐息與深層吐息（由你瞄準）、火焰之息就緒時使用攪亂均勢、火焰之息與地裂崩引都在冷卻時使用時間跳躍，以及功能性提醒。先見與極熾鱗片會施放在你的目標上：要選擇哪位盟友以及蓄力等級都由你決定。"
L["rm.retail.evoker.augmentation.assisted.Name"] = "暴雪戰鬥助手"
L["rm.retail.evoker.augmentation.assisted.Description"] = "暴雪戰鬥助手對增幅的建議，作為推薦的 Icy Veins 增幅內建循環的替代，預設為停用：啟用它並停用那個，或提高它的優先順序。它只會在黯黑力量消失後才重新施放，並在你施法或按住蓄力法術時等待。戰鬥中提醒亙古吐息、深層吐息、攪亂均勢與時間跳躍，以及與其他喚能師內建循環相同的壓制、黑曜鱗片、青銅龍的祝福與魔力之源。"
L["rm.retail.evoker.devastation.Name"] = "暴雪戰鬥助手"
L["rm.retail.evoker.devastation.Description"] = "推薦破滅專精使用。醒目提示暴雪戰鬥助手建議的下一個法術，這是在至暗之夜的戰鬥中，遊戲仍允許插件讀取的唯一循環建議；你施法、引導崩解或按住蓄力法術時它會等待。蓄力等級由你自行選擇。同時，戰鬥中會提醒龍之怒、深層吐息與攪亂均勢，對可中斷的施法使用壓制，以及黑曜鱗片只要就緒就提醒；脫戰時會在缺少青銅龍的祝福時提醒施放，並提醒對隊伍中的友方目標施放魔力之源。敵人的施法在戰鬥中會被隱藏，因此壓制只會在遊戲顯示它們的場合亮起；正式版中生命力是隱藏的，因此何時使用黑曜鱗片由你決定。"
L["rm.retail.evoker.devastation.guide.Name"] = "參考（SimulationCraft 與 Icy Veins）"
L["rm.retail.evoker.devastation.guide.Description"] = "僅供參考，預設關閉：最佳的破滅優先順序。觸發效果、冷卻與目標身上的燃燒效果在至暗之夜的戰鬥中會被隱藏，因此它無法在戰鬥中運作；可以閱讀它，或複製後自行實驗。以生命烈焰拉怪。龍隊指揮官（已學會集體崩解）：永恆奔騰，火焰之息，兩個以上敵人時使用深層吐息，有集體崩解充能時使用崩解，五個以上敵人時使用龍焰，崩解，有跳躍火焰時在燃盡觸發時使用生命烈焰，龍能爆發少於兩層時使用無縛烈焰，蒼藍掃擊。塑火者：永恆奔騰，火焰之息的燃燒效果消失或即將結束時使用火焰之息，五個以上敵人時使用龍焰，崩解，四個以上敵人時使用深層吐息，無縛烈焰，有跳躍火焰時在燃盡觸發時使用生命烈焰，蒼藍掃擊。接著移動中使用蒼藍打擊，生命烈焰，蒼藍打擊。單一目標時蓄力法術使用 1 級（Icy Veins）。提醒：龍之怒、在龍之怒期間或火焰之息就緒時使用攪亂均勢、龍隊指揮官使用深層吐息，以及功能性提醒。"
L["rm.retail.evoker.initial.Name"] = "暴雪戰鬥助手"
L["rm.retail.evoker.initial.Description"] = "在你選擇專精之前推薦使用（此時遊戲回報的是喚能師的初始專精）。醒目提示暴雪戰鬥助手建議的下一個法術，這是在至暗之夜的戰鬥中，遊戲仍允許插件讀取的唯一循環建議；你施法或引導時它會等待。同時附上每個喚能師內建循環共用的提醒，各項在你學會對應法術後才會出現。當你在 10 級選擇專精後，該專精的內建循環會接手。"
L["rm.retail.evoker.preservation.Name"] = "參考（Icy Veins）"
L["rm.retail.evoker.preservation.Description"] = "僅供參考，預設關閉。在至暗之夜的戰鬥中，盟友的生命力、回音、逆轉、龍能爆發與所有冷卻都對插件隱藏，Rotation Master 無法決定要治療誰，而暴雪也沒有為治療者提供戰鬥助手循環，因此這個內建循環不會進行治療。它會在脫戰時提醒你青銅龍的祝福與魔力之源；當你的目標是敵人時，它會建議傷害技能：火焰之息、崩解、生命烈焰，以及移動中使用蒼藍打擊。壓制與黑曜鱗片的提醒與其他喚能師內建循環相同。治療由你自行處理。"
