*! version 2.0.1  Eric A. Booth and Elizabeth Teas  09nov2026
*! srctag: stamp variables with their source lineage in characteristics
*! v2.0.1 keeps a $ inside tag text (OData/Socrata ?$where= URLs, "$USD"):
*!        stamping, show, and the sources manifest expand tag text through
*!        macval(), so nothing is macro-expanded away.
*! v2.0.0 merges the structured-field schema (src_agency, src_dataset,
*!        src_url, src_vintage, src_category, key/value) and the show
*!        subcommand into the v1 source/vintage/notes front door.
program define srctag, rclass
    version 16.0

    * ---- subcommand: srctag sign / srctag verify --------------------------
    * sign stores a -datasignature- fingerprint beside the lineage tags;
    * verify recomputes it, so stale provenance (tags describing data that
    * has since changed) is caught instead of trusted.
    gettoken first rest : 0, parse(" ,")
    if lower(`"`first'"') == "sign" {
        quietly datasignature
        char _dta[src_signature] `"`r(datasignature)'"'
        char _dta[src_signed] `"`c(current_date)' `c(current_time)'"'
        di as txt "srctag sign: data signature stored (" ///
            as res `"`r(datasignature)'"' as txt ")"
        return local signature `"`r(datasignature)'"'
        exit 0
    }
    if lower(`"`first'"') == "verify" {
        local stored : char _dta[src_signature]
        if `"`stored'"' == "" {
            di as err "srctag verify: no signature stored; run srctag sign first"
            exit 198
        }
        quietly datasignature
        local now `"`r(datasignature)'"'
        local when : char _dta[src_signed]
        if `"`now'"' == `"`stored'"' {
            di as txt "srctag verify: data unchanged since signing (`when')"
            return scalar match = 1
            exit 0
        }
        di as err "srctag verify: data have CHANGED since the lineage tags were signed (`when')"
        di as err "               the source tags may describe data that no longer exists"
        exit 459
    }

    * ---- subcommand: srctag apply using file ------------------------------
    * Applies edited lineage metadata from the layout srcfind's saving()
    * writes (string variables varname, charname, value; a file column is
    * ignored).  This closes the human-review loop: export the tags, let a
    * reviewer correct them, fold the corrections back in.
    if lower(`"`first'"') == "apply" {
        srctag_apply `rest'
        return add
        exit
    }

    * ---- subcommand: srctag show varlist  (alias: profile) ---------------
    if inlist(lower(`"`first'"'), "show", "profile") {
        local rest : list clean rest
        if `"`rest'"' == "" {
            di as err "srctag `first': supply one or more variable names"
            exit 198
        }
        foreach v of local rest {
            capture confirm variable `v'
            if _rc {
                di as err "srctag `first': variable `v' not found"
                exit 111
            }
            srctag_show_one `v'
        }
        exit 0
    }

    syntax varlist, [        ///
        SOurce(string)       ///
        Vintage(string)      ///
        NOTEs(string)        ///
        AGency(string)       ///
        DATaset(string)      ///
        URL(string)          ///
        CATegory(string)     ///
        KEY(name)            ///
        VALue(string asis)   ///
        replace              ///
        ]

    if ("`key'" == "" & `"`macval(value)'"' != "") | ("`key'" != "" & `"`macval(value)'"' == "") {
        di as err "srctag: key() and value() must be supplied together"
        exit 198
    }
    if `"`macval(source)'`macval(vintage)'`macval(notes)'`macval(agency)'`macval(dataset)'`macval(url)'`macval(category)'`key'"' == "" {
        di as err "srctag: supply at least one of source() vintage() notes() " ///
            "agency() dataset() url() category() or key()/value()"
        exit 198
    }

    * Build the (characteristic, value) pairs this call writes.  source(),
    * vintage(), and notes() are the v1 names the book prints; the src_*
    * fields are the structured schema.  Both live side by side.
    local npairs 0
    if `"`macval(source)'"' != "" {
        local ++npairs
        local pc`npairs' "source"
        local pv`npairs' `"`macval(source)'"'
    }
    if `"`macval(vintage)'"' != "" {
        local ++npairs
        local pc`npairs' "source_vintage"
        local pv`npairs' `"`macval(vintage)'"'
    }
    if `"`macval(notes)'"' != "" {
        local ++npairs
        local pc`npairs' "source_notes"
        local pv`npairs' `"`macval(notes)'"'
    }
    if `"`macval(agency)'"' != "" {
        local ++npairs
        local pc`npairs' "src_agency"
        local pv`npairs' `"`macval(agency)'"'
    }
    if `"`macval(dataset)'"' != "" {
        local ++npairs
        local pc`npairs' "src_dataset"
        local pv`npairs' `"`macval(dataset)'"'
    }
    if `"`macval(url)'"' != "" {
        local ++npairs
        local pc`npairs' "src_url"
        local pv`npairs' `"`macval(url)'"'
    }
    if `"`macval(category)'"' != "" {
        local ++npairs
        local pc`npairs' "src_category"
        local pv`npairs' `"`macval(category)'"'
    }
    if "`key'" != "" {
        local ++npairs
        local pc`npairs' "`key'"
        local pv`npairs' `"`macval(value)'"'
    }

    * ---- the overwrite guard, uniformly on every characteristic ----------
    * Changing an existing tag needs -replace-; re-stamping the identical
    * value is a no-op, so a tagging do-file can run top to bottom twice
    * without erroring on its own earlier work.  The guard checks the whole
    * varlist before the first write, so a refused call changes nothing.
    foreach v of varlist `varlist' {
        forvalues j = 1/`npairs' {
            local cur : char `v'[`pc`j'']
            if `"`macval(cur)'"' != "" & `"`macval(cur)'"' != `"`macval(pv`j')'"' & "`replace'" == "" {
                di as err `"srctag: `v' already carries `pc`j'' (`macval(cur)'); add replace to overwrite"'
                exit 110
            }
        }
    }

    * ---- write the tags ---------------------------------------------------
    local n = 0
    foreach v of varlist `varlist' {
        forvalues j = 1/`npairs' {
            char `v'[`pc`j''] `"`macval(pv`j')'"'
        }
        local ++n
    }

    * ---- dataset-level manifest of distinct source() values --------------
    * block-form if: a one-line if re-expands its command, which would drop
    * a $ in the source text
    if `"`macval(source)'"' != "" {
        srctag_addmani `"`macval(source)'"'
    }

    if `"`macval(source)'"' != "" {
        di as txt "srctag: stamped " as res `n' as txt " variable(s) with source " ///
            as res `"`macval(source)'"'
    }
    else {
        di as txt "srctag: stamped " as res `n' as txt " variable(s)"
    }
    return scalar n = `n'
end

* ---- srctag_show_one: everything known about one variable's lineage ------
program define srctag_show_one
    version 16.0
    args v

    local lab    : variable label `v'
    local type   : type `v'
    local fmt    : format `v'
    local vallab : value label `v'

    di as txt "{hline 72}"
    di as txt "{bf:srctag:} " as res `"{stata "describe `v'":`v'}"' ///
        as txt "  " `"`macval(lab)'"'
    di as txt "{hline 72}"
    di as txt "  storage type" _col(20) ": " as res "`type'" _col(44) as txt "format: " as res "`fmt'"
    if "`vallab'" != "" di as txt "  value label" _col(20) ": " as res "`vallab'"

    * v1 names first (what the book prints), then the structured fields.
    foreach c in source source_vintage source_notes {
        local cv : char `v'[`c']
        if `"`macval(cv)'"' != "" {
            * the clickable command escapes $ so the search runs on the tag
            local lk = subinstr(`"`macval(cv)'"', char(36), char(92) + char(36), .)
            di as txt "  `c'" _col(20) ": " as res `"{stata `"srcfind `macval(lk)'"':`macval(cv)'}"'
        }
    }
    foreach c in src_agency src_dataset src_vintage src_category {
        local cv : char `v'[`c']
        if `"`macval(cv)'"' != "" {
            local lk = subinstr(`"`macval(cv)'"', char(36), char(92) + char(36), .)
            di as txt "  `c'" _col(20) ": " as res `"{stata `"srcfind `macval(lk)', char(`c')"':`macval(cv)'}"'
        }
    }
    local u : char `v'[src_url]
    if `"`macval(u)'"' != "" {
        di as txt "  src_url" _col(20) ": " as res `"{browse "`macval(u)'":`macval(u)'}"'
    }

    * anything else the variable carries, shown so nothing hides
    local core source source_vintage source_notes src_agency src_dataset ///
        src_vintage src_category src_url
    local cnames : char `v'[]
    local extras : list cnames - core
    if `"`extras'"' != "" {
        di as txt "  other characteristics:"
        foreach c of local extras {
            local cv : char `v'[`c']
            di as txt "    `c'" _col(20) ": " as res `"`macval(cv)'"'
        }
    }
    di as txt "{hline 72}"
