*! version 2.0.0  Eric A. Booth and Elizabeth Teas  08aug2026
*! srcfind: find variables by their srctag source lineage
*! v2.0.0 adds the warehouse scan (dir()), structured-field search,
*!        exact/wildcard modes, untagged/not audits, saving() export,
*!        local() hand-off, and the tags/values subcommands.
program define srcfind, rclass
    version 16.0

    * ---- subcommands: srcfind tags | srcfind values <charname> -----------
    gettoken first rest : 0, parse(" ,")
    if inlist(lower(`"`first'"'), "tags", "taglist") {
        srcfind_tags `rest'
        return add
        exit
    }
    if lower(`"`first'"') == "values" {
        srcfind_values `rest'
        return add
        exit
    }

    syntax [anything(name=pattern)] , [SOurce(string) CHar(name) All      ///
        UNTagged NOT noREPort EXact WILDcard CASEsensitive DIR(string)    ///
        INTO(name) LOCal(name) SAVing(string asis) PROFile]

    if "`exact'" != "" & "`wildcard'" != "" {
        di as err "srcfind: choose either exact or wildcard, not both"
        exit 198
    }
    if `"`source'"' == "" & `"`pattern'"' != "" local source `"`pattern'"'
    local source = strtrim(subinstr(`"`source'"', `"""', "", .))
    if "`untagged'" != "" & (`"`source'"' != "" | "`all'" != "") {
        di as err "srcfind: untagged cannot be combined with a pattern or all"
        exit 198
    }
    if "`not'" != "" & `"`source'"' == "" {
        di as err "srcfind: not requires a pattern to invert"
        exit 198
    }
    if "`not'" != "" & "`all'" != "" {
        di as err "srcfind: not cannot be combined with all"
        exit 198
    }
    * a name-type option cannot be handed on empty, so build it conditionally
    local chopt = cond("`char'" == "", "", "char(`char')")

    local mode "contains"
    if "`exact'"    != "" local mode "exact"
    if "`wildcard'" != "" local mode "wildcard"

    * ---- saving(): open the metadataset postfile --------------------------
    * One row per (selected variable, lineage characteristic); a selected
    * variable with no lineage rows (untagged) posts one row with empty
    * charname/value.  The file column is filled during a warehouse scan.
    local postopt ""
    if `"`saving'"' != "" {
        gettoken savefile saverest : saving, parse(",")
        local savefile = strtrim(subinstr(`"`savefile'"', `"""', "", .))
        local saverep  = cond(strpos(lower(`"`saverest'"'), "replace"), "replace", "")
        tempname sfpost
        tempfile sfres
        postfile `sfpost' str244 file str32 varname str32 charname ///
            str2000 value using `"`sfres'"', replace
        local postopt "post(`sfpost')"
    }

    * ---- warehouse scan: srcfind <pattern>, dir(folder) -------------------
    * Each .dta is opened in a scratch frame -- first observation only, so
    * the scan reads headers and characteristics without loading the data or
    * disturbing what is in memory.
    if `"`dir'"' != "" {
        local d `"`dir'"'
        if inlist(substr(`"`d'"', -1, 1), "/", "\") {
            local d = substr(`"`d'"', 1, strlen(`"`d'"') - 1)
        }
        capture local files : dir `"`d'"' files "*.dta"
        if _rc {
            capture postclose `sfpost'
            di as err `"srcfind: dir(`dir') is not a directory that can be listed"'
            exit 601
        }
        tempname sf
        frame create `sf'
        local totn    = 0
        local nfiles  = 0
        local nskip   = 0
        local mfiles ""
        foreach f of local files {
            local ++nfiles
            capture frame `sf': use in 1 using `"`d'/`f'"', clear
            if _rc capture frame `sf': use `"`d'/`f'"', clear
            if _rc {
                local ++nskip
                if "`report'" != "noreport" ///
                    di as txt `"srcfind: skipped `f' (could not be read)"'
                continue
            }
            frame `sf' {
                srcfind_scan, source(`"`source'"') `chopt' `all'          ///
                    `untagged' `not' mode(`mode') `casesensitive' `report' ///
                    fileprefix(`"`f'"') `postopt'
            }
            if "`sfhits'" != "" {
                local totn = `totn' + `: word count `sfhits''
                local mfiles `"`mfiles' "`f'""'
            }
        }
        frame drop `sf'
        if "`report'" != "noreport" & `totn' == 0 ///
            di as txt "srcfind: no variables match in `nfiles' file(s)"
        if `"`saving'"' != "" {
            postclose `sfpost'
            srcfind_savefinish `"`sfres'"' `"`savefile'"' "`saverep'"
        }
        return scalar n      = `totn'
        return scalar nfiles = `nfiles'
        return local  files  `"`mfiles'"'
        exit 0
    }

    * ---- in-memory search -------------------------------------------------
    srcfind_scan, source(`"`source'"') `chopt' `all' `untagged' `not' ///
        mode(`mode') `casesensitive' `report' `postopt'
    local found "`sfhits'"

    if "`report'" != "noreport" & "`found'" == "" ///
        di as txt "srcfind: no variables match"
    local nf : word count `found'
    return local varlist "`found'"
    return scalar n = `nf'
    if "`into'"  != "" c_local `into'  "`found'"
    if "`local'" != "" c_local `local' "`found'"

    if `"`saving'"' != "" {
        postclose `sfpost'
        srcfind_savefinish `"`sfres'"' `"`savefile'"' "`saverep'"
    }

    if "`profile'" != "" {
        foreach v of local found {
            srctag show `v'
        }
    }
end

* ---- srcfind_savefinish: land the posted metadataset where asked ---------
program define srcfind_savefinish
    version 16.0
    args res target rep
    preserve
    quietly use `"`res'"', clear
    quietly compress
    local nr = _N
    capture noisily save `"`target'"', `rep'
    if _rc {
        restore
        di as err `"srcfind: saving(`target') could not be written"'
        exit 602
    }
    di as txt `"srcfind: metadataset saved to `target' (`nr' row(s))"'
    restore
end

* ---- srcfind_scan: match over the dataset in the CURRENT frame -----------
* Hands the matching varlist back through c_local sfhits and prints the
* report lines itself (prefixed with the file name during a warehouse scan).
* With post(), also posts one metadataset row per lineage characteristic of
* each selected variable.
program define srcfind_scan
    version 16.0
    syntax , [SOurce(string) CHar(name) All UNTagged NOT Mode(string) ///
        CASEsensitive noREPort FILEprefix(string) POST(name)]

    local hits ""
    local hdr = 0
    capture unab allv : *
    if _rc local allv ""
    foreach v of local allv {
        * candidate characteristics: char() when named; otherwise the v1
        * -source- slot plus every structured src_* field the variable has
        if "`char'" != "" {
            local cands "`char'"
        }
        else {
            local cands "source"
            local cn : char `v'[]
            foreach c of local cn {
                if substr("`c'", 1, 4) == "src_" local cands "`cands' `c'"
            }
        }
        local tagged = 0
        local mval ""
        local firstval ""
        foreach c of local cands {
            local s : char `v'[`c']
            if `"`s'"' == "" continue
            if !`tagged' local firstval `"`s'"'
            local tagged = 1
            if "`untagged'" != "" continue, break
            if "`all'" != "" {
                local mval `"`s'"'
                continue, break
            }
            local lhs `"`s'"'
            local rhs `"`source'"'
            if "`casesensitive'" == "" {
                local lhs = lower(`"`lhs'"')
                local rhs = lower(`"`rhs'"')
            }
            local ok 0
            if "`mode'" == "exact" {
                if `"`lhs'"' == `"`rhs'"' local ok 1
            }
            else if "`mode'" == "wildcard" {
                if strmatch(`"`lhs'"', `"`rhs'"') local ok 1
            }
            else {
                if strpos(`"`lhs'"', `"`rhs'"') | `"`rhs'"' == "" local ok 1
            }
            if `ok' & `"`mval'"' == "" local mval `"`s'"'
        }
        * selection rule
        local sel = 0
        if "`untagged'" != "" local sel = !`tagged'
        else if "`all'" != "" local sel = (`"`mval'"' != "")
        else {
            local sel = (`"`mval'"' != "")
            if "`not'" != "" local sel = !`sel'
        }
        if !`sel' continue
        local hits "`hits' `v'"
        if "`report'" != "noreport" {
            if !`hdr' & `"`fileprefix'"' != "" {
                di as txt `"`fileprefix':"'
                local hdr = 1
            }
            local ind = cond(`"`fileprefix'"' == "", "", "  ")
            local vin : char `v'[source_vintage]
            if `"`vin'"' == "" local vin : char `v'[src_vintage]
            * a -not- hit is tagged with something ELSE: show that, not a
            * misleading "(no source tag)"
            local dval `"`mval'"'
            if `"`dval'"' == "" local dval `"`firstval'"'
            if `"`dval'"' == "" {
                di as txt "`ind'" %-16s "`v'" as txt "(no source tag)"
            }
            else if `"`vin'"' != "" {
                di as txt "`ind'" %-16s "`v'" as res `"`dval'"' ///
                    as txt " (" as res `"`vin'"' as txt ")"
            }
            else di as txt "`ind'" %-16s "`v'" as res `"`dval'"'
        }
        if "`post'" != "" {
            local nrows = 0
            foreach c of local cands {
                local s : char `v'[`c']
                if `"`s'"' == "" continue
                post `post' (`"`fileprefix'"') ("`v'") ("`c'") (`"`s'"')
                local ++nrows
            }
            foreach c in source_vintage source_notes {
                local s : char `v'[`c']
                if `"`s'"' != "" & "`char'" == "" {
                    post `post' (`"`fileprefix'"') ("`v'") ("`c'") (`"`s'"')
                    local ++nrows
                }
            }
            if `nrows' == 0 post `post' (`"`fileprefix'"') ("`v'") ("") ("")
        }
    }
    local hits : list retokenize hits
    c_local sfhits "`hits'"
end

* ---- srcfind tags [, all nolinks] ----------------------------------------
* List the lineage characteristic NAMES in the data in memory, with the
* count of variables carrying each.  -all- widens the sweep to every
* characteristic, not just source/source_* and src_*.
program define srcfind_tags, rclass
    version 16.0
    syntax [, All NOLinks]

    capture unab allv : *
    if _rc local allv ""
    local names ""
    foreach v of local allv {
        local cn : char `v'[]
        foreach c of local cn {
            if "`all'" == "" {
                if substr("`c'", 1, 4) != "src_" ///
                    & !inlist("`c'", "source", "source_vintage", "source_notes") continue
            }
            local kn : list posof "`c'" in names
            if `kn' {
                local cnt`kn' = `cnt`kn'' + 1
            }
            else {
                local names "`names' `c'"
                local kn : word count `names'
                local cnt`kn' = 1
            }
        }
    }
    local names : list retokenize names
    local ntags : word count `names'
    return scalar N_tags = `ntags'
    return local tags "`names'"
    if `ntags' == 0 {
        di as txt "srcfind tags: no source tags found"
        exit 0
    }
    di as txt "lineage tag names in memory  (n=" as res `ntags' as txt "):"
    local j = 0
    foreach c of local names {
        local ++j
        if "`nolinks'" == "" {
            di as txt "  " as res `"{stata "srcfind values `c'":`c'}"' ///
                as txt "  (tagged vars=" as res `cnt`j'' as txt ")"
        }
        else {
            di as txt "  " as res "`c'" as txt "  (tagged vars=" as res `cnt`j'' as txt ")"
        }
    }
end

* ---- srcfind values <charname> [, nolinks] -------------------------------
* List the distinct VALUES a lineage characteristic takes, with counts.
program define srcfind_values, rclass
    version 16.0
    syntax anything(name=cname) [, NOLinks]
    gettoken cname junk : cname
    confirm name `cname'

    capture unab allv : *
    if _rc local allv ""
    * Distinct values can hold spaces, so index them in numbered locals.
    local nvals = 0
    foreach v of local allv {
        local cv : char `v'[`cname']
        if `"`cv'"' == "" continue
        local hit = 0
        forvalues j = 1/`nvals' {
            if `"`val`j''"' == `"`cv'"' {
                local cnt`j' = `cnt`j'' + 1
                local hit = 1
                continue, break
            }
        }
        if !`hit' {
            local ++nvals
            local val`nvals' `"`cv'"'
            local cnt`nvals' = 1
        }
    }
    return scalar N_values = `nvals'
    if `nvals' == 0 {
        di as txt "srcfind values " as inp "`cname'" as txt ": no nonempty values found"
        exit 0
    }
    di as txt "distinct values of char[" as inp "`cname'" as txt "]  (n=" ///
        as res `nvals' as txt "):"
    forvalues j = 1/`nvals' {
        if "`nolinks'" == "" {
            local opt = cond("`cname'" == "source", "", ", char(`cname')")
            di as txt "  " as res `"{stata `"srcfind `val`j''`opt'"':`val`j''}"' ///
                as txt "  (vars=" as res `cnt`j'' as txt ")"
        }
        else {
            di as txt "  " as res `"`val`j''"' as txt "  (vars=" as res `cnt`j'' as txt ")"
        }
    }
end
