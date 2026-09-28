# FAMIGLIA: Game Plan

**One line:** A grounded online Mafia-empire campaign for 2–8 friends, running from 1920s Prohibition to the 1980s RICO trials. You don't win by shooting the most people. You win by hiding your money, keeping your men loyal, staying out of prison, and choosing the right moment to betray your friends.

---

## 1. Why this isn't Empire of Sin

Empire of Sin (Paradox, 2020) had a strong premise and flopped. The reasons are the design brief for what we should do differently:

| Empire of Sin | FAMIGLIA |
|---|---|
| Most of the playtime is XCOM-style gunfights | Violence is rare, expensive and dangerous. Most play is business, corruption and negotiation |
| Rackets are "buy building, upgrade building" | Every racket depends on real systems: suppliers, unions, cops, laundering capacity |
| Money is just a number that goes up | Money is **dirty**. You have to launder it before you can use it openly |
| Police are a simple "heat" meter | The feds build a **case**: evidence, witnesses, wiretaps, informants. You can see part of it |
| Crew members are combat units | Crew members are **people**: loyalty, greed, ambition, family. They can be arrested and **flip** |
| AI diplomacy made no sense | Diplomacy happens **between real friends** over voice chat. Deals aren't enforced by the game, only by reputation |
| One static era | **Eras** that change the economy: Prohibition, Repeal, the Depression, WWII, Vegas, RICO |
| Cartoon gangsters | Grounded tone, closer to *Boardwalk Empire*, *Goodfellas* and *The Irishman* |

**Design rule:** Every realistic system has to create a **decision** or a **story**. If it only creates paperwork, we cut or automate it. You're the boss, so you make the calls and your people do the chores.

---

## 2. What it looks like

Mock-ups are in `docs/mockups/` (1280×720; regenerate them from `mockups.html`).

| Screen | What it's for |
|---|---|
| `1_city.png` **City** | A top-down noir city. Districts are coloured by family. You click businesses. Decision cards pile up on the right, and a newspaper ticker along the bottom shows what's happening. |
| `2_family.png` **Family** | The org chart: boss, underboss, consigliere, capos, soldiers, associates. Each person has loyalty and exposure bars. In the mock-up, Sal has been arrested and is 31% likely to flip. |
| `3_ledger.png` **Ledger** | Where the money goes. Rackets produce dirty cash, fronts launder it into clean money, and anything you can't launder piles up in a stash that becomes evidence if it's raided. |
| `4_intel_board.png` **Intel** | The FBI's corkboard on you, as far as your crooked detective can see: photos, red strings, case strength (23% against you, indictment at 70%). |
| `5_sitdown.png` **Sit-down** | Two friends on voice chat build a deal out of terms and a guarantee (e.g. a nephew as a "hostage"), with a third player as Commission witness. Nothing is written down. |

**Art direction:** A painted, muted 1920s–80s look (sepia, amber streetlights, rain), with the UI styled like paper, ink and cheap office supplies. The city is stylized 3D or 2.5D seen from above, like Godfather 2's Don's View but more alive: cars, lit windows, raids you can watch happen. There's **no third-person shooting**. That keeps the budget sane and keeps the focus on being the boss.

---

## 3. The core systems

