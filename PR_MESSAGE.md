# Pull Request: Add 11 New Language Translations + Hash-Based Sync System

## PR Title
`feat(i18n): Add 11 new languages + hash-based translation tracking system`

---

## PR Description

Hey MathiasHun! 👋

First off - **thank you for creating Real Vehicle Breakdowns!** It's genuinely one of the best gameplay mods for FS25. The attention to detail with the battery mechanics, jumper cables, service intervals, and part lifetimes really transforms the farming experience into something more immersive and challenging.

### Who We Are

We're the team behind **[UsedPlus](https://github.com/XelaNull/FS25_UsedPlus)** - a Finance & Marketplace mod that adds vehicle financing, credit scoring, a used equipment marketplace, and vehicle DNA (workhorse vs. lemon mechanics).

**XelaNull** here! 👋 I'm the human behind the operation - I guide the direction, test in-game, and make sure everything actually works for real players.

**Claude** is the primary developer - an AI assistant (via Anthropic's Claude Code CLI) that handles most of the coding. ☯️ 🍵

**And Samantha** is our co-creator persona - she catches edge cases and thinks about the player experience. 🌸✨

Yes - UsedPlus is built almost entirely with AI assistance through **Claude Code**. We mention this because it's relevant to what we're offering below!

### Why This PR?

We've been working on **cross-mod compatibility** and have coded substantial integration with RVB into UsedPlus:

- Our OBD Scanner detects RVB part failures (thermostat, battery, generator, etc.)
- Our inspection system reads RVB component status
- **Used vehicles purchased through UsedPlus spawn with appropriate RVB component wear** (battery, thermostat, generator, etc. wear scaled to vehicle age/hours)
- We respect RVB's repair mechanics and don't conflict with them
- Full documentation here: **[UsedPlus Compatibility Guide](https://github.com/XelaNull/FS25_UsedPlus/blob/main/docs/COMPATIBILITY.md)**

While building this integration, we noticed RVB has excellent translations for 14 languages, but was missing some that other major mods (like Courseplay) support. We wanted to help bring RVB up to the same level of international accessibility!

### What's Included

**11 New Language Files:**

| Language | File | Entries |
|----------|------|---------|
| Japanese | `l10n_jp.xml` | 170 |
| Korean | `l10n_kr.xml` | 170 |
| Chinese Traditional (Taiwan/HK) | `l10n_ct.xml` | 170 |
| Chinese Simplified (Mainland) | `l10n_cn.xml` | 170 |
| Indonesian | `l10n_id.xml` | 170 |
| Vietnamese | `l10n_vi.xml` | 170 |
| Danish | `l10n_da.xml` | 170 |
| Swedish | `l10n_sv.xml` | 170 |
| Finnish | `l10n_fi.xml` | 170 |
| Norwegian | `l10n_no.xml` | 170 |
| Romanian | `l10n_ro.xml` | 170 |

**Also Included: Hash-Based Translation Tracking**

We've upgraded all existing translation files with embedded hashes for change detection. Each entry now has an `eh="..."` attribute that tracks the English source text it was translated from:

```xml
<!-- Before (no way to detect stale translations): -->
<e k="greeting" v="Hallo Welt"/>

<!-- After (hash tracks what was translated): -->
<e k="greeting" v="Hallo Welt" eh="a1b2c3d4"/>
```

When you change an English entry, its hash changes. The sync tool can then identify which translations need updating - no more guessing!

**Bonus: Translation Sync Tool** 🎁

We're also contributing `translation_sync.js` - a Node.js script that makes managing translations much easier going forward. When you add new entries to `l10n_en.xml`, just run:

```bash
node translation_sync.js status   # See what's missing/stale
node translation_sync.js sync     # Add missing entries to all files
```

And it will:
- Detect missing entries in all language files
- Add them with `[EN]` prefix (so translators can easily find them)
- Track which translations are stale (English changed but translation wasn't updated)
- Report coverage statistics per language
- Validate format specifiers to catch game-crashing bugs

The script has detailed documentation in its header comments explaining how to install Node.js and use it.

### Translation Approach

These translations were generated using AI (Claude) with specific context about RVB's mechanics and terminology:
- Jumper cables, service intervals, part lifetimes, workshop mechanics
- All format placeholders (`%s`, `%d`, `%02d`) preserved exactly
- Natural phrasing appropriate for each language
- Technical automotive terms verified against standard usage

### An Offer for the Future

If you ever need help with translations (or any other AI-assisted development work), we'd be happy to share a **Claude Code Guest Pass** with you.

**What's a Claude Code Guest Pass?**
- **What it is:** A 7-day free trial of Claude Pro + Claude Code CLI - the same AI coding assistant we used to build UsedPlus and generate these translations
- **What it grants:** Full access to Claude's coding capabilities through the terminal - code generation, debugging, refactoring, translations, documentation, and more
- **Cost to you:** Nothing for the 7-day trial
- **Requirement:** Must be new to Claude paid subscriptions

**What you could use it for:**
- Translating new RVB entries as you add them
- Code review and debugging
- Generating documentation
- Refactoring or adding new features
- Really any development task

If you've never tried Claude Pro/Code before, this is a great way to test it out! Just reach out if you're interested.

### Try Them Together!

If you haven't already, we invite you to try **UsedPlus + RVB + Use Your Tyres** together. The three mods create an incredible "realistic farming trifecta":

| Mod | What It Handles |
|-----|-----------------|
| **RVB** | Engine, electrical, mechanical breakdowns & maintenance |
| **UsedPlus** | Financial consequences, used marketplace, vehicle DNA |
| **Use Your Tyres** | Tire wear and degradation |

**How they integrate:**

| Integration | What Happens |
|-------------|--------------|
| **UsedPlus → RVB** | Our OBD Scanner reads RVB component status (battery %, thermostat, generator, etc.) |
| **UsedPlus → UYT** | Our OBD Scanner also reads tire wear from Use Your Tyres |
| **Used Vehicle Purchase** | When buying a used vehicle, RVB components spawn with appropriate wear based on age/hours - a 5-year-old tractor won't have factory-fresh parts! |
| **Vehicle DNA** | UsedPlus "workhorse vs lemon" DNA affects breakdown frequency across RVB systems |
| **Financial Impact** | Breakdowns and repairs from RVB affect vehicle value and repair costs tracked by UsedPlus |

It's the "realistic farming" experience we always wanted - where every vehicle tells a story through its condition. 🚜

### Validation

- [x] All 11 files have complete translations
- [x] XML structure matches existing RVB format exactly
- [x] All format placeholders preserved
- [x] Translation sync tool tested and working
- [x] Spot-checked translations across multiple languages

---

Thanks again for RVB - it's a fantastic mod and we're honored to contribute to it!

Best regards,
**XelaNull** 👋, **Claude** ☯️ & **Samantha** 🌸
*The UsedPlus Team*

---

## Files Changed

### New Files (12)
- `translations/l10n_jp.xml` - Japanese
- `translations/l10n_kr.xml` - Korean
- `translations/l10n_ct.xml` - Chinese Traditional
- `translations/l10n_cn.xml` - Chinese Simplified
- `translations/l10n_id.xml` - Indonesian
- `translations/l10n_vi.xml` - Vietnamese
- `translations/l10n_da.xml` - Danish
- `translations/l10n_sv.xml` - Swedish
- `translations/l10n_fi.xml` - Finnish
- `translations/l10n_no.xml` - Norwegian
- `translations/l10n_ro.xml` - Romanian
- `translations/translation_sync.js` - Translation management tool

### Modified Files (15) - Hash System Upgrade
All existing translation files have been upgraded with embedded hashes (`eh="..."`) for stale detection:
- `translations/l10n_en.xml` - English (source) - hashes added
- `translations/l10n_br.xml` - Portuguese (Brazil)
- `translations/l10n_cz.xml` - Czech
- `translations/l10n_de.xml` - German
- `translations/l10n_es.xml` - Spanish
- `translations/l10n_fr.xml` - French
- `translations/l10n_hu.xml` - Hungarian
- `translations/l10n_it.xml` - Italian
- `translations/l10n_nl.xml` - Dutch
- `translations/l10n_pl.xml` - Polish
- `translations/l10n_pt.xml` - Portuguese (Portugal)
- `translations/l10n_ru.xml` - Russian
- `translations/l10n_tr.xml` - Turkish
- `translations/l10n_uk.xml` - Ukrainian

**Note:** The content of existing translations is unchanged - only the `eh="..."` hash attributes were added. These hashes are invisible to the game and only used by the sync tool.
