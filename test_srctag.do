* test_srctag.do -- behavioral contract for srctag + srcfind v2.0.0
* Run from the directory holding srctag.ado and srcfind.ado:
*   do test_srctag.do
clear all
adopath ++ "`c(pwd)'"
set varabbrev off

sysuse auto, clear

* --- (1) stamp and read back (v1 front door, unchanged) ----------------------
srctag price mpg, source(dealer file 2026) vintage(2026-07)
assert r(n) == 2
local s : char price[source]
assert `"`s'"' == "dealer file 2026"
local v : char mpg[source_vintage]
assert `"`v'"' == "2026-07"

* --- (2) refuse silent overwrite; allow with replace -------------------------
capture noisily srctag price, source(other)
assert _rc == 110
srctag price, source(EPA extract) replace
local s : char price[source]
assert `"`s'"' == "EPA extract"

* --- (2b) re-stamping the IDENTICAL value is a no-op, not an error -----------
* (a tagging do-file must be rerunnable top to bottom)
capture noisily srctag price, source(EPA extract)
assert _rc == 0
local s : char price[source]
assert `"`s'"' == "EPA extract"

* --- (3) srcfind by pattern and all (v1 contract) ----------------------------
srctag weight length, source(dealer file 2026)
srcfind dealer, noreport
assert r(n) == 3
assert strpos("`r(varlist)'", "mpg") > 0
srcfind , all noreport
assert r(n) == 4
srcfind nomatch, noreport
assert r(n) == 0

* --- (3b) dataset-level manifest accumulates unique sources ------------------
local m : char _dta[sources]
assert strpos(`"`m'"', "dealer file 2026") > 0
assert strpos(`"`m'"', "EPA extract") > 0

* --- (3c) manifest membership is entry-exact, not substring ------------------
* "dealer" is a substring of "dealer file 2026" and still gets its own entry
srctag turn, source(dealer)
local m : char _dta[sources]
assert strpos(`"`m'"', "; dealer") > 0 | substr(`"`m'"', 1, 6) == "dealer"
* ... and stamping the same source twice does not duplicate the entry
srctag trunk, source(dealer)
local m2 : char _dta[sources]
assert `"`m2'"' == `"`m'"'

* --- (4) characteristics survive save/use ------------------------------------
tempfile t
save "`t'"
use "`t'", clear
local s : char mpg[source]
assert `"`s'"' == "dealer file 2026"

