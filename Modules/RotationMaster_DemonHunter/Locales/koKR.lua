-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.
-- Translators: Claude (AI-assisted, not yet reviewed by a native speaker), Codex (AI-assisted, not yet reviewed by a native speaker)
-- Built In rotation text: each key is the rotation ID plus .Name or .Description.
if GetLocale() ~= "koKR" then return end
local addon_name = ...
local host = RotationMasterBuiltIns
local L = LibStub("AceLocale-3.0"):GetLocale(host and host.localeName or addon_name:match("^(.-)_[^_]+$") or addon_name)

L["rm.retail.demonhunter.devourer.Name"] = "Blizzard 전투 보조"
L["rm.retail.demonhunter.devourer.Description"] = "포식 전문화에 권장됩니다. Blizzard의 전투 보조가 다음으로 제안하는 주문을 강조합니다. 한밤 전투에서 게임이 애드온에 아직 읽기를 허용하는 유일한 로테이션 조언이며, 시전 중이거나 공허 광선을 정신 집중하는 동안에는 기다립니다. 이와 함께 보조 기능이 플레이어에게 맡기는 것을 알려 줍니다: 전투 중 준비될 때마다 공허 탈태, 사냥, 공허칼날, 차단 가능한 시전에 분열, 전투 중 준비될 때마다 흐릿해지기. 적의 시전은 전투 중 숨겨지므로 분열은 게임이 시전을 보여 주는 곳에서만 강조되며, Retail에서는 생명력이 숨겨지므로 흐릿해지기를 언제 쓸지는 직접 판단합니다."
L["rm.retail.demonhunter.devourer.guide.Name"] = "참고용 (Icy Veins)"
L["rm.retail.demonhunter.devourer.guide.Description"] = "참고용이며 기본적으로 꺼져 있습니다. Icy Veins의 궤멸자 우선순위입니다. 한밤 전투에서는 대부분의 강화 효과가 숨겨지므로 그곳에서는 실행할 수 없으며, Retail에서는 분노가 숨겨지므로 공허 광선은 비용만 기다립니다. 공허 탈태 밖: 영혼분출 발동 시 흡수, 수확, 영혼 제물이 타오르고 있지 않으면 영혼 제물, 공허 탈태가 준비되면 공허칼날과 사냥, 공허 탈태, 굶주린 베기, 공허 광선, 흡수. 공허 탈태 중: 영혼분출 발동 시 집어삼키기, 공허 광선, 공허상흔 일격(있다면), 붕괴하는 별, 도태, 집어삼키기, 영혼 제물. Rotation Master는 영혼 파편을 셀 수 없으므로 수확과 도태는 재사용 대기시간마다 사용합니다. 알림: 분열과 흐릿해지기."
L["rm.retail.demonhunter.devourer.simc.Name"] = "참고용 (SimulationCraft)"
L["rm.retail.demonhunter.devourer.simc.Description"] = "참고용이며 기본적으로 꺼져 있습니다. 공허 탈태가 준비되는 즉시 들어가는 SimulationCraft의 궤멸자 목록입니다. 숨겨진 전투 데이터 때문에 한밤 전투에서는 실행되지 않습니다. 공허 탈태 밖: 적이 셋 이하이고 공허 탈태가 가득 찼을 때 포식자의 이빨과 함께 공허칼날, 공허 탈태, 영혼분출 발동 시 흡수, 수확, 공허 광선, 몹 무리에 영혼 제물, 흡수. 공허 탈태 중: 대상이 하나일 때 영혼분출 발동 시 집어삼키기, 포식자의 이빨과 함께 사냥과 공허칼날, 몹 무리에 공허 광선, 붕괴하는 별, 도태, 공허 광선, 영혼 제물, 집어삼키기. 알림: 분열과 흐릿해지기."
L["rm.retail.demonhunter.havoc.Name"] = "Blizzard 전투 보조"
L["rm.retail.demonhunter.havoc.Description"] = "파멸 전문화에 권장됩니다. Blizzard의 전투 보조가 다음으로 제안하는 주문을 강조합니다. 한밤 전투에서 게임이 애드온에 아직 읽기를 허용하는 유일한 로테이션 조언이며, 시전이나 정신 집중 중에는 기다립니다. 이와 함께 게임의 보조 기능이 플레이어에게 맡기는 것을 알려 줍니다: 전투 중 탈태와 사냥, 타성 또는 갈무리한 기운이 있으면 복수의 퇴각, 차단 가능한 시전에 분열, 전투 중 준비될 때마다 흐릿해지기. 적의 시전은 전투 중 숨겨지므로 분열은 게임이 시전을 보여 주는 곳에서만 강조되며, Retail에서는 생명력이 숨겨지므로 흐릿해지기를 언제 쓸지는 직접 판단합니다. 이동, 어둠, 장신구는 직접 판단합니다."
L["rm.retail.demonhunter.havoc.guide.Name"] = "참고용 (Icy Veins, SimulationCraft와 Wowhead)"
L["rm.retail.demonhunter.havoc.guide.Description"] = "참고용이며 기본적으로 꺼져 있습니다. 공략의 파멸 우선순위입니다. 한밤 전투에서는 발동 효과, 탈태, 정수 파쇄가 애드온에 숨겨지므로 이 목록은 그곳에서는 실행할 수 없습니다. 읽어 보거나, 복제해서 실험해 보세요. Retail에서는 분노가 숨겨지므로 지옥칼은 여유 공간을 기다리지 않습니다. 알드라치 파괴자: 분쇄 일격과 몰아치는 전투검이 모두 없으면 파괴자의 글레이브, 분쇄 일격 발동 시 혼돈의 일격. 지옥상흔: 탈태 중 정수 파쇄, 칼춤, 혼돈의 일격. 그다음 정수 파쇄 중 칼춤과 혼돈의 일격, 충전 2회에서 제물의 오라, 안광, 타성을 위해 지옥칼, 안광까지 4초 넘게 남았으면 정수 파쇄, 칼춤, 적이 둘이면 제물의 오라, 혼돈의 일격, 지옥칼, 제물의 오라, 글레이브 투척, 지옥 돌진. 알림: 안광과 칼춤을 쓴 뒤 탈태, 사냥, 복수의 퇴각, 그리고 분열과 흐릿해지기."
L["rm.retail.demonhunter.initial.Name"] = "Blizzard 전투 보조"
L["rm.retail.demonhunter.initial.Description"] = "전문화를 선택하기 전(게임이 악마사냥꾼의 초기 전문화를 보고하는 동안)에 권장됩니다. Blizzard의 전투 보조가 다음으로 제안하는 주문을 강조합니다. 한밤 전투에서 게임이 애드온에 아직 읽기를 허용하는 유일한 로테이션 조언이며, 시전이나 정신 집중 중에는 기다립니다. 이와 함께 모든 악마사냥꾼 기본 제공 로테이션이 공유하는 알림을, 해당 주문을 배운 뒤에 각각 제공합니다. 10레벨에 전문화를 선택하면 해당 전문화의 기본 제공 로테이션이 대신합니다."
L["rm.retail.demonhunter.vengeance.Name"] = "Blizzard 전투 보조"
L["rm.retail.demonhunter.vengeance.Description"] = "복수 전문화에 권장됩니다. Blizzard의 전투 보조가 다음으로 제안하는 주문을 강조합니다. 한밤 전투에서 게임이 애드온에 아직 읽기를 허용하는 유일한 로테이션 조언이며, 시전이나 정신 집중 중에는 기다립니다. 이와 함께 보조 기능이 플레이어에게 맡기는 것을 알려 줍니다: 전투 중 준비될 때마다 악마 쐐기, 불타는 낙인, 지옥 황폐, 탈태, 차단 가능한 시전에 분열, 전투 중 준비될 때마다 흐릿해지기. 적의 시전은 전투 중 숨겨지므로 분열은 게임이 시전을 보여 주는 곳에서만 강조되며, Retail에서는 생명력이 숨겨지므로 흐릿해지기를 언제 쓸지는 직접 판단합니다. 불지옥 일격, 어둠, 도발, 장신구는 직접 판단합니다."
L["rm.retail.demonhunter.vengeance.guide.Name"] = "참고용 (Wowhead와 Icy Veins)"
L["rm.retail.demonhunter.vengeance.guide.Description"] = "참고용이며 기본적으로 꺼져 있습니다. Icy Veins의 영웅 특성 목표를 더한 Wowhead의 복수 순서입니다. 한밤 전투에서는 강화 효과가 숨겨지므로 그곳에서는 실행할 수 없으며, Retail에서는 분노가 숨겨지므로 소모 기술은 비용만 기다리고 생성 기술은 최대치를 피하지 않습니다. 알드라치 파괴자: 파괴자의 글레이브, 분쇄 일격 발동 시 균열, 몰아치는 전투검 발동 시 영혼 베어내기. 그다음 충전이 가득 차면 균열, 적이 셋 이상이면 영혼 폭탄, 제물의 오라, 불꽃의 인장, 대상이 하나일 때 영혼 베어내기, 지옥 황폐, 영혼 베어내기, 균열, 지옥칼, 글레이브 투척. Rotation Master는 영혼 파편을 셀 수 없으므로 영혼 폭탄은 적 수를 따릅니다. 알림: 악마 쐐기가 없을 때 악마 쐐기, 탈태, 불타는 낙인, 원한의 인장, 영혼 저미기(충전 2회에서 불지옥 일격은 꺼져 있음), 그리고 분열과 흐릿해지기."
L["rm.retail.demonhunter.vengeance.simc.Name"] = "참고용 (SimulationCraft)"
L["rm.retail.demonhunter.vengeance.simc.Description"] = "참고용이며 기본적으로 꺼져 있습니다. SimulationCraft의 복수 목록입니다. 숨겨진 전투 데이터 때문에 한밤 전투에서는 실행되지 않으며, Retail에서는 분노가 숨겨지므로 분노 기준은 빠져 있습니다. 알드라치 파괴자: 불꽃의 인장과 제물의 오라 먼저, 탈태, 지옥칼을 섞은 파괴자의 글레이브 순환, 불타는 낙인, 원한의 인장, 몹 무리에 영혼 폭탄, 뜨거운 최후 중 영혼 저미기, 그다음 균열, 영혼 베어내기, 지옥칼, 지옥 황폐. 궤멸자: 준비된 공허내림을 영혼 폭탄이나 영혼 베어내기로 소모, 공허내림 2중첩에서 균열, 탈태, 영혼 폭탄, 원한의 인장, 충전이 가득 차면 균열, 제물의 오라, 불꽃의 인장, 균열, 영혼 베어내기, 지옥칼, 글레이브 투척. 알림: 악마 쐐기, 분열, 흐릿해지기."
