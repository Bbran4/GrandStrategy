# Country creator: research and proposed design

Research date: 6 November 2026. Target: Viking-inspired tribal societies developing into medieval nations.
Status: user direction recorded; detailed mechanics below remain proposals, not implemented gameplay. The creator must be a separate scene
from the map editor. Countries must support both human and AI control.

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

## Proposed data ownership

### Country definition: reusable across maps

- Stable ID, display name, adjective/demonym, description.
- Map color, secondary color, flag/emblem asset.
- Default culture and faith references. These do not overwrite province populations.
- All countries begin as tribes. A tribal institution profile and starting laws
  describe initial organization; later government reform happens during play.
- National skill-tree reference and optional starting tradition references.
- No playable ruler, character stats, dynasty or personal succession system.
- AI profile reference and optional overrides.
- Eligible for player selection; eligible for AI spawning. These are independent
  permissions, not permanently assigned controllers.

Possible later reforms include centralized kingdoms and merchant republics.
Feudal institutions are one possible medieval development, not a compulsory
upgrade. Exact government branches and reform requirements are undecided.

Culture and faith are separate definitions and can be shared by multiple countries.
Neither should grant automatic judgments about intelligence, morality or inherent
population quality. Institution and tradition effects should be explicit game rules.

### Scenario: ties a country to a map and start date

- Country ID, capital province ID, owned provinces, controller assignments if needed.
- Starting tribal laws and institutional configuration. Standard starts must
  enforce tribal government for every country.
- Treasury and debt in currency units; initial legitimacy and stability (0–100).
- Unlocked technologies, national skill unlocks, starting forces and diplomatic relationships.
- Subject/overlord relationships and optional claims.
- Local population, wealth, buildings and resources belong to province setup.

The creator can save a country without any map loaded. Capital and province
ownership are assigned in scenario/map tooling using that stable country ID.
Current ownership controls should eventually select from the country library.
Existing ad hoc owner IDs must be migrated explicitly, never silently discarded.

### Runtime state: changes during play

- Current treasury, debt, stability, authority, institutions and active laws.
- Population: one unified population type, counted in each province and summed
  nationally. This interprets "single pop unit" as a single population category;
  people represented by one unit remains an explicit scale decision. No separate
  citizen, peasant, noble or slave population classes are planned.
- Tax income: local taxable production/wealth × tax policy × collection/control,
  then applicable modifiers. Monthly scale and exact formula remain to be designed.
- Recruitable manpower: eligible population × recruitment rules minus committed
  forces, with recovery and losses handled by the military system.
- Army/naval strength: actual units, equipment, readiness and supply.
- Food balance, trade income, administrative demand, research output and unrest:
  derive from the appropriate local and national systems once implemented.

Show these totals in a scenario preview when those systems exist. Do not fabricate
an editable permanent national population, income or military-strength score.

## Technology and national skill trees

Confirmed: two distinct progression systems attached to the nation.

- Technology tree: shared practical knowledge, unlocking buildings, equipment,
  production methods and prerequisites for institutional reforms. Suggested
  branches: agriculture, crafts, warfare, seafaring and administration.
- National skill tree: deliberate specialization for unique builds. Suggested
  branches: raiding, commerce, settlement, warfare and governance. Deep branches
  should contain meaningful alternatives so every country does not converge on
  the same completed build. Exact costs, branching and respecialization are open.

Proposed distinction: research earns technological progress; national advancement
comes from a separate, capped progression budget with multiple viable earning
routes. Raiding must not be the only way to advance. Avoid uncapped repeat-action
experience farms. Neither currency nor earning formula is approved yet.

Technology unlocks possibilities; national skills specialize their use; laws
choose how society operates. Reforms need both institutional prerequisites and
sustainable costs. Tribal nations should remain viable while medieval institutions
bring benefits and new obligations. A calendar date alone should not force reform.

## Laws, taxation and recruitment

Confirmed: laws and taxation are part of nation management.
Proposed law groups: authority/council powers, taxation, military service, land
tenure, commerce and religious policy. Some laws require technology or reform.
Law changes should show consequences and transition costs before confirmation.

Higher taxation should increase revenue but reduce household prosperity or
stability. Military service can range from temporary levies to a standing force;
more mobilization reduces productive civilian labor and increases supply costs.
Use one population ledger: recruitment transfers people into service, demobilization
returns survivors, deaths reduce total population. Wounded recovery and eligibility
must not create extra people or count recruits twice. Recruitable manpower is a
recovering subset of population, not a second independent population stock.

## Traditions and modifiers

Initial recommendation: a small number of starting traditions from a shared catalogue,
with most national specialization earned through the national skill tree.
For example, Merchant Networks might improve trade income; Frontier Garrisons
might reduce fort upkeep. Exact effects are provisional until those systems exist.
An unavailable effect must be labelled as inactive, not presented as working.

Each tradition needs an ID, name, description, effect list, requirements and
incompatibilities. Each effect needs a known stat ID, operation, value and scope.
Use percentage-point changes only for rates; distinguish additive percentages
from multiplicative factors. Show an effect breakdown rather than silently stacking.

Start with modest bonuses (roughly 5–10% as a balancing hypothesis). Government
sets institutional rules; traditions add specialties; geography creates practical
strengths and weaknesses. No compulsory point budget for historical authoring.
A balanced custom-country mode can impose one later.

## AI profile

Suggested preferences, each 0–100 with neutral default 50:
aggression, expansion, diplomacy, trade, military investment, risk tolerance.
These are decision weights, not income/combat bonuses, probabilities or a complete
AI implementation. Situation and threat assessment must override preferences.
The same country rules apply whether controlled by human or AI; difficulty
adjustments belong in game settings. Human control suspends AI decision-making,
not the country's laws or traditions.

## Separate creator scene

Left: searchable country library and New/Duplicate controls.
Center: tabs for Identity, Tribal Society, National Build, Starting Laws, AI Behavior.
Right: flag/color/name preview and validation summary.
Bottom: Save, Revert and return/navigation controls, with unsaved-change handling.

Save reusable definitions under `data/countries/`, with separate shared catalogues
for governments, traditions and AI profiles. Use a schema version and stable IDs.
Validate duplicate IDs, malformed colors, unknown references, invalid numbers,
missing assets and incompatible choices. File selection must not execute scripts.
Use ID-based filenames and controlled asset references, not arbitrary entered paths.
Duplication creates a new ID; renaming display text preserves references. Warn or
block deletion when a known scenario references the country.

First implementation should support country CRUD, colors/emblems, tribal profiles,
culture/faith IDs, national-tree reference, starting laws/traditions, AI preferences
and player/AI eligibility. All new countries start tribal; the creator must not
present medieval governments as standard starting options.
Label future simulation effects honestly. Connect the saved library to ownership
selection next, followed by scenario capitals and starting-state editing.

## Implementation progress

The standalone country workshop and saved-country province picker are implemented.
The workshop now includes an interactive technology/national skill planner with
30 data-defined nodes, prerequisites, separate point budgets, exclusive national
specialties, proposed effect totals and cascading refunds. Plans save with country
definitions without granting starting unlocks. Old country files remain valid.
Live research generation, skill-point earning, law/economy effects and reforms
remain future simulation work. See the README for running and testing the tools.

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
