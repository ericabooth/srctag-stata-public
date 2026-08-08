# srctag + srcfind

Stamp Stata variables with characteristics (meta-information) including: their source lineage, their category (e.g., survey construct, origin, topic), and search these tags/stamps —
in memory or across a whole folder of `.dta` files. The simplest question
in applied work is often the hardest to answer on the spot: *where did
this number come from?* `srctag` writes the answer into each variable's
characteristics, the metadata slot that survives `save` and travels with
the dataset through every later `merge` and `append`. `srcfind` reads it
back on demand.

Companion package to *Applied Program Evaluation Using Stata*
(Booth & Teas).

## Install

```stata
net install srctag, from("https://raw.githubusercontent.com/ericabooth/srctag-stata-public/main/") replace
```

(SSC submission is in progress; once live, `ssc install srctag`.)

Requires Stata 16.0 or newer. One install provides both commands.


<img width="2400" height="1260" alt="projectbuilder_srctag_suite" src="https://github.com/user-attachments/assets/a144a8d5-b3c8-45a6-bb23-c18b4b138f51" />

## Quick start

```stata
sysuse auto, clear

* stamp the sources once, at import
srctag price mpg, source(dealer file 2026) vintage(2026-07)
srctag headroom, agency(TWC) dataset(wage ledger) url(https://example.gov/twc)

* months later: which variables came from the dealer file?
srcfind dealer
*   price           dealer file 2026 (2026-07)
*   mpg             dealer file 2026 (2026-07)

* everything known about one variable, clickable
srctag show headroom

* which variables has nobody tagged yet?
srcfind , untagged

* search a whole warehouse folder without loading the data
srcfind TWC, dir("warehouse")

* fingerprint the data the tags describe; catch staleness later
srctag sign
srctag verify        // errors 459 if the data changed since signing
```

## What each command does

**srctag** writes tags: `source()`, `vintage()`, `notes()` (the simple
schema) and `agency()`, `dataset()`, `url()`, `category()`,
`key()/value()` (the structured `src_*` schema). It refuses to *change*
an existing tag without `replace` (identical restamps are no-ops, so
tagging do-files rerun cleanly), keeps a manifest of every source in
`_dta[sources]`, and its `sign`/`verify` pair stores a `datasignature`
fingerprint so tags describing since-changed data are caught instead of
trusted.

**srcfind** searches both schemas at once: case-insensitive
contains-match by default, `exact`/`wildcard`/`casesensitive` modes,
`char()` to restrict to one field, `all` to list every tagged variable,
`untagged` to audit for missing tags, `not` to invert, `dir(folder)` to
scan a warehouse (each file opens first-observation-only in a scratch
frame — nothing in memory is disturbed), `local()` to hand the matching
varlist to your next command, and `saving()` to export every tag as a
machine-readable dataset. `srcfind tags` and `srcfind values` browse the
tagging vocabulary a file already uses.

## The ecosystem: four packages, one provenance story

None of these is required — srctag/srcfind need only Stata 16 — but each
connection makes the tags do more work.

| Package | Connection | Install |
|---|---|---|
| **projectbuilder** | Its generated `300_labels.do` (the labeling stage of the numbered pipeline) is where tagging belongs: raw files identified, analytic file built, a commented `srctag` block already waiting. `projectbuilder check` reports whether srctag/srcfind are installed, beside every other companion. | `ssc install projectbuilder` |
| **combineall** | Writes `char[source]` **itself**: its harmonization layer stamps each mapped variable with `"oldname (file, year)"` while stacking yearly releases — so a combineall-built panel is srcfind-searchable with no srctag call at all. srctag then adds what the stamp lacks (an agency, a URL) without disturbing it. | `ssc install combineall` |
| **datadictionary** | Harvests `char[source]` into a dedicated **srctag column** of its codebook workbook (with every other characteristic beside it), so the finished codebook answers the provenance question for someone without Stata. Its `dofile()` option snapshots *all* metadata — lineage tags included — into a relabel do-file. | `ssc install datadictionary` |
| **srcfind** | Ships in this package: the reader for everything srctag writes. | (included) |

The round trip that makes the tags durable: send data out as a bare CSV,
get it back edited, restore every tag in one `do`:

```stata
datadictionary, dofile("relabel.do")
export delimited using "share.csv", nolabel replace
* ... collaborator edits share.csv in R / Python / Excel ...
import delimited using "share.csv", varnames(1) case(preserve) clear
do relabel.do        // labels AND srctags restored
srctag verify        // then re-check the data signature
```

For a machine-readable inventory of the tags (one row per variable per
tag, editable and re-appliable), use `srcfind , all saving("lineage.dta")`.

## Testing

A test battery ships as an ancillary file (`net get srctag`):

```bash
stata-mp -b do test_srctag.do
```

18 blocks cover the tagging contract, guard semantics, the manifest,
save/use persistence, every search mode, the warehouse scan, audits,
exports, and sign/verify.

## Authors

- Eric A. Booth — eric.a.booth@gmail.com
- Elizabeth Teas — elizabeth@farharbor.com

## License

MIT — see [LICENSE](LICENSE).
