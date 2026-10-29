-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.
-- Built In rotation text: each key is the rotation ID plus .Name or .Description.
if GetLocale() ~= "zhCN" then return end
local addon_name = ...
local host = RotationMasterBuiltIns
local L = LibStub("AceLocale-3.0"):GetLocale(host and host.localeName or addon_name:match("^(.-)_[^_]+$") or addon_name)

L["rm.retail.demonhunter.devourer.Name"] = "暴雪战斗辅助"
L["rm.retail.demonhunter.devourer.Description"] = "推荐噬灭专精使用。高亮暴雪战斗辅助建议的下一个法术，这是在至暗之夜的战斗中游戏仍允许插件读取的唯一循环建议；你施法或引导虚空射线时它会等待。同时提醒战斗辅助留给你处理的部分：战斗中一旦就绪就使用的虚空变形、恶魔追击和虚空之刃、对可打断的施法使用瓦解，以及战斗中一就绪就使用的疾影。敌人的施法在战斗中是隐藏的，因此瓦解只在游戏显示它们的场合亮起；生命值在正式服中是隐藏的，因此何时使用疾影由你自己决定。"
L["rm.retail.demonhunter.devourer.guide.Name"] = "参考（Icy Veins）"
L["rm.retail.demonhunter.devourer.guide.Description"] = "仅供参考，默认关闭：Icy Veins 的歼灭者优先级。你的大部分增益效果在至暗之夜的战斗中是隐藏的，因此它无法在战斗中运行；怒气在正式服中是隐藏的，所以虚空射线只等待自身的消耗。虚空变形之外：灵魂爆发触发时使用吞噬，收割，灵魂献祭未在燃烧时使用灵魂献祭，虚空变形就绪后使用虚空之刃和恶魔追击，虚空变形，饥渴斩击，虚空射线，吞噬。虚空变形期间：灵魂爆发触发时使用吞噬，虚空射线，如果你有虚痕枭雄的打击技能就使用它们，坍缩之星，剔除，吞噬，灵魂献祭。Rotation Master 无法计算灵魂残片的数量，因此收割和剔除冷却好就用。提醒：瓦解和疾影。"
L["rm.retail.demonhunter.devourer.simc.Name"] = "参考（SimulationCraft）"
L["rm.retail.demonhunter.devourer.simc.Description"] = "仅供参考，默认关闭：SimulationCraft 的歼灭者列表，虚空变形一就绪就进入。战斗数据被隐藏，因此它无法在至暗之夜的战斗中运行。变形之外：敌人不超过三个且虚空变形已蓄满时，配合吞噬者之咬使用虚空之刃，虚空变形，灵魂爆发触发时使用吞噬，收割，虚空射线，对成群敌人使用灵魂献祭，吞噬。变形期间：单体时灵魂爆发触发则使用吞噬，配合吞噬者之咬使用恶魔追击和虚空之刃，对成群敌人使用虚空射线，坍缩之星，剔除，虚空射线，灵魂献祭，吞噬。提醒：瓦解和疾影。"
L["rm.retail.demonhunter.havoc.Name"] = "暴雪战斗辅助"
L["rm.retail.demonhunter.havoc.Description"] = "推荐浩劫专精使用。高亮暴雪战斗辅助建议的下一个法术，这是在至暗之夜的战斗中游戏仍允许插件读取的唯一循环建议；你施法或引导时它会等待。同时提醒游戏助手留给你处理的部分：战斗中的恶魔变形和恶魔追击、拥有冲撞惯性或能量放射时使用复仇回避、对可打断的施法使用瓦解，以及战斗中一就绪就使用的疾影。敌人的施法在战斗中是隐藏的，因此瓦解只在游戏显示它们的场合亮起；生命值在正式服中是隐藏的，因此何时使用疾影由你自己决定。移动、黑暗和饰品仍由你自己掌控。"
L["rm.retail.demonhunter.havoc.guide.Name"] = "参考（Icy Veins、SimulationCraft 和 Wowhead）"
L["rm.retail.demonhunter.havoc.guide.Description"] = "仅供参考，默认关闭：指南中的浩劫优先级。在至暗之夜的战斗中，你的触发效果、恶魔变形和精华破碎对插件隐藏，因此这个列表无法在战斗中运行；可以阅读它，或复制后自行试验。怒气在正式服中是隐藏的，所以邪能之刃不会等待怒气空间。奥达奇收割者：撕裂猛击和战刃乱舞都未生效时使用收割者战刃，撕裂猛击生效时使用混乱打击。邪痕枭雄：恶魔变形期间使用精华破碎、刃舞和混乱打击。然后在精华破碎期间使用刃舞和混乱打击，两层充能时使用献祭光环，眼棱，使用邪能之刃触发冲撞惯性，眼棱还有 4 秒以上才就绪时使用精华破碎，刃舞，面对两个敌人时使用献祭光环，混乱打击，邪能之刃，献祭光环，投掷利刃，邪能冲撞。提醒：眼棱和刃舞都用完后使用恶魔变形、恶魔追击、复仇回避，以及瓦解和疾影。"
L["rm.retail.demonhunter.initial.Name"] = "暴雪战斗辅助"
L["rm.retail.demonhunter.initial.Description"] = "推荐在你选择专精之前使用（此时游戏报告的是恶魔猎手的初始专精）。高亮暴雪战斗辅助建议的下一个法术，这是在至暗之夜的战斗中游戏仍允许插件读取的唯一循环建议；你施法或引导时它会等待。同时包含所有恶魔猎手内置循环共用的提醒，每一项在你学会对应法术后生效。当你在 10 级选择专精后，该专精的内置循环会接管。"
L["rm.retail.demonhunter.vengeance.Name"] = "暴雪战斗辅助"
L["rm.retail.demonhunter.vengeance.Description"] = "推荐复仇专精使用。高亮暴雪战斗辅助建议的下一个法术，这是在至暗之夜的战斗中游戏仍允许插件读取的唯一循环建议；你施法或引导时它会等待。同时提醒战斗辅助留给你处理的部分：战斗中一旦就绪就使用的恶魔尖刺、烈火烙印、邪能毁灭和恶魔变形、对可打断的施法使用瓦解，以及战斗中一就绪就使用的疾影。敌人的施法在战斗中是隐藏的，因此瓦解只在游戏显示它们的场合亮起；生命值在正式服中是隐藏的，因此何时使用疾影由你自己决定。地狱火撞击、黑暗、嘲讽和饰品仍由你自己掌控。"
L["rm.retail.demonhunter.vengeance.guide.Name"] = "参考（Wowhead 和 Icy Veins）"
L["rm.retail.demonhunter.vengeance.guide.Description"] = "仅供参考，默认关闭：Wowhead 的复仇施放顺序，并采用 Icy Veins 的英雄天赋目标。你的增益效果在至暗之夜的战斗中是隐藏的，因此它无法在战斗中运行；怒气在正式服中是隐藏的，所以消耗技能只等待自身的消耗，攒怒气的技能也不会避免溢出。奥达奇收割者：收割者战刃，撕裂猛击生效时使用破裂，战刃乱舞生效时使用灵魂裂劈。然后充能已满时使用破裂，三个或更多敌人时使用幽魂炸弹，献祭光环，烈焰咒符，单体时使用灵魂裂劈，邪能毁灭，灵魂裂劈，破裂，邪能之刃，投掷利刃。Rotation Master 无法计算灵魂残片的数量，因此幽魂炸弹按敌人数量判断。提醒：恶魔尖刺未生效时使用恶魔尖刺、恶魔变形、烈火烙印、怨念咒符、灵魂切削（两层充能时的地狱火撞击提醒为关闭状态），以及瓦解和疾影。"
L["rm.retail.demonhunter.vengeance.simc.Name"] = "参考（SimulationCraft）"
L["rm.retail.demonhunter.vengeance.simc.Description"] = "仅供参考，默认关闭：SimulationCraft 的复仇列表。战斗数据被隐藏，因此它无法在至暗之夜的战斗中运行；怒气在正式服中是隐藏的，所以其怒气阈值被省略了。奥达奇收割者：先使用烈焰咒符和献祭光环，恶魔变形，配合邪能之刃的收割者战刃循环，烈火烙印，怨念咒符，对成群敌人使用幽魂炸弹，猛烈的死亡期间使用灵魂切削，然后是破裂、灵魂裂劈、邪能之刃、邪能毁灭。歼灭者：虚落就绪时用幽魂炸弹或灵魂裂劈消耗它，虚落达到两层时使用破裂，恶魔变形，幽魂炸弹，怨念咒符，充能已满时使用破裂，献祭光环，烈焰咒符，破裂，灵魂裂劈，邪能之刃，投掷利刃。提醒：恶魔尖刺、瓦解、疾影。"
