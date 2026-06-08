# Story Rework — Northwind Analytics (2026-06-08)

Brainstormed direction to tighten the story and give a **diegetic justification for the shop/upgrades** that the current story hand-waves ("he bought a bucket with his own money"). Builds on — does not replace — the existing satire in `story-and-satire.md` and `story-content-guide.md`; most existing newspapers / cave-lore / billboards / ending are reused.

## The one-line premise (unchanged spine)
The government promises to "drain the swamp," hires one broke nobody (the player) with a $500 budget expecting him to fail quietly. He succeeds. Every pool he drains unearths buried elite corruption they desperately wanted hidden. They panic and sabotage him.

## The new layer — who's actually funding you
A fictional, **unnamed foreign government intelligence agency operating under the cover name "Northwind Analytics" (NA)** — a banal-sounding data-analytics consulting firm, which is exactly what a front would be. NA secretly funds and equips the player because every drained pool surfaces kompromat on US elites. **Their goal is NOT to expose it — it's to privatize it as future blackmail leverage over those same politicians.** So nobody in power wants the truth public: the US wants it buried, NA wants it owned. The player is the disposable middleman who actually digs it up.

This justifies the entire economy: you're paid for what you surface (water drained + documents recovered), and your gear is funded by your patron. The clean incremental loop is unchanged; it finally has a reason.

## Three story-delivery channels (the rhetorical triangle)
All narrative flows through exactly three voices, each with its own channel, tone, and arc. The player pieces together the truth from the gaps between them.

1. **The US Government (local → federal).** The power covering it up. Escalates from petty local officials (Mayor Kickback) to Congress to the CIA. Tone: spin, denial, self-congratulation, then panic. Channels: campaign **billboards**, official **warning signs**, the **wanted poster**, sabotage (water refills, **helicopter** flyovers), and the cover-up ending. *(Reuses existing billboards/signs/consultant-report content.)*
2. **The News (local → national).** The press reporting on the drainer. Local = quirky human-interest ("local man drains puddle"); national = establishment spin as it escalates to "the Atlantic is draining." Tone: satirical, sensational, increasingly alarmed. Channel: **newspaper popups** at milestones (+ optional HUD news ticker for ambient beats). *(Reuses the existing 10 milestone newspapers + intro/credits.)*
3. **Northwind Analytics (NA).** Your secret patron/handler. Tone: friendly → transactional → menacing; deadpan foreign case-officer who mangles idioms. Channels: **burner phone (texts)** + **dead-drop box** (below). Signs **"— a Friend"** until the Stage-3 reveal, then **"— NA."**

*(Note: Congressman Goodwell's hero→villain arc is DROPPED in this rework to keep the channels clean. Cut or flatten him; the three voices above carry the story.)*

## NA's two channels — phone + dead-drop
- **Burner phone (texts) = messages/story.** The ambient handler voice; messages arrive as you play (no walking), keyed to progress. This is NA's narrative channel and fills the "long stretches with no story" dead-air the roadmap flagged.
- **Dead-drop box = cool upgrades + extra money.** A physical crate/mailbox at the swamp edge where NA leaves **special/unique gear you can't buy in the shop** plus **bonus cash injections** — delivered as rewards for progress and for turning in recovered intel. This is distinct from the baseline shop (Swamp Mike's), where you spend ordinary earned money on standard tool tiers. So: **shop = baseline grind; dead-drop = NA's premium reward channel.**

