-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.
-- Translators: Claude (AI-assisted, not yet reviewed by a native speaker), Codex (AI-assisted, not yet reviewed by a native speaker)
-- Built In rotation text: each key is the rotation ID plus .Name or .Description.
if GetLocale() ~= "koKR" then return end
local addon_name = ...
local host = RotationMasterBuiltIns
local L = LibStub("AceLocale-3.0"):GetLocale(host and host.localeName or addon_name:match("^(.-)_[^_]+$") or addon_name)

L["rm.retail.evoker.augmentation.Name"] = "Icy Veins"
L["rm.retail.evoker.augmentation.Description"] = "증강 전문화에 권장됩니다: Icy Veins의 칠흑의 힘 우선순위입니다. 칠흑의 힘은 한밤 전투에서도 게임이 애드온에 보여 주는 몇 안 되는 강화 효과이므로 그곳에서도 유지가 작동합니다. 전투 밖: 끓어오르는 비늘이 없는 우호적 그룹 대상에게 끓어오르는 비늘, 적에게 살아있는 불꽃. 그다음 칠흑의 힘이 없거나 4초 미만이면 칠흑의 힘, 영겁의 숨결이 준비되지 않았다면 재사용 대기시간마다 칠흑의 힘; 예지; 불의 숨결; 지각 변동; 칠흑의 힘 중이거나 정수 폭발 2중첩에서 분출; 하늘빛 일격; 살아있는 불꽃. 숨겨진 강화 효과는 전투 중 자기 단계만 건너뜁니다. 알림: 영겁의 숨결과 깊은 숨결(조준은 직접), 불의 숨결이 준비되었을 때 전세역전, 불의 숨결과 지각 변동이 모두 재사용 대기 중이면 시간 건너뛰기, 그리고 유틸리티 알림. 예지와 끓어오르는 비늘은 현재 대상에게 시전됩니다: 아군 선택과 강화 단계는 직접 판단합니다."
L["rm.retail.evoker.augmentation.assisted.Name"] = "Blizzard 전투 보조"
L["rm.retail.evoker.augmentation.assisted.Description"] = "증강 전문화에 대한 Blizzard의 전투 보조 제안으로, 추천 Icy Veins 증강 기본 제공 로테이션의 대안이며 기본적으로 꺼져 있습니다: 이것을 켜고 그것을 끄거나, 이것의 우선순위를 높이세요. 칠흑의 힘은 사라진 뒤에만 다시 시전하며, 시전 중이거나 강화 주문을 충전하는 동안에는 기다립니다. 전투 중 영겁의 숨결, 깊은 숨결, 전세역전, 시간 건너뛰기 알림, 그리고 다른 기원사 기본 제공 로테이션처럼 진압, 흑요석 비늘, 청동용군단의 축복, 마법의 원천 알림."
L["rm.retail.evoker.devastation.Name"] = "Blizzard 전투 보조"
L["rm.retail.evoker.devastation.Description"] = "황폐 전문화에 권장됩니다. Blizzard의 전투 보조가 다음으로 제안하는 주문을 강조합니다. 한밤 전투에서 게임이 애드온에 아직 읽기를 허용하는 유일한 로테이션 조언이며, 시전 중이거나 파열을 정신 집중하거나 강화 주문을 충전하는 동안에는 기다립니다. 강화 단계 선택은 직접 판단합니다. 이와 함께 전투 중에는 용의 분노, 깊은 숨결, 전세역전, 차단 가능한 시전에 진압, 준비될 때마다 흑요석 비늘을, 전투 밖에서는 청동용군단의 축복이 없을 때 청동용군단의 축복, 그룹 내 우호적 대상에게 마법의 원천을 알려 줍니다. 적의 시전은 전투 중 숨겨지므로 진압은 게임이 시전을 보여 주는 곳에서만 강조되며, Retail에서는 생명력이 숨겨지므로 흑요석 비늘을 언제 쓸지는 직접 판단합니다."
L["rm.retail.evoker.devastation.guide.Name"] = "참고용 (SimulationCraft와 Icy Veins)"
L["rm.retail.evoker.devastation.guide.Description"] = "참고용이며 기본적으로 꺼져 있습니다. 최적의 황폐 우선순위입니다. 한밤 전투에서는 발동 효과, 재사용 대기시간, 대상의 화상 효과가 숨겨지므로 그곳에서는 실행할 수 없습니다. 읽어 보거나, 복제해서 실험해 보세요. 살아있는 불꽃으로 끌어옵니다. 비늘사령관(대규모 파열을 배운 경우): 영원의 쇄도, 불의 숨결, 적이 둘 이상이면 깊은 숨결, 대규모 파열 충전이 있으면 파열, 다섯 이상이면 기염, 파열, 화염 도약이 있을 때 불태움 발동 시 살아있는 불꽃, 정수 폭발이 2중첩 미만이면 해방된 불길, 하늘빛 휩쓸기. 불꽃형성자: 영원의 쇄도, 화상 효과가 없거나 끝나 가면 불의 숨결, 다섯 이상이면 기염, 파열, 넷 이상이면 깊은 숨결, 해방된 불길, 화염 도약이 있을 때 불태움 발동 시 살아있는 불꽃, 하늘빛 휩쓸기. 그다음 이동 중 하늘빛 일격, 살아있는 불꽃, 하늘빛 일격. 대상이 하나면 강화 주문은 1단계로 사용합니다(Icy Veins). 알림: 용의 분노, 용의 분노 중이거나 불의 숨결이 준비되었을 때 전세역전, 비늘사령관이면 깊은 숨결, 그리고 유틸리티 알림."
L["rm.retail.evoker.initial.Name"] = "Blizzard 전투 보조"
L["rm.retail.evoker.initial.Description"] = "전문화를 선택하기 전(게임이 기원사의 초기 전문화를 보고하는 동안)에 권장됩니다. Blizzard의 전투 보조가 다음으로 제안하는 주문을 강조합니다. 한밤 전투에서 게임이 애드온에 아직 읽기를 허용하는 유일한 로테이션 조언이며, 시전이나 정신 집중 중에는 기다립니다. 이와 함께 모든 기원사 기본 제공 로테이션이 공유하는 알림을, 해당 주문을 배운 뒤에 각각 제공합니다. 10레벨에 전문화를 선택하면 해당 전문화의 기본 제공 로테이션이 대신합니다."
L["rm.retail.evoker.preservation.Name"] = "참고용 (Icy Veins)"
L["rm.retail.evoker.preservation.Description"] = "참고용이며 기본적으로 꺼져 있습니다. 한밤 전투에서는 아군의 생명력, 메아리, 되감기, 정수 폭발, 모든 재사용 대기시간이 애드온에 숨겨지고, Rotation Master는 누구를 치유할지 고를 수 없으며, Blizzard는 치유 전담용 전투 보조 로테이션을 제공하지 않으므로 이 기본 제공 로테이션은 치유하지 않습니다. 전투 밖에서는 청동용군단의 축복과 마법의 원천을 알려 주고, 대상이 적이면 피해 기술을 제안합니다: 불의 숨결, 파열, 살아있는 불꽃, 이동 중 하늘빛 일격. 진압과 흑요석 비늘 알림은 다른 기원사 기본 제공 로테이션과 같습니다. 치유는 직접 판단합니다."