1. **Rackets and the real economy.** The city runs on NPC businesses and supply chains. If you control the Teamsters local, you tax every truck. If you control the concrete union, you rig construction bids. If you control the docks, you get smuggling and theft. Rackets depend on each other, just like they did historically.
2. **Dirty and clean money.** Illegal cash can pay your men, bribes and street loans. Anything visible needs clean money: property, companies, politicians, a casino. Laundering capacity (your fronts) is the bottleneck on how fast you grow.
3. **Evidence and insulation.** Every crime leaves evidence attached to the **people** who did it. Orders go down the chain, so each layer between you and the crime protects you but makes the job slower and less reliable. The feds need to connect the evidence to you. RICO (1970) changes the rules, and after that the whole family becomes a target.
4. **People.** Every man has loyalty, greed, ambition, fear and a family at home. Take care of the families of jailed men and pay for good lawyers, or those men start talking to the DA. Getting made raises a man's loyalty, but the Commission controls when new members can be made.
5. **Violence.** A hit is a big decision. It needs planning, a shooter, an alibi, and (after 1931) the Commission's permission. It brings attention, and it can start a war. Wars are terrible for business. Because hits are rare, each one becomes a story.
6. **Politics and corruption.** A payroll of beat cops, precinct captains, judges, ward bosses and eventually a senator. Reform candidates, press crusades and federal task forces push back.
7. **The Commission.** A player-run council. Families vote on the rules (territories, a narcotics ban, permission for hits, opening the books to new members). Breaking the rules isn't blocked by the game. The other families vote on how to punish you.
8. **Eras.** Each era rewrites the economy. Prohibition (1920–33) is booze. Repeal crashes it. The Depression brings loansharking and unions. WWII is the black market and the docks. The 1950s are Vegas and congressional hearings. The '70s–'80s bring narcotics money and RICO. Every era change is a crisis for somebody.
9. **Offline play.** When you're not online, your consigliere follows standing orders (defend, stay quiet, keep collecting). You can lose ground while you're away, but you can't lose everything. You come back to a "while you were gone" report.

**Factions play differently** (realistic and good for replays):
- **Italian families:** strong discipline and structure. Best at protection and unions.
- **Irish mob:** political machine and docks. Cheap cops and politicians.
- **Jewish syndicate:** finance, gambling and laundering. Best fronts, fewest soldiers.
- *Later DLC or eras:* Cuban and Colombian suppliers, a Russian "gasoline" mob, the Chicago Outfit.

---

## 4. Simulation: four friends play a campaign

