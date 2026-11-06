# Tribe creation: current direction

Updated 6 November 2026 following the user's correction.

The reusable tribe definition contains only a permanent ID and display name.
All nations start tribal. There is no playable character or dynasty simulation.

Technology, national skill choices, government reform, laws, taxation, faith,
culture, traditions and AI preferences must not be preselected in the tribe tool.
Their exact gameplay treatment is future work; development choices belong to the
running game. Population uses a single type with recruitable manpower drawn from
it. Province ownership, population and live resources belong to game/scenario state.

The separate tribe creator supports ID/name editing, duplication, search, saving
and administrative archive/restore. The old technology/skill planner is retained
as a detached prototype for future in-game progression, not attached to tribes.
The six fictional starting tribes contain only IDs and names, without stat bonuses.

Historical research below is reference material, not an approved field list.

## Research scope

This compares the major relevant design families, not every Paradox-published
game, expansion, historical patch or Civilization spin-off. Older series entries
are background; the evidence below concentrates on systems useful to this game.
Developer descriptions and manuals establish the comparisons. The proposed
fields and balancing numbers below are our design choices, not copied rules.

| Reference | Relevant approach | Lesson for our creator |
| --- | --- | --- |
| Europa Universalis IV | National ideas represent national legacy and ambitions. | Give countries a few identifiable traditions. |
| Europa Universalis V | Nations have living populations, economic and logistical challenges. | Derive strength from the world and simulation. |
| Crusader Kings III | Dynasties and rulers persist through succession and changing realms. | Use realm institutions as inspiration; no playable characters or dynasties. |
| Imperator: Rome | Government, characters, population culture/religion and military traditions interact. | Closest ancient-world reference for separating these systems. |
| Victoria 3 | Population groups underpin society, industry and political change. | National totals should come from local populations and production. |
| Hearts of Iron IV | Industry, technology, military organization and political choices shape war-making capacity. | Keep current forces and technology separate from country identity. |
| Stellaris | Empire creation combines ethics, origins and civics. | Use modular choices and compatibility rules. |
| Civilization III | Civilization qualities and advantages define different starting identities. | Make differences understandable during creation. |
| Civilization IV | Civilizations, starting technologies, unique units and leader traits are distinct. | Attach our build choices to the nation rather than a leader. |
| Civilization V | Special abilities and unique units/buildings distinguish civilizations. | Prefer a few meaningful differences over dozens of generic sliders. |
| Civilization VI | Civilization traits, leader traits, units and infrastructure are separate. | Keep national identity and unlocks modular; no leader system planned. |
| Civilization VII | Leaders and civilizations have attributes, abilities and agendas; civilization changes are part of its age structure. | Distinguish gameplay benefits from AI priorities; no need to adopt its age-switching model. |
| Age of Wonders 4 | Culture and society traits contribute to faction identity and affinity. | Compose countries from reusable definitions. |
| Old World | Nations, families and leaders have distinct roles. | Internal social pressures can matter without a dynasty simulation. |
| Total War: Rome II | Faction traits have effects; political parties and characters are another system. | Keep national modifiers separate from internal politics. |
| Humankind | Culture definitions reference affinities and legacy traits. | Use reusable trait records rather than hard-coded country scripts. |

## Sources

- [EU IV overview](https://www.paradoxinteractive.com/games/europa-universalis-iv/about)
- [EU V overview](https://www.paradoxinteractive.com/games/europa-universalis-v/about)
- [CK III overview](https://www.paradoxinteractive.com/games/crusader-kings-iii/about)
- [Imperator overview](https://www.paradoxinteractive.com/games/imperator-rome/about)
- [Victoria 3 overview](https://www.paradoxinteractive.com/games/victoria-3/about)
- [HOI IV overview](https://www.paradoxinteractive.com/games/hearts-of-iron-iv/about)
- [Stellaris developer diary 299](https://store.steampowered.com/news/posts/?appids=281990&enddate=1683630012&feed=steam_community_announcements)
- [Civilization III manual](https://usermanual.wiki/Document/Civilization3Manual.1841378190.pdf)
- [Civilization IV manual](https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/3900/manuals/manual.pdf)
- [Civilization V manual](https://well-of-souls.com/civ/Civ_V_Manual_EN_Combined.pdf)
- [Civilization VI manual](https://downloads.2kgames.com/civilization/vi/manuals/eu/CIV_VI_25TH_ONLINE_MANUAL_ENG.pdf)
- [Civilization VII official patch notes: attributes, abilities and agendas](https://support.civilization.com/hc/en-us/articles/55328611080339-Civilization-VII-Patch-Notes-September-15-2026)
- [Age of Wonders 4 affinity developer diary](https://www.paradoxinteractive.com/games/age-of-wonders-4/news/age-of-wonders-4-dev-diary-2)
- [Old World official nations reference](https://wiki.hoodedhorse.com/Old_World/Nations)
- [Rome II official faction selection manual](https://r2enc.totalwar.com/en/manual/single-player/0014_enc_page_campaign_play_faction_select/)
- [Humankind official modding guide](https://medias.games2gether.com/universes/humankind/mods/HUMANKIND_Official_Modding_Guide.pdf)
