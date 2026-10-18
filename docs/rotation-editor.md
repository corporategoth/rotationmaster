# Rotation editor

Open `/rm config` and select Rotations. Default and custom rotations share the same view. Defaults are read-only: inspect their cards and conditions, enable or disable them, or use Clone to edit. A clone is independent and keeps its original source for comparison.

Custom rotations use a private draft. Apply saves the draft; Discard restores the saved rotation. Undo and Redo step through structural, field and condition edits. Closing the window keeps the draft available during this session. Apply before `/reload` or logout to retain edits across sessions. Switching rotations or opening comparison/transfer while a draft is dirty offers Apply, Discard or Cancel.

The header has the rotation name, then history and metadata controls. Metadata opens a form with a larger description box and optional Author, Realm, Email, Website and Version fields. Enable/disable and Delete are docked at the right. New rotation, Duplicate, Import/Export and Compare rotations live in a two-row grid below the rotation roster. Use changes stages metadata and description together as one undoable draft edit; the rotation’s Apply button saves them. Cancel or Escape abandons form edits. Defaults show the same form read-only. Retained source titles and links stay separate; contact fields are never filled automatically. Deleting a whole custom rotation requires confirmation and cannot be undone; deleting a card in a draft can be undone. Defaults and the implicit fallback rotation cannot be deleted.

The switch condition appears below the toolbar as a clickable summary. Click its text to open its condition tree; click the heading to hide or show that summary. Opening an untouched fallback or read-only default does not create unsaved changes. The fallback rotation is selected when no other rotation matches and has no editable switch condition.

## Independent cooldowns

Cooldown cards appear above the ordered rotation in a responsive grid. Each block heading can collapse its entire block into one row; the editing buttons are replaced by a Click to expand hint while hidden. Expand all and Collapse all control the cards, followed by the Add buttons. Cooldowns have no ordering arrows. They can all highlight independently when their conditions are met. Their visual position does not impose a sequence. Add cooldown creates a new reminder; drag the control into an insertion gap to choose its place.

The chevron toggles Summary and Name only. Click action text to replace the action summary with fields while retaining the editable condition below them; the double-down chevron returns from fields to Summary. In the condition editor, click condition description text for fields. Name-only cards retain drag and expansion. Collapse all keeps branch paths visible; the separate branch-path icon folds a subtree when desired. Expand all restores summaries and paths. Mode/enable pills sit beside Help on the top row. Cooldown summaries show the effect on their spell icon; action details keep that leading spell icon as their live preview. Exact rank uses a checkbox. Labels sit to the left of fields and center vertically against their controls, magnification uses a numbered slider, and the direction pad adjusts numeric offsets (Shift moves ten pixels), and Center resets to CENTER/0/0. A color swatch opens an owned HSV/alpha picker with live draft preview; RGBA inputs use two rows beside a swatch spanning both rows. Channels accept decimal values from 0 to 1. Offset values are stacked beside the directional pad; Default resets return the corresponding settings to the profile. Cancel restores the previous pending values, including unfinished input. Sounds come from LibSharedMedia with a play preview. Blank optional overrides inherit the profile settings.

## Ordered actions and branches

Add action appends an action; drag it into a gap to insert elsewhere. Click a plain-text card name to rename it in place; the input replaces the label at the same position, and clicking outside finishes editing within the draft. Click its action to change action fields, or click the condition summary to inspect/edit its guard. Spell identities support hover tooltips; Shift-click an action to open its spell link. Selected spells keep their icons in action details. Actions implicitly require the learned spell or carried item, readiness, resources and valid range.

Add branch creates a conditional decision. Drag Add branch into a gap to put it before existing steps. Inserting a branch moves all following siblings into its True arm. False is on the left with red connectors; True is on the right with green connectors. An evaluated branch has a white border. Its mode pill cycles through Evaluate condition, Always true and Always false. Forced modes skip guard evaluation; cards in an unreachable arm are gray.

Dragging an ordered card into a different branch arm carries the rest of its source sequence with it, including every nested branch subtree. A destination inside any carried subtree is refused. Moving within the same sequence or using Up/Down reorders the selected card and its own nested subtree. Cooldowns remain independent.

A branch finishes its selected arm and then rejoins any siblings following that branch. Stop ends the ordered sequence; implicit Attack may still apply unless the Stop explicitly suppresses it. Independent cooldowns continue to be evaluated.

Undo reverses an insertion, captured tail or grouped move as one edit. Apply validates both arms, including currently unreachable cards, without running custom condition code. Incomplete or unavailable cards have red borders and remain editable when validation refuses Apply. A warning above the switch condition explains why the rotation cannot run; click it for diagnostics.

Dragging displays a floating card preview beside the pointer and highlights one valid insertion gap. A drag release does not also activate the source button. Both axes scroll when needed. RM positions and drags its own scrollbar thumbs so downward/rightward motion always increases the scroll offset. Thumbs reflect how much of the content is visible; click empty track space to page in that direction, or use the wheel or small arrows for smaller movements. Window scaling applies on slider release and also reaches RM child windows.

In the condition editor, Add condition and Add group append to the whole expression’s end regardless of the selected card; drag either button into a gap to choose a nested position. All/Any pills are yellow. Disabled cards retain their condition descriptions in gray, and icon-only controls have no button backgrounds. Empty rotation branch arms keep their colored path continuous.