* --- (5) structured fields write the src_* schema ----------------------------
srctag headroom, agency(TWC) dataset(wage ledger) url(https://example.gov/twc) ///
    vintage(2025q3) category(labor)
local a : char headroom[src_agency]
assert `"`a'"' == "TWC"
local d : char headroom[src_dataset]
assert `"`d'"' == "wage ledger"
local u : char headroom[src_url]
assert `"`u'"' == "https://example.gov/twc"
* vintage() writes the v1 slot even when given with structured fields
local vv : char headroom[source_vintage]
assert `"`vv'"' == "2025q3"

* --- (5b) key()/value() writes an arbitrary characteristic -------------------
srctag headroom, key(src_confidence) value(high)
local k : char headroom[src_confidence]
assert `"`k'"' == "high"
capture noisily srctag headroom, key(src_confidence)
assert _rc == 198
capture noisily srctag headroom, value(low)
assert _rc == 198

* --- (5c) the guard covers structured fields too -----------------------------
capture noisily srctag headroom, agency(BLS)
assert _rc == 110
srctag headroom, agency(BLS) replace
local a : char headroom[src_agency]
assert `"`a'"' == "BLS"

* --- (6) srctag show runs and errors correctly -------------------------------
srctag show headroom
capture noisily srctag show nosuchvar
assert _rc == 111
capture noisily srctag show
assert _rc == 198

* --- (7) srcfind reaches structured fields by default ------------------------
srcfind ledger, noreport
assert r(n) == 1
assert "`r(varlist)'" == "headroom"

* --- (8) match modes: exact, wildcard, case sensitivity ----------------------
srcfind dealer, exact noreport
* exact "dealer" matches turn and trunk, not "dealer file 2026"
assert r(n) == 2
assert wordcount("`r(varlist)'") == 2
srcfind "dealer*", wildcard noreport
assert r(n) == 5
srcfind DEALER, noreport
assert r(n) == 5
srcfind DEALER, casesensitive noreport
assert r(n) == 0
capture noisily srcfind x, exact wildcard
assert _rc == 198

* --- (9) char() restricts the search to one characteristic -------------------
srcfind BLS, char(src_agency) noreport
assert r(n) == 1
srcfind dealer, char(src_agency) noreport
assert r(n) == 0

* --- (10) into() hands the varlist to the calling scope ----------------------
srcfind dealer, noreport into(myhits)
assert wordcount("`myhits'") == 5

* --- (11) tags and values subcommands ----------------------------------------
srcfind tags, nolinks
assert r(N_tags) >= 4
assert strpos("`r(tags)'", "source") > 0
srcfind values source, nolinks
assert r(N_values) >= 3
srcfind values src_agency, nolinks
assert r(N_values) == 1

* --- (12) warehouse scan: dir() reads headers, not data ----------------------
* build a little warehouse in a scratch folder
local wh "`c(tmpdir)'/srcfind_wh_test"
capture mkdir "`wh'"
preserve
    sysuse auto, clear
    srctag price mpg, source(TWC wage file) vintage(2026q2) replace
    quietly save "`wh'/tagged.dta", replace
    sysuse bplong, clear
    quietly save "`wh'/untagged.dta", replace
    clear
    set obs 0
    generate byte empty_var = .
    srctag empty_var, source(TWC empty) replace
    quietly save "`wh'/zero_obs.dta", replace
restore
* memory must be untouched by the scan (frames do the work)
local before = _N
srcfind TWC, dir("`wh'") noreport
assert r(n) == 3
assert r(nfiles) == 3
assert strpos(`"`r(files)'"', "tagged.dta") > 0
assert strpos(`"`r(files)'"', "zero_obs.dta") > 0
assert strpos(`"`r(files)'"', "untagged") == 0
assert _N == `before'
local s : char price[source]
assert `"`s'"' == "EPA extract"
* a directory that is not there errors clearly
capture noisily srcfind TWC, dir("`wh'/nope") noreport
assert _rc == 601
* clean the scratch warehouse
capture erase "`wh'/tagged.dta"
capture erase "`wh'/untagged.dta"
capture erase "`wh'/zero_obs.dta"
capture rmdir "`wh'"

* --- (13) profile chains srcfind into srctag show ----------------------------
srcfind BLS, char(src_agency) profile

* --- (15) untagged audit and not inversion -----------------------------------
srcfind , untagged noreport
* auto has 12 vars; tagged so far: price mpg weight length turn trunk headroom
assert r(n) == 5
srcfind dealer, not noreport
* complement of the 5 dealer matches over all 12 vars
assert r(n) == 7
capture noisily srcfind , not noreport
assert _rc == 198
capture noisily srcfind dealer, untagged noreport
assert _rc == 198
capture noisily srcfind dealer, not all noreport
assert _rc == 198

* --- (16) local() hands off like into() --------------------------------------
srcfind dealer, noreport local(lhits)
assert "`lhits'" == "`myhits'"

* --- (17) saving() writes the metadataset ------------------------------------
tempfile meta
srcfind , all noreport saving("`meta'", replace)
preserve
    use "`meta'", clear
    assert _N >= 8
    confirm variable file varname charname value
    quietly count if varname == "headroom" & charname == "src_agency"
    assert r(N) == 1
restore

* --- (18) sign and verify catch stale provenance -----------------------------
srctag sign
local sg : char _dta[src_signature]
assert `"`sg'"' != ""
srctag verify
assert r(match) == 1
quietly replace price = price + 1 in 1
capture noisily srctag verify
assert _rc == 459
quietly replace price = price - 1 in 1
srctag verify
assert r(match) == 1
preserve
    clear
    set obs 1
    generate x = 1
    capture noisily srctag verify
    assert _rc == 198
restore

* --- (19) apply: the human-review round trip ---------------------------------
* export the tags, edit them the way a metadata reviewer would, fold the
* edits back in with the guard and receipt intact
tempfile lin lin2
srcfind , all noreport saving("`lin'.dta", replace)
preserve
    use "`lin'.dta", clear
    * reviewer corrects one vintage, clears one notes-style tag via a new
    * row, retags a variable that no longer exists, and leaves the rest
    quietly replace value = "2026-08" if varname == "mpg" & charname == "source_vintage"
    quietly count
    local addrow = r(N) + 1
    quietly set obs `addrow'
    quietly replace varname  = "ghostvar"    in `addrow'
    quietly replace charname = "source"      in `addrow'
    quietly replace value    = "phantom file" in `addrow'
    quietly save "`lin2'.dta", replace
restore
* without replace: the changed vintage is held back, nothing else changes
srctag apply using "`lin2'.dta"
assert r(n_held) == 1
assert r(n_applied) == 0
assert r(n_skipped) == 1
local vv : char mpg[source_vintage]
assert `"`vv'"' == "2026-07"
* with replace: the edit lands; unchanged rows report as already current
srctag apply using "`lin2'.dta", replace
assert r(n_applied) == 1
assert r(n_held) == 0
local vv : char mpg[source_vintage]
assert `"`vv'"' == "2026-08"
* rerun is a no-op (everything already current)
srctag apply using "`lin2'.dta", replace
assert r(n_applied) == 0
assert r(n_same) >= 1
* a new source value applied through apply reaches the manifest
preserve
    clear
    quietly set obs 1
    generate str32 varname  = "turn"
    generate str32 charname = "source"
    generate str244 value   = "auditor list 2026"
    quietly save "`lin2'.dta", replace
restore
srctag apply using "`lin2'.dta", replace
assert r(n_applied) == 1
local m : char _dta[sources]
assert strpos(`"`m'"', "auditor list 2026") > 0
* a file without the expected layout errors clearly
preserve
    sysuse bplong, clear
    quietly save "`lin2'.dta", replace
restore
capture noisily srctag apply using "`lin2'.dta"
assert _rc == 198
capture noisily srctag apply using "`c(tmpdir)'/no_such_file_xyz.dta"
assert _rc == 601

* --- (14) the book's printed example, verbatim -------------------------------
preserve
    clear
    set obs 5
    generate q_wage  = 100
    generate q_hours = 40
    srctag q_wage q_hours, source(TWC wage file) vintage(2026q2)
    assert r(n) == 2
    srcfind TWC
    assert r(n) == 2
    assert "`r(varlist)'" == "q_wage q_hours"
restore

di as res "ALL TESTS PASSED"
