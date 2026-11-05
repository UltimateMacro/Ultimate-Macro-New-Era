# Community interface catalogs

Ten community locale catalogs are supplied alongside built-in English: eleven
language choices, including separate Brazilian and European Portuguese variants.
These are presentation-only lookups. They do not change strategy contents,
Roblox/OCR language, map/tower identifiers, Party protocol values or hotkeys.
Unknown and omitted phrases stay in English.

| Locale | Native name | Contributor | Supplied phrases |
| --- | --- | --- | ---: |
| ar | العربية | Ka_Demon | 147 |
| es | Español | RAZE500 | 138 |
| id | Bahasa Indonesia | g4m3rsl4y3r | 149 |
| mt | Malti | Ayden567843 | 145 |
| pl | Polski | Creeperhouse999 | 149 |
| pt-BR | Português (Brasil) | Flupizinho | 146 |
| pt-PT | Português (Portugal) | profesorhenrique21 | 146 |
| ru | Русский | KUTMAN79 | 149 |
| uk | Українська | nexaridev; submitted by typoxerax | 146 |
| zh-CN | 中文（简体） | yz | 146 |

The 1,461 entries count supplied source phrases, not complete coverage of every
current screen. The community worksheet has 159 planned/preview source IDs;
translated text does not enable or promise any unimplemented feature. New UI
copy and incomplete, uncertain or meaning-reversed entries retain English.
The catalogs have had data/engineering review, not native-speaker certification.

Only English/Translation pairs are included. Private assignment instructions,
conversations, comments and signed CDN download URLs are not bundled. Metadata
records source hashes and observed message IDs. The European Portuguese catalog
uses a user-provided copy of an inaccessible document; its metadata explicitly
does not claim the document was read or invent a Discord message ID.

Later, explicit Ukrainian and Simplified Chinese translator corrections have
per-entry message provenance. Bare Start/Pause/Resume/Stop labels reuse the
provided action token only after removing the exact same legacy shortcut suffix
from both source and translation; derivation metadata records that operation.
The legacy shortcut instructions themselves are not translated or reused.

`tools/import_community_catalogs.py` provides bounded, offline conversion and
explicit reviewed-correction support. It rejects conflicting or malformed
entries, mismatched placeholders and unsafe legacy instructions rather than
guessing missing translations. The runtime validates each catalog independently
and safely falls back to English if a catalog is missing or invalid.
