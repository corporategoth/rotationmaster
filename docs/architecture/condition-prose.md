# Condition prose

Condition printers return translated templates. Use `{{!positive|negative}}` at the main predicate, for example `L["%s {{!is|is not}} in combat"]` or `L["you {{!have|do not have}} a pet"]`. The leading `!` identifies predicate scope, not Lua negation. Translators may move the marker with the predicate. Positive rendering selects the first alternative; a NOT leaf selects the second.

`addon.compareString(operator, left, right, primary)` supplies translated comparison alternatives. Set `primary=true` on the outer comparison when the left side already contains another numeric comparison, such as counting members with health below a threshold. This keeps the member qualifier positive while negating the final count predicate. Without an explicit primary, the first comparison marker is the leaf predicate.

Registration wraps printers once, preserving the definition table's identity and positive direct `definition.print` calls. The engine passes a negation flag to the wrapper for leaves. Multiple NOT wrappers cancel; a NOT group keeps its explicit logical wrapper. Unmarked custom/legacy prose uses a translated `not (text)` fallback. Bounded data-only descriptions still avoid running custom printers. No observation or evaluation behavior changes.

The full rendered condition loses one outer parenthesis pair only if that pair encloses the complete expression. Nested group parentheses and `NOT (group)` remain, so precedence is preserved.
