# Translation glossary

The wording each locale already uses for the addon's recurring terms, read from the locale files by `python3 tools/translation_glossary.py --write`. Use the same word for the same thing: a player sees "Switch" in a menu, a tooltip and a help paragraph, and they must match. When a locale changes its wording, change it everywhere and regenerate this file. Game vocabulary (spells, classes, specializations, stats, zones) follows the game client's own translation, not this table.

`-` means no short entry exists in that locale yet. Columns: deDE German, esES Spanish (Spain), esMX Spanish (Latin America), frFR French, itIT Italian, koKR Korean, ptBR Portuguese (Brazil), ruRU Russian, zhCN Chinese (Simplified), zhTW Chinese (Traditional).

## Core terms

| Term | deDE | esES | esMX | frFR | itIT | koKR | ptBR | ruRU | zhCN | zhTW | Note |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Rotation | Rotation | Rotación | Rotación | Rotation | Rotazione | 로테이션 | Rotação | Ротация | 循环 | 循環 | The ordered priority list the addon advises from. Plural: Rotations. |
| Rotations | Rotationen | Rotaciones | Rotaciones | Rotations | Rotazioni | 로테이션 | Rotações | Ротации | 循环 | 循環 |  |
| Step | Schritt | Paso | Paso | Étape | Passo | 단계 | Passo | Шаг | 步骤 | 步驟 | One entry in a rotation: an action, Branch or Stop. Taken from "Step %d". |
| Steps | Schritte | Pasos | Pasos | Étapes | Passi | 단계 | Passos | Шаги | 步数 | 步數 |  |
| Condition | Bedingung | Condición | Condición | Condition | Condizione | 조건 | Condição | Условие | 条件 | 條件 | A test (health below 30%, spell ready, ...). Plural: Conditions. |
| Conditions | Bedingungen | Condiciones | Condiciones | Conditions | Condizioni | 조건 | Condições | Условия | 条件 | 條件 |  |
| Switch | Wechsel | Cambio | Cambio | Bascule | Cambio | 전환 | Troca | Переключение | 切换 | 切換 | The condition that decides when a rotation is selected automatically; not the verb. |
| Built In | Integriert | Integrada | Integrada | Intégrée | Integrate | 기본 제공 | Integrada | Встроенные | 内置 | 內建 | A premade rotation shipped with the addon; read-only, can be cloned. |
| Priority | Priorität | Prioridad | Prioridad | Priorité | Priorità | 우선순위 | Prioridade | Приоритет | 优先级 | 優先順序 | Higher is tried first. Taken from "Priority %s". |
| Specialization | Spezialisierung | Especialización | Especialización | Spécialisation | Specializzazione | 전문화 | Especialização | Специализация | 专精 | 專精 | Follow the game client: talent specialization. |
| Cooldown | Abklingzeit | Tiempo de reutilización | Tiempo de reutilización | Temps de recharge | Tempo di recupero | 재사용 대기시간 | Tempo de recarga | Восстановление | 冷却 | 冷卻 | Follow the game client; also names the rotation section that runs on its own. |
| Cooldowns | Abklingzeiten | Tiempos de reutilización | Tiempos de reutilización | Temps de recharge | Tempi di recupero | 재사용 대기시간 | Tempos de recarga | Восстановления | 冷却 | 冷卻 |  |
| Stop | Stopp | Detener | Detener | Arrêt | Stop | 중지 | Parar | Стоп | 停止 | 停止 | A step type: end the pass when its condition holds. |
| Branch | Verzweigung | Rama | Rama | Branche | Ramo | 분기 | Ramificação | Ветвь | 分支 | 分支 | A step type: an If / Else split. |
| Action | Aktion | Acción | Acción | Action | Azione | 동작 | Ação | Действие | 动作 | 動作 |  |
| Spell | Zauber | Hechizo | Hechizo | Sort | Incantesimo | 주문 | Feitiço | Заклинание | 法术 | 法術 | Follow the game client. |
| Item | Gegenstand | Objeto | Objeto | Objet | Oggetto | 아이템 | Item | Предмет | 物品 | 物品 | Follow the game client. |
| Talent | Talent | Talento | Talento | Talent | Talento | 특성 | Talento | Талант | 天赋 | 天賦 | Follow the game client. |
| Target | Ziel | Objetivo | Objetivo | Cible | Bersaglio | 대상 | Alvo | Цель | 目标 | 目標 | Follow the game client. |
| Pet | Begleiter | Mascota | Mascota | Familier | Famiglio | 소환수 | Ajudante | Питомец | 宠物 | 寵物 | Follow the game client. |
| Class | Klasse | Clase | Clase | Classe | Classe | 직업 | Classe | Класс | 职业 | 職業 | Follow the game client. |
| Level | Stufe | Nivel | Nivel | Niveau | Livello | 레벨 | Nível | Уровень | 等级 | 等級 | Follow the game client. |
| Health | Gesundheit | Salud | Salud | Points de vie | Salute | 생명력 | Vida | Здоровье | 生命值 | 生命力 | Follow the game client. |
| Mana | Mana | Maná | Maná | Mana | Mana | 마나 | Mana | Мана | 法力值 | 法力 | Follow the game client. |
| Combat | Kampf | Combate | Combate | Combat | Combattimento | 전투 | Combate | Бой | 战斗 | 戰鬥 | Follow the game client. |
| Channel | Kanal | Canal | Canal | Canal | Canale | 채널 | Canal | Канал | 频道 | 頻道 | Spell channeling in this addon (not a chat channel in the combat-log sense). |
| Stacks | Stapel | Acumulaciones | Acumulaciones | Cumuls | Accumuli | 중첩 | Acúmulos | Наложения | 层数 | 層數 | Aura stacks. |
| Unit | Einheit | Unidad | Unidad | Unité | Unità | 유닛 | Unidade | Юнит | 单位 | 單位 | A game unit token: player, target, focus, ... |
| Identifier | Bezeichner | Identificador | Identificador | Identifiant | Identificatore | 식별자 | Identificador | Идентификатор | 标识符 | 識別碼 | Short name used with /rm set. Never "Handle". |
| Tags | Tags | Etiquetas | Etiquetas | Étiquettes | Tag | 태그 | Etiquetas | Метки | 标签 | 標籤 | Labels on a rotation. |
| Function | Funktion | Función | Función | Fonction | Funzione | 함수 | Função | Функция | 函数 | 函式 | A named reusable Lua function. |
| Functions | Funktionen | Funciones | Funciones | Fonctions | Funzioni | 함수 | Funções | Функции | 函数 | 函式 |  |
| Effect | Effekt | Efecto | Efecto | Effet | Effetto | 효과 | Efeito | Эффект | 效果 | 效果 | A highlight effect. |
| Effects | Effekte | Efectos | Efectos | Effets | Effetti | 효과 | Efeitos | Эффекты | 效果 | 效果 |  |
| Item Set | Gegenstandsset | Conjunto de objetos | Conjunto de objetos | Ensemble d'objets | Set di oggetti | 아이템 세트 | Conjunto de itens | Комплект предметов | 物品组 | 物品組 | An ordered list of items the addon treats as one button. |
| Item Sets | Gegenstandssets | Conjuntos de objetos | Conjuntos de objetos | Ensembles d'objets | Set di oggetti | 아이템 세트 | Conjuntos de itens | Комплекты предметов | 物品组 | 物品組 |  |
| Announce | Ankündigen | Anunciar | Anunciar | Annonce | Annuncio | 알림 | Anunciar | Оповещение | 通报 | 通報 | Chat or sound output when something happens. |
| Default | Standard | Predeterminado | Predeterminado | Par défaut | Predefinito | 기본값 | Padrão | По умолчанию | 默认 | 預設 | The fallback rotation / default value. |
| Fallback | Ersatz | Reserva | Reserva | Repli | Riserva | 대체 | Reserva | Запасная | 后备 | 備用 | The rotation used when no other can be selected. |
| Custom | Benutzerdefiniert | Personalizado | Personalizado | Personnalisé | Personalizzate | 사용자 | Personalizado | Свои | 自定义 | 自訂 | User-made, as opposed to Built In. |
| Unavailable | Nicht verfügbar | No disponible | No disponible | Indisponible | Non disponibile | 사용할 수 없음 | Indisponível | Недоступно | 不可用 | 無法使用 | A condition that cannot be evaluated right now. |
| Preview | Vorschau | Vista previa | Vista previa | Aperçu | Anteprima | 미리보기 | Pré-visualizar | Предпросмотр | 预览 | 預覽 |  |
| Import | Importieren | Importar | Importar | Importer | Importa | 가져오기 | Importar | Импорт | 导入 | 匯入 |  |
| Copy | Kopieren | Copiar | Copiar | Copier | Copia | 복사 | Copiar | Копировать | 复制 | 複製 |  |
| Duplicate | Duplizieren | Duplicar | Duplicar | Dupliquer | Duplica | 복제 | Duplicar | Дублировать | 复制 | 複製 |  |
| Undo | Rückgängig | Deshacer | Deshacer | Défaire | Annulla | 실행 취소 | Desfazer | Отменить | 撤销 | 復原 |  |
| Redo | Wiederherstellen | Rehacer | Rehacer | Refaire | Ripeti | 다시 실행 | Refazer | Повторить | 重做 | 重做 |  |
| Apply | Übernehmen | Aplicar | Aplicar | Appliquer | Applica | 적용 | Aplicar | Применить | 应用 | 套用 |  |
| Cancel | Abbrechen | Cancelar | Cancelar | Annuler | Annulla | 취소 | Cancelar | Отмена | 取消 | 取消 |  |
| Discard | Verwerfen | Descartar | Descartar | Abandonner | Scarta | 변경 취소 | Descartar | Отменить изменения | 放弃 | 捨棄 | Throw away unsaved edits. |
| Delete | Löschen | Borrar | Borrar | Supprimer | Elimina | 삭제 | Excluir | Удалить | 删除 | 刪除 |  |
| Add | Hinzufügen | Añadir | Agregar | Ajouter | Aggiungi | 추가 | Adicionar | Добавить | 添加 | 新增 |  |
| Edit | Bearbeiten | Editar | Editar | Modifier | Modifica | 편집 | Editar | Изменить | 编辑 | 編輯 |  |
| Reset | Zurücksetzen | Restablecer | Restablecer | Réinitialiser | Reimposta | 초기화 | Redefinir | Сбросить | 重置 | 重設 |  |
| Compare | Vergleichen | Comparar | Comparar | Comparer | Confronta | 비교 | Comparar | Сравнить | 比较 | 比較 |  |
| Check | Prüfen | Comprobar | Comprobar | Vérifier | Verifica | 확인 | Verificar | Проверить | 检查 | 檢查 |  |
| Search | Suchen | Buscar | Buscar | Rechercher | Cerca | 검색 | Buscar | Поиск | 搜索 | 搜尋 |  |
| General | Allgemein | General | General | Général | Generale | 일반 | Geral | Общие | 常规 | 一般 |  |
| Enable | Aktivieren | Activar | Activar | Activer | Attiva | 사용 | Ativar | Включить | 启用 | 啟用 |  |
| Disable | Deaktivieren | Desactivar | Desactivar | Désactiver | Disattiva | 끄기 | Desativar | Отключить | 禁用 | 停用 |  |
| Enabled | Aktiviert | Activado | Activado | Activé | Attivato | 활성 | Ativado | Включено | 已启用 | 已啟用 |  |
| Disabled | Deaktiviert | Desactivado | Desactivado | Désactivé | Disattivato | 비활성 | Desativado | Отключено | 已禁用 | 已停用 |  |
| Minimum | Minimum | Mínimo | Mínimo | Minimum | Minimo | 최소 | Mínimo | Минимум | 最小值 | 最小值 |  |
| Maximum | Maximum | Máximo | Máximo | Maximum | Massimo | 최대 | Máximo | Максимум | 最大值 | 最大值 |  |
| Description | Beschreibung | Descripción | Descripción | Description | Descrizione | 설명 | Descrição | Описание | 描述 | 說明 |  |
| Name | Name | Nombre | Nombre | Nom | Nome | 이름 | Nome | Название | 名称 | 名稱 |  |
| Scale | Skalierung | Escala | Escala | Échelle | Scala | 크기 비율 | Escala | Масштаб | 缩放 | 縮放 |  |
| Any | Beliebig | Cualquiera | Cualquiera | N'importe laquelle | Qualsiasi | 아무거나 | Qualquer | Любое | 任意 | 任一 |  |
| All | Alle | Todas | Todas | Toutes | Tutte | 모두 | Todas | Все | 全部 | 全部 |  |
| Always | Immer | Siempre | Siempre | Toujours | Sempre | 항상 | Sempre | Всегда | 总是 | 總是 |  |
| None | Keine | Ninguno | Ninguno | Aucun | Nessuno | 없음 | Nenhum | Нет | 无 | 無 |  |
| Yes | Ja | Sí | Sí | Oui | Sì | 예 | Sim | Да | 是 | 是 |  |
| No | Nein | No | No | Non | No | 아니요 | Não | Нет | 否 | 否 |  |
| AND | AND | Y | Y | ET | AND | 그리고 | E | И | 与 | 且 | Logic operators stay short and capitalized where the language allows. |
| OR | OR | O | O | OU | OR | 또는 | OU | ИЛИ | 或 | 或 |  |
| NOT | NOT | NO | NO | NON | NOT | 아님 | NÃO | НЕ | 非 | 非 |  |

