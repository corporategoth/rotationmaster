# Bounded RotationMaster import decoder

This is the first transport/data slice of the planned static viewer. There is no viewer UI, website deployment, encoder, sharing service, Lua interpreter, or rotation execution engine here. The browser module smoke test is a separate acceptance step; the current automated runner is Node's built-in test runner.

```js
import {decodeImport} from './import.mjs';
const result = decodeImport(pastedText);
// result.ok: inspect result.value as inert Lua data, or show result.reason.
```

`decodeImport(text)` returns `{ok:true,value,kind,original,transportVersion}` or `{ok:false,reason}`. `kind` is `envelope` when the root's format field is `RotationMaster`, otherwise `legacy`; this does **not** validate that the value is a rotation. Profiles, itemsets and other RM data can use the same transport. `original` preserves the complete successful input exactly, including wrapping. `transportVersion` is `1` for `RM1:` or `null` without a prefix. Future numbered prefixes fail explicitly.

`checkPortable(value)` from `lua-data.mjs` returns `{ok:true}` or `{ok:false,reason,path}`. It accepts only the documented data types, with native Map branding and an exact Map prototype. It does not call methods attached to input Maps. `toTypedTree(value)` produces the deterministic test-oracle representation; numeric values use big-endian IEEE-754 hexadecimal bits, including negative zero. `decodeLegacyCompression(Uint8Array)` and `parseAce1(Uint8Array)` are pure lower-level stages; a caller using those stages directly must still run portable validation. Results contain fresh data rather than mutable aliases of input byte buffers.

## Lua data representation

Tables are native `Map` instances, not JavaScript objects or arrays. Numeric key `1` and byte-string key `"1"` are different. Numeric priority order is obtained from the actual numeric keys; serializer table traversal order does not define it. `false`, `0`, empty tables and holes remain distinct. `__proto__` and `constructor` are ordinary inert keys. Positive finite integer keys follow Lua's double-number semantics, including rounding above 2^53.

Strings preserve bytes: each JavaScript code unit is 0..255. A Unicode label exported by Lua is UTF-8 **bytes** in this representation. Do not use a replacement-decoding TextDecoder to alter the stored value. A later UI can display valid UTF-8 or escaped invalid bytes while retaining the original byte data. `null` represents Lua nil for the portable-data utility; serialized table nil keys/values are refused by the wire parser. Tables cannot have metatables/prototypes, cycles or executable values. Acyclic shared references are accepted by the utility and counted at each visit; the wire format itself creates fresh tables.

Source strings, custom Lua, JavaScript-looking text and HTML stay strings. These modules have no evaluation, DOM, native-game, save, callback-dispatch or network APIs. Decode success makes no claim about unresolved dependencies, condition truth, readiness, gameplay, provenance quality or applicability. Preserve unknown legacy edition/class/scope; do not infer them from spell IDs or a transport label.

## Wire behavior and fixed limits

The observed transport is ordinary canonical Base64 (ASCII space/tab/CR/LF wrapping) over legacy compression tag 1 Store, 2 LZW, or 3 Huffman, over AceSerializer rev1. It is not URL-safe Base64, JSON, LibDeflate, zlib or a filtered modern LibCompress stream. Only `RM1:` and unprefixed payloads are supported.

| Resource | Maximum |
| --- | ---: |
| Original input UTF-8 bytes, before normalization | 2,097,152 |
| Compressed bytes | 1,048,577 |
| Decompressed/serialized bytes | 1,048,576 |
| Serializer control tokens | 20,000 |
| Serializer table nesting, root at 1 | 64 |
| Portable depth, root at 0 | 64 |
| Portable nodes: each table/value visit plus every collected key | 20,000 |
| One string or string key, bytes | 262,144 |
| Total visited string/key bytes | 1,048,576 |

These constraints are independent and fixed; there is no API to raise them. Input length is measured before whitespace stripping. Non-ASCII Base64 payloads are rejected. UTF-8 accounting applies only to the browser's text input, not to decoded Lua byte strings.

The decompressor refuses oversized declared/derived output before producing it. LZW has a length-only first pass and prefix/suffix dictionaries, so it never constructs a growing string for every dictionary entry. Its dictionary capacity is bounded by compressed byte length plus 256; phrase expansion uses the precomputed lengths and a fixed output buffer. Huffman has at most 256 map entries and 32 escaped code bits per entry; decoding examines at most 32 bits per output byte. The observed finite one-zero-byte EOF allowance is retained. Duplicate code entries overwrite earlier entries and shorter matching lengths take precedence, as observed; malformed maps are not passed into a vendor parser. Tokenization has at most 20,000 entries, serialized text at most 1MiB; table construction and portable traversal use explicit stacks. No unbounded output, recursion, codebook search or intermediate dictionary phrase strings are used. These algorithmic limits do not claim a precise browser heap or wall-clock budget.