end

* ---- srctag_addmani: add one source to the _dta[sources] manifest --------
*      Entries are separated by "; ".  Membership is checked entry by entry:
*      a substring check would silently drop a new source that happens to be
*      a substring of one already recorded ("dealer" after "dealer file").
program define srctag_addmani
    version 16.0
    gettoken src 0 : 0
    local mani : char _dta[sources]
    local found 0
    local rest2 `"`macval(mani)'"'
    while `"`macval(rest2)'"' != "" {
        local p = strpos(`"`macval(rest2)'"', "; ")
        if `p' {
            local seg   = substr(`"`macval(rest2)'"', 1, `p' - 1)
            local rest2 = substr(`"`macval(rest2)'"', `p' + 2, .)
        }
        else {
            local seg `"`macval(rest2)'"'
            local rest2 ""
        }
        if `"`macval(seg)'"' == `"`macval(src)'"' local found 1
    }
    if !`found' {
        local sep = cond(`"`macval(mani)'"' == "", "", "; ")
        char _dta[sources] `"`macval(mani)'`sep'`macval(src)'"'
    }
end

* ---- srctag_apply: fold edited lineage metadata back into the data -------
*      Reads the layout srcfind's saving() writes: one row per variable per
*      characteristic, string variables varname, charname, value (a file
*      column, if present, is ignored -- apply works on the data in memory).
*      The overwrite guard holds here too: a row that would CHANGE an
*      existing tag is held back unless -replace- is given, and the receipt
*      says exactly what happened to every row.
program define srctag_apply, rclass
    version 16.0
    syntax using/ [, replace]

    tempname fr
    frame create `fr'
    capture frame `fr': use `"`using'"', clear
    if _rc {
        frame drop `fr'
        di as err `"srctag apply: `using' could not be opened as a dataset"'
        exit 601
    }
    foreach need in varname charname value {
        capture frame `fr': confirm string variable `need', exact
        if _rc {
            frame drop `fr'
            di as err "srctag apply: the file must hold string variables varname,"
            di as err "              charname, and value -- the layout that"
            di as err "              srcfind's saving() writes"
            exit 198
        }
    }

    local N = 0
    frame `fr': local N = _N
    local napplied  = 0
    local nsame     = 0
    local nheld     = 0
    local nskipvar  = 0
    local nskipname = 0
    local nblank    = 0
    local missvars ""
    forvalues i = 1/`N' {
        frame `fr' {
            local v = varname[`i']
            local c = charname[`i']
            local x = value[`i']
        }
        * rows with no charname are the untagged placeholders saving() writes
        if "`c'" == "" {
            local ++nblank
            continue
        }
        capture confirm name `c'
        if _rc {
            local ++nskipname
            continue
        }
        capture confirm variable `v', exact
        if _rc {
            local ++nskipvar
            if !`: list posof "`v'" in missvars' local missvars "`missvars' `v'"
            continue
        }
        local cur : char `v'[`c']
        if `"`macval(cur)'"' == `"`macval(x)'"' {
            local ++nsame
            continue
        }
        if `"`macval(cur)'"' != "" & "`replace'" == "" {
            local ++nheld
            local held`nheld' "`v'[`c']"
            continue
        }
        char `v'[`c'] `"`macval(x)'"'
        if "`c'" == "source" & `"`macval(x)'"' != "" {
            srctag_addmani `"`macval(x)'"'
        }
        local ++napplied
    }
    frame drop `fr'

    * ---- the receipt ------------------------------------------------------
    di as txt "srctag apply: " as res `napplied' as txt " tag(s) applied, " ///
        as res `nsame' as txt " already current"
    if `nheld' {
        di as err "              `nheld' row(s) would CHANGE an existing tag and were"
        di as err "              held back; add replace to apply them:"
        forvalues j = 1/`nheld' {
            di as err "                `held`j''"
        }
    }
    if `nskipvar' {
        local missvars : list retokenize missvars
        di as txt `"              skipped (variable not in memory):`missvars'"'
    }
    if `nskipname' ///
        di as txt "              skipped `nskipname' row(s) with an invalid charname"
    if `nblank' ///
        di as txt "              ignored `nblank' untagged placeholder row(s)"
    local sig : char _dta[src_signature]
    if `"`sig'"' != "" & `napplied' > 0 ///
        di as txt `"              the data are signed; rerun {stata "srctag sign":srctag sign} to restamp the signing time over the edited tags"'

    return scalar n_applied = `napplied'
    return scalar n_same    = `nsame'
    return scalar n_held    = `nheld'
    return scalar n_skipped = `nskipvar' + `nskipname'
end