## Terms found inside longer strings

These words have no entry of their own. The example string shows how each locale renders the term in context.

| Term | Example | deDE | esES | esMX | frFR | itIT | koKR | ptBR | ruRU | zhCN | zhTW | Note |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Buff | `Buff Present` | Stärkungszauber vorhanden | Beneficio presente | Beneficio presente | Amélioration présente | Effetto benefico presente | 강화 효과 있음 | Bônus presente | Есть положительный эффект | 存在增益效果 | 存在增益效果 | Use the client's word for a beneficial aura. |
| Debuff | `Debuff Present` | Schwächungszauber vorhanden | Perjuicio presente | Perjuicio presente | Affaiblissement présent | Penalità presente | 약화 효과 있음 | Penalidade presente | Есть отрицательный эффект | 存在减益效果 | 存在減益效果 | Use the client's word for a harmful aura. |
| Own | `Own Buff` | Eigener Stärkungszauber | Beneficio propio | Beneficio propio | Amélioration personnelle | Effetto benefico proprio | 자신의 강화 효과 | Bônus próprio | Свой полож. эффект | 自身增益 | 自身增益 | Cast by the player. |
| Clone | `Clone to edit` | Zum Bearbeiten klonen | Clonar para editar | Clonar para editar | Cloner pour modifier | Clona per modificare | 복제해서 편집 | Clonar para editar | Клонировать для правки | 克隆以编辑 | 複製以編輯 | Make an editable copy of a Built In. |
| Remove | `Remove condition` | Bedingung entfernen | Quitar condición | Quitar condición | Retirer la condition | Rimuovi condizione | 조건 제거 | Remover condição | Удалить условие | 移除条件 | 移除條件 |  |
| Export | `Export archive` | Archiv exportieren | Exportar archivo | Exportar archivo | Exporter l'archive | Esporta archivio | 보관함 내보내기 | Exportar arquivo | Экспорт архива | 导出存档 | 匯出封存 |  |
| Profile | `Profile archive` | Profilarchiv | Archivo del perfil | Archivo del perfil | Archive du profil | Archivio del profilo | 프로필 보관함 | Arquivo do perfil | Архив профиля | 配置文件存档 | 設定檔封存 | The saved-variables profile. |
| Announcement | `Announcement` | Ankündigung | Anuncio | Anuncio | Annonce | Annuncio | 알림 | Anúncio | Оповещение | 通报 | 通報 |  |
| Switch priority | `Switch priority` | Wechselpriorität | Prioridad de cambio | Prioridad de cambio | Priorité de bascule | Priorità di cambio | 전환 우선순위 | Prioridade de troca | Приоритет переключения | 切换优先级 | 切換優先順序 |  |
| Switch condition | `Switch condition` | Umschaltbedingung | Condición de cambio | Condición de cambio | Condition de bascule | Condizione di cambio | 전환 조건 | Condição de troca | Условие переключения | 切换条件 | 切換條件 |  |

## Never translated

Product, site and addon names; slash commands and their arguments (`/rm set`, `/rm debug glow`); condition and field identifiers inside `{{braces}}`; format placeholders (`%s`, `%d`); color codes (`|cffffd100...|r`); the word "Rotation Master". Names the tools never flag as untranslated:

AceGUI, AzeriteUI, Bartender4, Battle.net, BigWigs, Blizzard, ButtonForge, CurseForge, DBM, Discord, Dominos, EllesmereUI, ElvUI, ExtendedCharacterStats, FarmingBar, GitHub, Hekili, Icy Veins, LibRangeCheck, LittleWigs, LuaWorkbench, LUI, Masque, MaxDps, Mobalytics, MobInfo2, Musca Auras, NextActionTBC, Questie, Rotation Master, Shockadin, SimulationCraft, SoD, Titan Panel, TotemTimers, Tukui, Wago Addons, Warcraft Tavern, WeakAuras, WoWAce, Wowhead, WoWInterface, Simulator, simulator, WowUp Hub, Zockify.
