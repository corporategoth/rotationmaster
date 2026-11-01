# Rotation Master: CurseForge library audit

Compared with the files in the bundled `Libs` runtime files, using the release archives published on CurseForge. Runtime relevance is determined by `embeds.xml`; unused legacy library directories are not treated as active dependencies. Library minor numbers identify LibStub revisions; they do not by themselves prove compatibility with a particular client.

| Runtime dependency | CurseForge comparison | Decision |
| --- | --- | --- |
| AceAddon, AceConsole, AceEvent, AceTimer, AceLocale, AceSerializer, AceComm (including ChatThrottleLib), AceBucket, CallbackHandler, LibStub | All bundled Lua files match [Ace3 Release-r1403](https://www.curseforge.com/wow/addons/ace3/files/8629919) after normalizing line endings and expanded SVN `$Id$` comments. | Keep. |
| AceDB | Bundled minor 39 differs from CurseForge Ace3 r1403 minor 33, including character/realm identity changes. | Keep the newer bundled revision; replacing it risks profile identity and is not a safe update. |
| LibDBIcon | Bundled Lua matches [v12.1.2](https://www.curseforge.com/wow/addons/libdbicon-1-0/files/9278071) byte for byte. | Keep. |
| LibSharedMedia | Bundled Lua matches [v12.1.3](https://www.curseforge.com/wow/addons/libsharedmedia-3-0/files/9277931), revision r184. Earlier local r182 was updated during this session. | Updated to r184. |
| LibCompress | Bundled Lua matches [r87-release](https://www.curseforge.com/wow/addons/libcompress/files/9058043) after line-ending normalization. | Keep. |
| LibDataBroker | Bundled Lua matches [v1.1.4](https://www.curseforge.com/wow/addons/libdatabroker-1-1/files/370771) after line-ending normalization. | Keep. |
| LibCustomGlow | Bundled minor 25 differs from [v1.0.4](https://www.curseforge.com/wow/addons/libcustomglow/files/5558702), minor 19. The published archive lists Retail 11.0.2, not the current client set. | Keep the newer bundled revision; do not downgrade. |
| LibRangeCheck-3.0 | Bundled minor 38 differs from [v1.0.17](https://www.curseforge.com/wow/addons/librangecheck-3-0/files/5663743), minor 26. That archive lists Retail 11.0.2 and Classic 1.14.3, not current MoP. | Keep the newer bundled revision; do not downgrade. |
| LibClassicDurations | Bundled core minor 71 differs from [1.69a-classic](https://www.curseforge.com/wow/addons/libclassicdurations/files/3288614), minor 69; two data files match and two differ. The release targets Classic 1.13.5. | Keep the newer bundled revision. RM only registers the library on Classic when its required aura and combat-log APIs exist. |
| ThreatClassic-1.0 | No matching standalone CurseForge release was found. The embedded library is legacy; [its successor](https://www.curseforge.com/wow/addons/threatclassic2) is a different threat-meter addon/library and is not a drop-in replacement. | Keep pending a separate compatibility assessment; do not substitute an unrelated archive. |

The CurseForge pages and archives are the comparison source. The audit does not claim that every dependency has been verified in every game client, and it does not treat a repository HEAD as a CurseForge release. The optional LuaWorkbench integration is a separate issue: the installed standalone v1.2.2 does not expose an independent editor-engine API compatible with RM's current integration.