## NEW mechanic — Intel as payout (fixes empty caves)
"Uncovering secrets" becomes literal income, not just flavor:
- Buried **documents** are found by draining pools and exploring caves (the cave-lore docs, the lagoon's "waterproof containers," etc. — content already written).
- Turn them in (at the dead-drop / via phone) → **bonus money + special dead-drop upgrades, and the handler reacts to them in texts.** This gives caves/loot a reason to exist (`loot_data` is empty everywhere today) and ties the satire payloads to progression.
- Baseline loop (drain → get paid → buy tools at shop) stays intact; intel is a bonus stream feeding the dead-drop channel.

## The slow-burn NA arc (mapped to the existing 10 pools / 4 acts)
Player + audience realize *together* that the "friend" is foreign intelligence.

**Stage 1 — "A Friend" (Puddle→Marsh / Act 1 "Nobody cares"):** Anonymous benefactor. First dead-drop + unsigned text after your first sale. Warm, mysterious — you assume a sympathetic citizen.
- *"You do good work. Tools waiting in the drop box. — a Friend"*
- *"Do not thank me. Just keep draining. The water hides much."*

**Stage 2 — "Something's off" (Bog→Lake / Act 2 "They're watching"):** Drops keep coming, suspiciously well-funded, and the asks begin — photograph/recover documents. Idiom slips. The US starts sabotaging you (existing helicopters/refills).
- *"Excellent labors, com— friend. Photograph all documents you recover."*
- *"Funds in the drop box. Buy the bigger bucket. We believe in you."*
- *"The papers from the marsh — where are they now? Asking for no reason."*

**Stage 3 — The mask off (Reservoir→Bayou / Act 3 "The cover-up"):** Undeniable. The handler drops the pretense and signs "— NA." You realize you've been feeding a rival power the elites' kompromat, while your own government hunts you.
- *"Enough pretense. Northwind requires the Guest List. You will deliver it. — NA"*
- *"Your government wants you in a cell. We want you employed. Choose wisely. — NA"*

**Stage 4 — The Deep End (The Atlantic + endgame / Act 4):** You drain the Atlantic and recover **the Guest List**. Both powers want it; both need you gone.

## The climax — a real choice, two roads to the same grave
At the island, with the Guest List, the player chooses — and **both outcomes end with the drainer eliminated** ("whacked"), because surfacing the truth makes you expendable to everyone who profits from controlling it. Keep the whacking **darkly comedic and off-screen** (black bag, cut to a newspaper, a single SFX over black) — Steam-safe, on-brand.

- **Hand the Guest List to NA → NA whacks you.** You're the loose end who knows too much. They vanish you; NA now quietly owns the same politicians (new bosses, same swamp). Ending newspaper: *"DRAINER VANISHES — Officials Decline to Comment."*
- **Refuse / destroy it / swing the hammer → the CIA whacks you.** A foreign asset gone off-script + a threat to the cover-up. This is essentially the *existing* arrest/cover-up ending: "it was all fake," everyone pardoned, swamp refilled — reframed as one of the two roads.

Identical lesson: **the individual who exposes the truth is disposable to every power that profits from owning it.**

## What to reuse vs. touch
- **Reuse as-is:** all 10 milestone newspapers, billboards, consultant reports, most cave-lore docs, sabotage/helicopter/wanted-poster beats, the island confrontation + "it was all fake" refill ending (now = the CIA road).
- **Add:** burner-phone text system + dead-drop box; ~4 stages of NA texts; intel turn-in payouts; the NA reveal beats; the second (NA) ending road + the island choice point.
- **Cut/flatten:** Congressman Goodwell's arc (dropped from this rework).

## Mechanics implications (to spec in a build pass)
1. **Phone/text system** — message queue keyed to drain progress + pool completions + intel turn-ins; HUD notification + a readable log. (Could extend the existing newspaper-popup system.)
2. **Dead-drop box** — interactive node at the swamp edge: dispenses special upgrades + bonus money; accepts intel turn-ins.
3. **Intel/documents loop** — define document items, drop sources (pools + caves), and payouts; populate the empty `loot_data`.
4. **Shop framing** — baseline shop/sell stays mechanically; dead-drop is the NA premium channel layered on top.
5. **Branching ending** — a choice point at the island → 2 ending sequences (NA road is new; CIA road exists). Save a flag; no mid-game branching.
6. **Economy tie-in** — intel/dead-drop payouts must slot into the existing curve without breaking it (coordinate with the economy-rebalance plan).

## Resolved decisions
- Comms: **phone for messages, dead-drop for special upgrades + extra money** ✔
- Agency: **Northwind Analytics, aka NA**, country unnamed/fictional ✔
- **Goodwell arc dropped** ✔
- Three delivery channels: **US Government · News · NA** ✔

## Still open
- Exact split of baseline shop income vs. NA dead-drop rewards (who "buys" the drained water in-fiction — Swamp Mike front, or NA directly?).
- How explicit the Stage-3 "you're a foreign asset" realization is vs. left to infer.
- Whether the local vs. national **news** voices are distinct outlets or one paper that scales up.
