# Export text format

How an encoded export string is presented for copying and accepted for pasting. The addon and the website implement the same rule; change both together. Presentation only: the encoded bytes (`RM1:` marker plus Base64 of the compressed payload, see `rotation-transport.md`) are never altered, and `codec:Encode` still returns the unwrapped string.

## Export: fixed-width lines

`addon:FormatExportText(text)` (`Data/export_text.lua`):

1. Remove any existing line breaks (CR and LF) from the string, and nothing else. Formatting an already wrapped string therefore returns the same wrapped string. Encoded exports contain no other whitespace.
2. If the result has at most **76** characters, return it unchanged.
3. Otherwise cut the whole string, marker included, into consecutive pieces of exactly 76 characters; the last piece holds the remainder (1 to 76 characters). Join the pieces with a single `\n` (LF, never CRLF).
4. No trailing newline, no blank line, no indentation, no per-line prefix. The `RM1:` marker is simply the first four characters of line 1, so line 1 carries 72 Base64 characters and every later line 76.

76 is the RFC 2045 (MIME) line length and is used for every export kind: rotation, item set, announcement, effect, condition category, custom condition and function bundles, and profile. A 64-column rule (RFC 7468 / PEM) was considered and rejected: it adds about 19% more lines for no readability gain, while 76 characters still fit the 570-pixel transfer window in the bundled monospace face.

Worked example (3 lines: 76, 76 and 11 characters; the data is not meaningful):

```
RM1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAA=
```

## Display

The export and import edit boxes use a fixed-pitch face, the bundled `Fonts/Inconsolata-Regular.ttf` (SIL OFL, see `Fonts/OFL.txt`). `addon:UseExportFont(dialog)` picks the largest size from 12, 11, 10, 9 whose measured 76-character line fits the box without wrapping (the box is 510 pixels wide in the transfer window, 828 in the function bundle window; 12 point Inconsolata needs about 456). If the file is missing or the client rejects it the box keeps `GameFontHighlightSmall`: the text still copies and imports correctly, only the alignment is lost. Websites should use a `monospace` stack (for example `ui-monospace, "SFMono-Regular", Consolas, "Liberation Mono", monospace`), `white-space: pre` (or `pre-wrap` with `overflow-wrap: anywhere`), and preserve `\n` when copying.

## Import: whitespace tolerant

`addon:NormalizeImportText(text)` removes every one of the following, anywhere in the string, then the codec decodes the remainder exactly as before:

- ASCII space, tab, LF, CR, vertical tab, form feed (so wrapped, CRLF, indented and unwrapped forms all decode, as do blank lines and leading or trailing blanks);
- U+0085, U+00A0 (no-break space), U+1680, U+180E, U+2000 to U+200A (spaces), U+2028, U+2029, U+202F, U+205F, U+3000;
- zero-width and invisible formatting characters that chat and web copy introduce: U+00AD, U+200B to U+200F, U+202A to U+202E, U+2060 to U+2064, U+2066 to U+2069, U+FEFF.

Nothing else is removed. The encoding's alphabet (`A-Z a-z 0-9 + / =` and the `:` of the marker) contains none of those characters, so stripping cannot change valid data. A corrupted string still fails with the same codec error code as before (`invalid-base64`, `invalid-base64-padding`, `unsupported-transport-version`, ...) whether it is wrapped or not, because wrapping never reaches the decoder.

The rule is applied inside `codec:Decode`, which every import path calls (rotation preview, item set, announcement, effect, condition category, custom condition and function bundle review, profile). It is deliberately not applied to the text box contents before an importer sees it: item sets and condition categories also accept plain pasted lists in which a space or newline separates entries.

Limits are unchanged. The 2 MiB pasted-text limit is checked on the text as pasted, before normalization. The box accepts one extra character per 76 so a wrapped export is never truncated where the unwrapped one was not.