The serializer reader preserves observed permissiveness: token-attached ignored text, repeated-key last-write behavior, alternate valid string escapes, Lua decimal/signed hexadecimal/hex-float number forms, and the deployed `^F` multiplication order. `^N` has special Infinity spellings which `^F` operands do not share; nonfinite results are refused by portable validation. Nil table values, nonportable keys, extra root values and control tokens after the terminator fail. Failure reasons are fixed codes; input contents and exception messages are not surfaced as diagnostic reasons. Matching sampled malformed streams does not prove equivalence for every corrupt wire input or every platform's `tonumber` implementation.

## Oracle and tests

Run from the repository root:

```
node --test tests/web_codec.mjs
luajit tests/rotation_codec.lua
```

The Node suite also invokes the actual bundled LuaJIT codec oracle, with its real `bit` library; it does not install packages or substitute a fake bit API. The first seven fixture imports include the three immutable original LibCompress90083 exports, actual90087 Store/LZW/Huffman streams (asserted tags), and the reviewed Shaman starter envelope. Further protocol/compression fixtures cover byte strings, Map keys, exact doubles, malformed/oversized input and unknown/unusable values. Additional deterministic generated cases and bounded mutations are decoded by Lua and JavaScript in the same test, comparing exact results or fixed reasons. Custom source is exercised only as inert data. These are codec/data tests, not native-client or website acceptance evidence.

To generate a new oracle snapshot for deliberate review:

```
luajit tools/export_web_codec_fixtures.lua > /a/new/review/path/web_codec.json
```

Optional `--differential` and `--adversarial` add generated data or bounded malformed streams. Do not overwrite historical fixtures just because a vendor/codec changes. Lua `pairs` and compressor tie ordering need not yield byte-identical newly generated streams across processes; each generated stream is compared to that same actual Lua decode, while the committed snapshot remains a stable independent input. No encoder was added to the JS implementation.

## Protocol provenance and licenses

The JavaScript architecture is independently authored from protocol facts and behavior tested against the actual Lua oracle. It does not embed or distribute a standalone AceSerializer/LibCompress implementation, translate their source functions line-for-line, or include third-party code under a different license. This is not a clean-room or legal certification claim. The repository LICENSE is unchanged.

The test oracle uses the already bundled, unmodified libraries: AceSerializer-3.0 (AceSerializer revision1 wire protocol) and LibCompress90087/r87, with original90083 compatibility fixtures. LibCompress's header/license explicitly states GPL version2. `Libs/Ace3-LICENSE.txt` includes notice/redistribution requirements and a standalone redistribution restriction. Those notices and licenses continue to govern the bundled oracle sources; they are not erased or relabeled by this new module. Any later reuse of vendor implementation code requires a separate licensing review, rather than treating this protocol reader as permission to copy it.

Inspected baseline: `2c2a97962b01a6c08607e33c2b280e222a891205`.

| Oracle source | SHA-256 |
| --- | --- |
| `Data/codec.lua` | `8f8f78b714598259582438bd33a6408bd15277ca27f4ceea6ee2694e80ef65bc` |
| `Data/plain.lua` | `3984e9f99847015d4ba7eed89094ed54be446ba961413c46ddee54aeee07b965` |
| `Libs/AceSerializer-3.0/AceSerializer-3.0.lua` | `af2d55fd5ded8cca07608d20c40cc8aa776afbd417f936f5078c8b0054e713ff` |
| `Libs/LibCompress/LibCompress.lua` | `9eee2a4a19034638ea7e227d68d790f4ae3c489676cdfb7f6e19d89d6baec1ed` |
| `tests/fixtures/legacy_rotation_exports.lua` | `492b32233db48a941c9fbed9d91961cf39e5a351410fa9f02fd8cd671fceda95` |

## Deliberately separate follow-up work

There is no generated JS-readable condition/effect/itemset schema yet. Porting the actual closed rotation schema and its diagnostic/status semantics is a separate unit, followed by ordered rendering, unresolved dependency presentation, structural diff/catalog integration, accessibility and actual-browser acceptance. URL fragments, downloads, URL-size testing, public hosting and any service/account choice remain separate. No import is executed, installed or rewritten to make it fit the browser model.
