# Translate the macro

## Before you start

- Work only in the JSON file for your assigned language.
- If several people share a language, split the entries and merge the work into one file.

## Translate

1. In your language file, find a line under Strings.
2. Translate the text after the colon. Leave the English key before the colon unchanged.
3. Keep placeholders such as {count} exactly as written.
4. Keep the product name **Ultimate Macro** exactly the same.
5. Save the file as UTF-8.

Example:

    "Overview": "Visão geral"

An empty value shows English in the macro. Fill in as many blank values as you can. The supplied translations were made for a newer version, so many entries are blank for this version.

## If something is unclear

Send the entry key and your question or suggested wording with the translation file. Use official game wording for tower and game names when available.

## Finish

Send back the updated JSON file and name the language in your message. Include any entries that need review.

To see the translation in the macro, open Settings, select the language, then restart the macro.

## Add a language

1. Copy TranslationTemplate.json.
2. Name the copy with the language code, such as fr-FR.json.
3. Add Locale and Name at the top of the file. For example:

       "Locale": "fr-FR",
       "Name": "Français",

4. Translate the values under Strings.
