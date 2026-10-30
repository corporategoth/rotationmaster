# Style per language

The register each language already uses, measured on the current locale files (counts of the pronoun and verb forms in the
whole file). Keep it: a mixed register reads as careless. Full words and terms are in `glossary.md`; game vocabulary
follows the game client.

| Code | Register (you) | Evidence in the files | Buttons and commands | Punctuation and typography |
| --- | --- | --- | --- | --- |
| deDE | Formal: **Sie / Ihr** | Sie/Ihr forms about 1060, du forms 8 (use Sie) | Infinitive: *Löschen, Abbrechen, Hinzufügen*; instructions *Wählen Sie ...* | Nouns capitalized; compounds written together (*Wechselpriorität*) |
| esES | Informal: **tú** | tú forms (*elige, puedes, abre*) about 300, usted about 0 | Infinitive: *Borrar, Cancelar, Añadir* | Spain vocabulary: *Añadir, coste, ordenador* |
| esMX | Informal: **tú** | same pattern as esES | Infinitive: *Borrar, Cancelar, Agregar* | Latin American vocabulary: *Agregar, costo*. Do not copy esES words that differ (about 600 strings differ between the two) |
| frFR | Formal: **vous / votre** | vous forms about 985, tu 0 | Infinitive: *Supprimer, Annuler, Ajouter* | A space before `:` `;` `?` `!` (a plain space in these files); guillemets « » for quotation |
| itIT | Informal: **tu** | tu forms about 465, Lei 2 | Imperative (2nd person singular): *Elimina, Applica, Aggiungi, Cerca* | Sentence case |
| koKR | Polite formal: **-합니다 / -세요** | those endings about 2670, informal endings 0 | Noun form: *삭제, 추가, 취소* | ASCII punctuation (`:`, `,`, `.`); no space before it |
| ptBR | **você** | você / seu / sua about 1020, tu 3 | Infinitive: *Excluir, Adicionar, Cancelar, Remover condição* | Brazilian spelling (*ação, configuração*) |
| ruRU | Formal: **Вы** (capital) | Вы forms about 380, ты 0 | Infinitive: *Удалить, Добавить, Отмена* | Sentence case; quotation marks « » if needed |
| zhCN | Informal-neutral: **你** | 你 about 740, 您 0 | Short verb: *删除, 添加, 取消* | Simplified characters; **full-width** punctuation `，。：；（）`; no spaces around Chinese text; ASCII for numbers and commands |
| zhTW | Informal-neutral: **你** | 你 about 730, 您 0 | Short verb: *刪除, 新增, 取消* | Traditional characters; Taiwan terms (*設定, 快取, 停用, 在地化*), not mainland ones (*配置, 缓存, 禁用, 本地化*); full-width punctuation |

## All languages

- Translate the *meaning* for a player, not word by word. If the English is a long technical paragraph, the translation is
  too; do not shorten it by dropping a condition or a number.
- Keep numbers, units (`s`, `%`), keys and slash commands as written.
- Use one term for one thing, and the term in `glossary.md`. If a locale has no entry for a word yet, choose the word the
  game client uses and add it to the glossary table's source (the locale file) by using it consistently.
- Do not add or remove emphasis, exclamation marks or emoji.
- US spelling applies to the *English source* only; translations use their own language's standard orthography.
- Labels in English Title Case ("Switch Condition") become the natural capitalization of the target language
  (sentence case almost everywhere, German keeps noun capitals).
- Ellipsis: keep the English's `...`; do not turn it into `…` unless the English did.
