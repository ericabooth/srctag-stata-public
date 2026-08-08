*! version 2.0.0  Eric A. Booth and Elizabeth Teas  08aug2026
*! srctag: stamp variables with their source lineage in characteristics
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

    if ("`key'" == "" & `"`value'"' != "") | ("`key'" != "" & `"`value'"' == "") {
        di as err "srctag: key() and value() must be supplied together"
        exit 198
    }
    if `"`source'`vintage'`notes'`agency'`dataset'`url'`category'`key'"' == "" {
        di as err "srctag: supply at least one of source() vintage() notes() " ///
            "agency() dataset() url() category() or key()/value()"
        exit 198
    }

    * Build the (characteristic, value) pairs this call writes.  source(),
    * vintage(), and notes() are the v1 names the book prints; the src_*
    * fields are the structured schema.  Both live side by side.
    local npairs 0
    if `"`source'"' != "" {
        local ++npairs
        local pc`npairs' "source"
        local pv`npairs' `"`source'"'
    }
    if `"`vintage'"' != "" {
        local ++npairs
        local pc`npairs' "source_vintage"
        local pv`npairs' `"`vintage'"'
    }
    if `"`notes'"' != "" {
        local ++npairs
        local pc`npairs' "source_notes"
        local pv`npairs' `"`notes'"'
    }
    if `"`agency'"' != "" {
        local ++npairs
        local pc`npairs' "src_agency"
        local pv`npairs' `"`agency'"'
    }
    if `"`dataset'"' != "" {
        local ++npairs
        local pc`npairs' "src_dataset"
        local pv`npairs' `"`dataset'"'
    }
    if `"`url'"' != "" {
        local ++npairs
        local pc`npairs' "src_url"
        local pv`npairs' `"`url'"'
    }
    if `"`category'"' != "" {
        local ++npairs
        local pc`npairs' "src_category"
        local pv`npairs' `"`category'"'
    }
    if "`key'" != "" {
        local ++npairs
        local pc`npairs' "`key'"
        local pv`npairs' `"`value'"'
    }

    * ---- the overwrite guard, uniformly on every characteristic ----------
    * Changing an existing tag needs -replace-; re-stamping the identical
    * value is a no-op, so a tagging do-file can run top to bottom twice
    * without erroring on its own earlier work.  The guard checks the whole
    * varlist before the first write, so a refused call changes nothing.
    foreach v of varlist `varlist' {
        forvalues j = 1/`npairs' {
            local cur : char `v'[`pc`j'']
            if `"`cur'"' != "" & `"`cur'"' != `"`pv`j''"' & "`replace'" == "" {
                di as err `"srctag: `v' already carries `pc`j'' (`cur'); add replace to overwrite"'
                exit 110
            }
        }
    }

    * ---- write the tags ---------------------------------------------------
    local n = 0
    foreach v of varlist `varlist' {
        forvalues j = 1/`npairs' {
            char `v'[`pc`j''] `"`pv`j''"'
        }
        local ++n
    }

    * ---- dataset-level manifest of distinct source() values --------------
    * Entries are separated by "; ".  Membership is checked entry by entry:
    * the v1 substring check silently dropped a new source that happened to
    * be a substring of one already recorded ("dealer" after "dealer file").
    if `"`source'"' != "" {
        local mani : char _dta[sources]
        local found 0
        local rest2 `"`mani'"'
        while `"`rest2'"' != "" {
            local p = strpos(`"`rest2'"', "; ")
            if `p' {
                local seg   = substr(`"`rest2'"', 1, `p' - 1)
                local rest2 = substr(`"`rest2'"', `p' + 2, .)
            }
            else {
                local seg `"`rest2'"'
                local rest2 ""
            }
            if `"`seg'"' == `"`source'"' local found 1
        }
        if !`found' {
            char _dta[sources] `"`mani'`=cond(`"`mani'"' == "", "", "; ")'`source'"'
        }
    }

    if `"`source'"' != "" {
        di as txt "srctag: stamped " as res `n' as txt " variable(s) with source " ///
            as res `"`source'"'
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
        as txt "  " `"`lab'"'
    di as txt "{hline 72}"
    di as txt "  storage type" _col(20) ": " as res "`type'" _col(44) as txt "format: " as res "`fmt'"
    if "`vallab'" != "" di as txt "  value label" _col(20) ": " as res "`vallab'"

    * v1 names first (what the book prints), then the structured fields.
    foreach c in source source_vintage source_notes {
        local cv : char `v'[`c']
        if `"`cv'"' != "" {
            di as txt "  `c'" _col(20) ": " as res `"{stata `"srcfind `cv'"':`cv'}"'
        }
    }
    foreach c in src_agency src_dataset src_vintage src_category {
        local cv : char `v'[`c']
        if `"`cv'"' != "" {
            di as txt "  `c'" _col(20) ": " as res `"{stata `"srcfind `cv', char(`c')"':`cv'}"'
        }
    }
    local u : char `v'[src_url]
    if `"`u'"' != "" {
        di as txt "  src_url" _col(20) ": " as res `"{browse "`u'":`u'}"'
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
            di as txt "    `c'" _col(20) ": " as res `"`cv'"'
        }
    }
    di as txt "{hline 72}"
end