**The group:** Alex (Vitale, Italian), Marco (Russo, Italian), Jess (O'Hara, Irish), Dani (Moretti, Italian). They play Friday nights for about 2–3 hours, with the city on a dedicated server. Each "game night" covers roughly 1–3 in-game years.

### Night 1: 1923, "Small time"
**What they do:** Everyone starts with a boss, three guys, a speakeasy and $2,000. Alex assigns his men: Frankie collects street tax on Mulberry St, Sal runs a truck of Canadian rye from the docks, Tommy starts a numbers bank. Then the first decision card arrives: the tailor won't pay. Alex sends Frankie to "talk". It works, and three neighbouring shops start paying without being asked.

Jess spends her first money on a precinct captain and a Tammany ward boss instead of men. Dani goes all-in on bootlegging trucks. Marco's crew hijacks a truck in week 9, and it turns out to be Alex's. Nobody knows who did it. The newspaper just says "Truck of rye vanishes on West St."

**How it feels:** Scrappy and small, with every dollar counted. It's tense in a fun way: *"Who took my truck?"* Everyone is suspicious by the end of the night. There's a lot of laughing and accusing on voice chat, and **Marco denies everything**.

### Night 2: 1925–27, "Too much cash"
**What they do:** Money floods in from booze, but Alex hits the wall: $40k dirty and only $6k clean. He can't buy the restaurant he wants without the Treasury noticing. He buys a bakery and a laundry as fronts, and it's still not enough. Jess offers to launder his money through her "consulting" business for 15%. Alex agrees, so now Jess knows exactly how much he earns.

Sal gets arrested after a beating. He faces 6–9 years. The DA offers him a deal. Alex has to choose: pay $2k for a good lawyer and $80 a week to Sal's wife, or save the money. He saves the money.

**How it feels:** The **"I'm rich but I can't spend it"** feeling, which is new and realistic. There's quiet dread about Sal. Alex's first real alliance, with Jess, feels good and also dangerous.

### Night 3: 1928–31, "The Crash and the Commission"
**What they do:** The 1929 crash hits. Legitimate businesses go cheap, and everyone buys fronts at fire-sale prices. Loansharking explodes. In 1931 the game proposes the **Commission**, and the four friends spend 25 minutes arguing about the rules on voice chat. They agree on no hits between families without a vote, each family keeps its territory, and a tribute to the table. Jess sells her vote on the territory rules to Dani for $10k.

Then the news arrives: Sal flipped. He never got his lawyer, and his wife stopped getting money. Two soldiers are arrested. Alex's case strength jumps from 23% to 58%.

**How it feels:** Politics night, with a real parliament of friends. Then it's Alex's worst moment, and it's **his own fault**: he was cheap with Sal. That is the lesson, and the story he'll tell: *"My capo ratted because I didn't pay his wife 80 bucks a week."*

### Night 4: 1933, "Repeal"
**What they do:** Prohibition ends. Dani was 70% bootlegging, and his income drops 84% in one week. He's desperate and borrows $30k from Alex at 10% a week. Alex, meanwhile, has been quietly buying into the longshoremen's union with Marco. Jess, with her political machine, gets the city construction contracts.

Dani can't pay the loan. Alex and Marco discuss taking his territory. Jess warns Dani. Dani uses the Commission rules: he calls a vote accusing Alex of loan-sharking a made family, and gets it passed 2–1 with Jess. Alex has to forgive half the debt.

**How it feels:** The balance of power shifts. The player who was on top is now at the bottom. The rules they wrote themselves on Night 3 get used against the player who wanted them. Everybody feels clever, and one person feels robbed.

### Nights 5–6: 1941–49, "The War"
**What they do:** A navy intelligence officer asks the families to "keep the waterfront safe from saboteurs" in exchange for the heat going down. That's based on real history. The players who control the docks, Alex and Marco, become untouchable. Ration stamps turn into a black-market currency. Jess helps smuggle a war-profiteer's money. Everyone gets rich.

Then Marco breaks the pier deal and kills Alex's underboss Frankie. It's the first war. It lasts 18 in-game months, both families go "to the mattresses", income collapses, and Jess and Dani quietly buy the Garment District while the two biggest families bleed.

**How it feels:** Peak drama. The hit on Frankie is the moment everyone clips. The war feels expensive and stupid, as real mob wars were, and the players watching from the side are laughing.

### Nights 7–8: 1950s, "Vegas"
**What they do:** A casino opportunity opens in Las Vegas. It costs $2M clean, which no family can afford alone. All four pool money into a joint venture, with the skim split by share. Now everyone's money is tied up in one building, so everyone wants to steal the skim and nobody dares to. Then congressional hearings subpoena the two biggest bosses, who must testify on TV (a public dialogue minigame; "I plead the Fifth" costs reputation, and lying risks perjury). Then there's a family summit at an upstate farm, and the feds raid it. **Someone tipped them off.** Nobody knows who.

**How it feels:** Cooperation under pressure. Paranoia about the tip-off drives the next five nights. Streamer material.

### Nights 9–10: 1970–85, "RICO"
**What they do:** RICO passes. Now any pattern of crime can bring down the whole family. Old structures become liabilities. Narcotics money is enormous, and the Commission banned it in 1957. Dani is secretly dealing. The feds start a "Commission case" against every boss at once.

Every player now has two paths: go legitimate (sell rackets, keep clean assets, cut ties) or double down. And there's the secret option: **cooperate with the government**. Alex's case is at 76%. He can give up everyone else for immunity and witness protection.

### Endgame: 1986
**What decides the winner:** At the end, each family is scored on **Legacy**: clean wealth, territory held, political reach, and whether the boss is free, in prison or dead. Informants get their own ending: they survive, but their family is gone and their Legacy is zero. They can still "win" through a secret objective (bosses convicted by their testimony).

In our story, Jess wins. She was never the biggest, but she went legitimate early, owned the politicians and never got indicted. Alex considered flipping and didn't. Marco died in 1978, shot by his own capo. Dani flipped and took everyone down with him.

**Afterwards:** The group spends 20 minutes arguing about who tipped off the summit raid in 1957. The end-of-campaign screen shows it: **Jess, for $50k from the Bureau.** She played everyone for 30 years.

### The emotional curve (what we're designing for)
```
tension ▲        Sal flips      war        summit raid   RICO / flips
        │           ▲            ▲▲            ▲            ▲▲▲
        │   truck  ╱ ╲  repeal  ╱  ╲   vegas  ╱ ╲          ╱   ╲  reveal
        │    ▲    ╱   ╲  ▲     ╱    ╲   ▲    ╱   ╲        ╱     ╲   ▲
        │___╱ ╲__╱     ╲╱ ╲___╱      ╲_╱ ╲__╱     ╲______╱       ╲_╱ ╲__
        └──────────────────────────────────────────────────────────────▶
          1923   1927   1931  1933   1941   1950   1957  1970  1980 1986
```
There's a peak every game night, a calm business stretch between peaks, and a reveal at the end that makes people want to start again.

---

## 5. Solo play, and why it matters

Most strategy players play alone, even in games known for multiplayer (Paradox titles are mostly played solo). Multiplayer is the hook and the marketing. **Solo against AI families is where most of the sales come from.** The AI families need personalities (a paranoid old don, an ambitious young upstart, a political fixer) and must be able to lie, keep grudges and betray you. This is the hardest engineering problem in the game, so we start on it early.

---

## 6. What could go wrong (honestly)

- **Realism turns into paperwork.** If laundering, lawyers and payroll feel like spreadsheets, the game dies. Fix: they show up as decisions on cards, the defaults are automated, and you only step in when something breaks.
- **Scheduling.** Friends don't play at the same time. Fix: game-night mode first (the world runs only when the host is on), the consigliere for absences, and a persistent 24/7 city later.
- **One player falls behind and quits.** Fix: the feds focus on the biggest family, small families get cheaper informants and hitmen, and eras reshuffle the board.
- **Content runs out.** This is what killed Schedule I after 15 hours. Fix: eras, factions, randomized cities and characters, and each campaign ends so a new one can begin.
- **Scope.** The full 1920–1986 version is a 2–3 year project. Fix: ship Early Access with Prohibition (1920–1933) only, then add eras.
- **Theme and platform risk.** Organized crime is fine on Steam (Mafia, Schedule I, Godfather). Avoid real names of living people, and be careful with how drugs are shown.

---

## 7. The plan

### Phase 0: paper test (weeks 1–4, costs nothing)
Run the game **as a Discord game with you as game master**. Use a Google Sheet for money and evidence, one message a week per player, and a real voice-chat sit-down every session. Play 1923–1933 with 4 friends over 3–4 weeks.
**Pass if:** friends message each other between sessions, lie to each other, and ask when the next session is. If they don't care in text form, graphics won't save it.

### Phase 1: ugly digital prototype (months 1–5)
Engine: **Godot or Unity**, with a host-authoritative simulation (the host runs the game logic and clients only display it). A menu-heavy strategy game is much easier to network than a shooter.
- 1 district, 1923–1933, 2–4 players plus 1 AI family
- Systems: crew jobs, 4 rackets, dirty/clean money with 3 fronts, evidence plus 1 investigation, arrests with a flip chance, sit-down deal builder, 1 type of hit, the Repeal event
- Art: flat 2D map and grey boxes

**Test:** 4 players, 3 sessions of 90 minutes. Measure how many deals were made and broken, how many times players shouted, whether people wanted a 4th session, and which systems they ignored (those get cut).

### Phase 2: vertical slice (months 5–12)
The full Prohibition era, 3 districts, 3 factions, real art direction, AI families with personalities, a solo mode, a Steam page and trailer, and a closed playtest on Discord.

### Phase 3: Early Access (months 12–20)
Launch with 1920–1945 (Prohibition, the Depression and the war) at **$19.99**, and a demo in Steam Next Fest. Update with eras over time (each era is a big content update and a news spike).

### Phase 4: 1.0 (months 20–36)
Eras through 1986, a persistent "living city" server mode, mod support, more factions and cities (Chicago, Havana, Vegas) as DLC.

### Team (minimum)
- **You:** design, writing, community
- **1 programmer:** simulation and networking (the most important hire)
- **1 artist:** UI and city art (can be contract)
- Later: 1 more programmer for AI, plus sound and music on contract

### Next 30 days
1. Write the paper rules (2 pages): rackets, money, evidence, people, deals.
2. Recruit 4 friends and run the Discord test for 3–4 weeks.
3. Keep a list of every story players tell afterwards. Those stories are the marketing.
4. Decide on the engine and start the Phase 1 prototype only if the paper test passes.

---

*Name note: "Famiglia" is a placeholder. Check Steam and trademarks before announcing.*