Collapsed section hints are clickable, including Switch condition. Compact unnamed conditions show their readable summary; clicking a compact title opens Summary. Named steps supply the condition editor title. Generated action titles omit hyperlink brackets while actionable spell descriptions retain tooltips/links. Disabled card summaries keep their ordinary wording. The condition dialog shares the main window’s dark chrome, compact single-row contextual header and footer.

Apply clears highlights using the previously saved action identities before evaluating the new settings, so changing an effect does not require switching rotations. Textured overlays inherit their target’s frame strata and sit one level above its icon, including in configuration dialogs.

Leaf and grouped conditions initially open at Summary; click condition text to show field controls. Noninteractive condition-edit buttons and compact card titles use plain spell names without hyperlink brackets. Actual spell links in the condition editor retain their link behavior. Card hover guidance is rebound on every render. Metadata opens at the workbench dialog layer and uses the standard RM Escape handling, including clients without the special-frame registry.

The condition editor uses a single-row header. Its heading is “Rotation Master: <step name>”, including an unfinished rename or the displayed spell/action name. The right side identifies Rotation, Cooldown or Switch condition; the footer shows the rotation name left aligned. Metadata uses matching chrome with a Metadata context label.

Metadata sits to the right of the rotation name, above Enabled/Delete. Its description is a multiline scrolling field; the dialog grows for actual source information and omits that section when absent. Use changes stages details in the rotation draft; Cancel/Escape restores the dialog’s opening values. Apply the rotation to save.

Up/Down controls are disabled at each sibling list boundary, including inside branches and condition groups. Group arrows remain on the left; the child connector starts below them and keeps its horizontal arms. Split group sits between Duplicate and Delete on the right. Compact unnamed condition groups show All of/Any of; named groups keep their name.

## Tags and search

Metadata includes a comma-separated Tags field. Any personal labels are supported, including tags such as AOE, PVP, Raid or MyLittlePony; quote a tag containing a comma and double any quote inside it. Empty text removes all tags. Up to 64 tags of 64 UTF-8 characters each are supported. Duplicate tags use the first spelling and compare without ASCII case differences. Tags are metadata and do not change switch conditions or recommendations.

Defaults show their tags read-only. Clones and imports inherit manifest tags unless their editable body explicitly supplies tags; an empty body list suppresses inheritance. Editing tags participates in the rotation draft, Apply/Discard and Undo/Redo. Cancel in Metadata restores its opening values. Leaving an inherited value unchanged keeps it absent from the body, so merely viewing or confirming a clone does not create a difference. Exporting an edited sourced rotation reflects its current tags without changing historical source records.

The roster has a searchable tag filter alongside All/Defaults/Custom ownership filtering. The existing search box matches name, description, tags, provided author/realm/contact/version metadata and source citation titles/URLs. No player or contact information is filled automatically. Filters combine without changing or discarding the selected editor. New clears active filters so its pending entry is visible. Tag changes have a readable side-by-side row in rotation comparisons.

## Auto-switch priority

Metadata includes Switch priority, a whole number from -100000 to 100000. Larger numbers win among custom rotations or among packaged defaults. Missing/blank priority means zero. Equal priorities use name, then stable identity, so equal names no longer depend on table iteration order. The roster shows each candidate’s priority; the saved fallback has no competing rank.

Custom rotations retain precedence over packaged defaults, and a valid saved fallback still takes precedence over a packaged recommendation. Priority does not override applicability, disabled state, invalid conditions, manual selection or the Disable auto-switching setting. Invalid priority makes a body unavailable to automatic selection. Metadata edits stay private until Apply and are undoable. The graphical diff shows priority changes. Existing rotations without priority retain their alphabetical behavior. This introduces explicit precedence without running additional condition callbacks to detect simultaneous matches.

`/rm check` reports invalid saved priorities without changing them. Explicit `/rm repair` clears a malformed priority back to the implicit zero, including on branch-based rotations. Graphical comparisons treat absent and explicit zero as equal; the diagnostic raw diff preserves their storage difference.

## Aura ranks

Buff/debuff presence, time and stack predicates offer Match all ranks. Exact numeric spell IDs remain exact unless this option is selected. The opt-in also matches a readable aura name against the authored ID’s readable localized spell name. Named legacy aura predicates retain their existing name matching. Aura pickers preserve numeric selections so disabling the option does not silently keep name-family behavior. No raw spell IDs are needed in the displayed search or icon.

Missing metadata and restricted identity are unavailable, including under NOT. An observed empty aura list remains ordinary absence. Different spells with the same localized name can match in family mode; use exact IDs when the distinction matters. Own-aura filtering and time/stack behavior are unchanged. Built-in condition checkboxes now use RM’s flat control through a shared layout adapter; AceGUI still supplies legacy field layout and custom-widget compatibility.

## Classic talent trees

Primary Talent Tree selects the unique Classic talent tree with the most positive points. Talent Tree Points compares the points in a selected tree and can explicitly test zero. Both use readable player metadata from the existing tree adapter. They do not interpret the saved rotation slot as a major spec.

No spent points, tied positive maxima or incomplete/unreadable tree metadata cannot establish a primary tree; that condition is unavailable, including under NOT. Tier-grid and trait layouts are unsupported by these tree predicates. New-profile defaults place the conditions in Character and allow them in switch conditions; existing custom category/switch lists are preserved and can be adjusted in Conditions management. Hybrid builds can combine tree-point and individual-talent predicates rather than treating a primary tree as a role assignment. References remain inspectable on unsupported clients. These are authoring primitives; they do not add later-level or other-class default packs.
