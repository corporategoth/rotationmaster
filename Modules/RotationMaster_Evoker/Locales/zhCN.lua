-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.
-- Built In rotation text: each key is the rotation ID plus .Name or .Description.
if GetLocale() ~= "zhCN" then return end
local addon_name = ...
local host = RotationMasterBuiltIns
local L = LibStub("AceLocale-3.0"):GetLocale(host and host.localeName or addon_name:match("^(.-)_[^_]+$") or addon_name)

L["rm.retail.evoker.augmentation.Name"] = "Icy Veins"
L["rm.retail.evoker.augmentation.Description"] = "推荐增辉专精使用：Icy Veins 的黑檀之力优先级。黑檀之力是至暗之夜战斗中游戏仍向插件显示的少数增益效果之一，因此在战斗中也能维持它。脱战时：对没有炽火龙鳞的友方队伍目标施放炽火龙鳞，对敌人使用活化烈焰。然后黑檀之力缺失或剩余不足 4 秒时使用黑檀之力，除非亘古吐息已就绪，否则冷却好就用；先知先觉；火焰吐息；地壳激变；黑檀之力期间或有两层精华迸发时使用喷发；碧蓝打击；活化烈焰。被隐藏的增益效果在战斗中只会跳过它们各自的步骤。提醒：亘古吐息和深呼吸（由你瞄准）、火焰吐息就绪时使用扭转天平、火焰吐息和地壳激变都在冷却时使用时间跳跃，以及功能性提醒。先知先觉和炽火龙鳞会施放在你的目标上：选择哪位盟友以及蓄力等级都由你决定。"
L["rm.retail.evoker.augmentation.assisted.Name"] = "暴雪战斗辅助"
L["rm.retail.evoker.augmentation.assisted.Description"] = "暴雪战斗辅助对增辉的建议，是推荐的 Icy Veins 增辉内置循环的替代方案，默认关闭：启用它并禁用那个，或提高它的优先级。它只会在黑檀之力消失后才重新施放，并在你施法或按住蓄力法术时等待。战斗中提醒亘古吐息、深呼吸、扭转天平和时间跳跃，以及与其他唤魔师内置循环相同的镇压、黑曜鳞片、青铜龙的祝福和魔力之源。"
L["rm.retail.evoker.devastation.Name"] = "暴雪战斗辅助"
L["rm.retail.evoker.devastation.Description"] = "推荐湮灭专精使用。高亮暴雪战斗辅助建议的下一个法术，这是在至暗之夜的战斗中游戏仍允许插件读取的唯一循环建议；你施法、引导裂解或按住蓄力法术时它会等待。蓄力等级由你自己选择。同时，战斗中会提醒狂龙之怒、深呼吸和扭转天平，对可打断的施法使用镇压，以及一就绪就使用的黑曜鳞片；脱战时会在缺少青铜龙的祝福时提醒施放，并提醒对队伍中的友方目标施放魔力之源。敌人的施法在战斗中是隐藏的，因此镇压只在游戏显示它们的场合亮起；生命值在正式服中是隐藏的，因此何时使用黑曜鳞片由你自己决定。"
L["rm.retail.evoker.devastation.guide.Name"] = "参考（SimulationCraft 和 Icy Veins）"
L["rm.retail.evoker.devastation.guide.Description"] = "仅供参考，默认关闭：最优的湮灭优先级。触发效果、冷却和目标身上的燃烧效果在至暗之夜的战斗中是隐藏的，因此它无法在战斗中运行；可以阅读它，或复制后自行试验。以活化烈焰拉怪。鳞长（已学会群体裂解）：永恒之涌，火焰吐息，两个或更多敌人时使用深呼吸，有群体裂解充能时使用裂解，五个或更多敌人时使用葬火，裂解，有飞扑烈焰时在燃尽触发时使用活化烈焰，精华迸发少于两层时使用释缚烈焰，碧蓝横扫。塑焰者：永恒之涌，火焰吐息的燃烧效果缺失或即将结束时使用火焰吐息，五个或更多敌人时使用葬火，裂解，四个或更多敌人时使用深呼吸，释缚烈焰，有飞扑烈焰时在燃尽触发时使用活化烈焰，碧蓝横扫。然后移动中使用碧蓝打击，活化烈焰，碧蓝打击。单体时蓄力法术使用 1 级（Icy Veins）。提醒：狂龙之怒、在狂龙之怒期间或火焰吐息就绪时使用扭转天平、鳞长使用深呼吸，以及功能性提醒。"
L["rm.retail.evoker.initial.Name"] = "暴雪战斗辅助"
L["rm.retail.evoker.initial.Description"] = "推荐在你选择专精之前使用（此时游戏报告的是唤魔师的初始专精）。高亮暴雪战斗辅助建议的下一个法术，这是在至暗之夜的战斗中游戏仍允许插件读取的唯一循环建议；你施法或引导时它会等待。同时包含所有唤魔师内置循环共用的提醒，每一项在你学会对应法术后生效。当你在 10 级选择专精后，该专精的内置循环会接管。"
L["rm.retail.evoker.preservation.Name"] = "参考（Icy Veins）"
L["rm.retail.evoker.preservation.Description"] = "仅供参考，默认关闭。在至暗之夜的战斗中，盟友的生命值、回响、逆转、精华迸发和所有冷却都对插件隐藏，Rotation Master 无法决定治疗谁，而暴雪也没有为治疗者提供战斗辅助循环，因此这个内置循环不会进行治疗。它会在脱战时提醒你青铜龙的祝福和魔力之源；当你的目标是敌人时，它会建议伤害技能：火焰吐息、裂解、活化烈焰，以及移动中使用碧蓝打击。镇压和黑曜鳞片的提醒与其他唤魔师内置循环相同。治疗仍由你自己掌控。"
