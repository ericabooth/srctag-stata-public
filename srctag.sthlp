{smcl}
{* *! version 2.0.0 08aug2026 Eric A. Booth and Elizabeth Teas}{...}
{vieweralsosee "srcfind" "help srcfind"}{...}
{vieweralsosee "[P] char" "help char"}{...}
{vieweralsosee "[D] notes" "help notes"}{...}
{vieweralsosee "[D] datasignature" "help datasignature"}{...}
{viewerjumpto "Syntax"         "srctag##syntax"}{...}
{viewerjumpto "Description"    "srctag##description"}{...}
{viewerjumpto "Options"        "srctag##options"}{...}
{viewerjumpto "Subcommands"    "srctag##subcommands"}{...}
{viewerjumpto "The ecosystem"  "srctag##ecosystem"}{...}
{viewerjumpto "Examples"       "srctag##examples"}{...}
{viewerjumpto "Stored results" "srctag##results"}{...}
{viewerjumpto "Authors"        "srctag##authors"}{...}
{hline}
{pstd}help for {hi:srctag}{p_end}
{hline}

{title:Title}

{p 4 8 2}
{bf:srctag} {hline 2} stamp variables with their source lineage, so
{cmd:where did this number come from?} has a command-line answer.
Companion command {helpb srcfind} searches the stamps.{p_end}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:srctag} {varlist}{cmd:,} [{opt so:urce(text)} {opt v:intage(text)}
{opt note:s(text)} {opt ag:ency(text)} {opt dat:aset(text)} {opt url(text)}
{opt cat:egory(text)} {opt key(name)} {opt val:ue(text)} {cmd:replace}]

{p 8 16 2}
{cmd:srctag} {cmd:show} {varlist}

{p 8 16 2}
{cmd:srctag} {cmd:apply} {cmd:using} {it:filename} [{cmd:,} {cmd:replace}]

{p 8 16 2}
{cmd:srctag} {cmd:sign}

{p 8 16 2}
{cmd:srctag} {cmd:verify}

{pstd}
At least one tagging option is required. {cmd:profile} is accepted as a
synonym for {cmd:show}.{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:srctag} writes a variable's origin into its
{help char:characteristics}, the metadata slot that survives {cmd:save}
and travels with the dataset through every later {cmd:merge} and
{cmd:append}. Stamp the sources once at import, and months later
{cmd:srcfind dealer} answers "which variables came from the dealer file?"
from the file itself rather than from anyone's memory.{p_end}

{pstd}
Two schemas live side by side. The simple one is {opt source()},
{opt vintage()}, and {opt notes()}, which write the {cmd:source},
{cmd:source_vintage}, and {cmd:source_notes} characteristics. The
structured one is {opt agency()}, {opt dataset()}, {opt url()}, and
{opt category()}, which write {cmd:src_agency}, {cmd:src_dataset},
{cmd:src_url}, and {cmd:src_category}, plus {opt key()}/{opt value()} for
any field the schema does not name. Use the simple schema when one line of
text answers the provenance question; add structured fields when different
consumers need different pieces (the URL for the analyst, the agency for
the client memo). {helpb srcfind} searches both without being told
which.{p_end}

{pstd}
{cmd:srctag} refuses to {it:change} an existing tag unless told
{cmd:replace}, so lineage cannot be overwritten silently. Re-stamping the
identical value is a no-op rather than an error, which keeps a tagging
do-file rerunnable top to bottom.{p_end}

{pstd}
Each distinct {opt source()} value is also added to a dataset-level
manifest in {cmd:_dta[sources]}, one glance at which lists every source
represented in the file ({cmd:char list _dta[sources]}).{p_end}


{marker options}{...}
{title:Options}

{phang}
{opt source(text)} records the origin in the variable's {cmd:source}
characteristic. This is the primary slot: it is what {helpb srcfind}
matches by default, what the manifest accumulates, and what
{helpb datadictionary} harvests into its codebook column.{p_end}

{phang}
{opt vintage(text)} records the data vintage (for example {cmd:2026q2} or
{cmd:FY2025 run 46820}) in {cmd:source_vintage}. {helpb srcfind} prints it
in parentheses beside each match.{p_end}

{phang}
{opt notes(text)} records free-text caveats in {cmd:source_notes}.{p_end}

{phang}
{opt agency(text)}, {opt dataset(text)}, {opt url(text)}, and
{opt category(text)} record the structured fields {cmd:src_agency},
{cmd:src_dataset}, {cmd:src_url}, and {cmd:src_category}.{p_end}

{phang}
{opt key(name)} and {opt value(text)}, which must be supplied together,
write any additional characteristic: for example
{cmd:key(src_confidence) value(high)}.{p_end}

{phang}
{cmd:replace} permits an existing tag to be changed. Without it, changing
a nonempty tag to a different value stops with error 110 and names the
variable, the characteristic, and the value it already carries.{p_end}


{marker subcommands}{...}
{title:Subcommands}

{phang}
{cmd:srctag show} {varlist} prints everything known about each variable's
lineage: storage type, labels, both schemas' tags, and any other
characteristics the variable carries. Each tag value is a clickable
{helpb srcfind} search, and {cmd:src_url} is a clickable {cmd:browse}
link.{p_end}

{phang}
{cmd:srctag apply using} {it:filename} folds edited lineage metadata back
into the data in memory. The file is the layout {helpb srcfind}'s
{opt saving()} writes -- string variables {cmd:varname}, {cmd:charname},
and {cmd:value}, one row per tag ({cmd:file}, if present, is ignored) --
so the review loop is: export the tags, let a reviewer correct them in
the Data Editor or a spreadsheet, apply the corrections. The overwrite
guard holds: a row that would {it:change} an existing tag is held back
unless {cmd:replace} is given, and a receipt reports every row's fate --
applied, already current, held, or skipped (variable not in memory, or an
invalid characteristic name). An applied {cmd:source} value joins the
{cmd:_dta[sources]} manifest. Stored results:
{cmd:r(n_applied)}, {cmd:r(n_same)}, {cmd:r(n_held)},
{cmd:r(n_skipped)}. See the
{help srctag##review:human review} section below for the full
recipe.{p_end}

{phang}
{cmd:srctag sign} computes the dataset's {helpb datasignature} and stores
it, with a timestamp, in {cmd:_dta[src_signature]} and
{cmd:_dta[src_signed]}. Sign after tagging, and the tags carry a
fingerprint of the data they describe.{p_end}

{phang}
{cmd:srctag verify} recomputes the signature and compares. If the data
have changed since signing, it stops with error 459: the lineage tags may
describe data that no longer exists. Put it at the top of an analysis
do-file and stale provenance is caught instead of trusted. With no stored
signature it stops with error 198 and says to run {cmd:srctag sign}
first.{p_end}


{marker ecosystem}{...}
{title:The ecosystem: how these packages work together}

{pstd}
{cmd:srctag} needs nothing beyond Stata 16: no other package is
required, and {cmd:sign}/{cmd:verify} use Stata's own
{helpb datasignature}. {bf:srcfind} ships in this package and is the
reader for everything {cmd:srctag} writes; one install provides both
commands (see {helpb srcfind} for the search, audit, and export side of
the workflow). Three companion packages, each optional, make the tags do
more work.{p_end}

{pstd}
{bf:projectbuilder} (SSC: {cmd:ssc install projectbuilder}) scaffolds a
project whose generated {cmd:300_labels.do} (the labeling stage of its
numbered pipeline) is where the tagging belongs: the raw files are
identified, the analytic file exists, and the do-file already carries a
commented {cmd:srctag} block inviting the stamps. Tag there and every
later stage inherits the lineage. {cmd:projectbuilder check} reports
whether srctag/srcfind are installed, beside every other companion, with
a clickable install command:{p_end}

{cmd}{...}
        . projectbuilder CountyBudgets, data("budget_drop")
        . do "CountyBudgets/_code/000_control.do"
        . use "$cleaned/CountyBudgets_analytic.dta", clear
        . srctag _all, source(county budget drop) vintage(FY2026)
        . save, replace
{txt}{...}

{pstd}
{bf:combineall} (SSC: {cmd:ssc install combineall}) writes
{cmd:char[source]} itself: its harmonization layer stamps each variable
renamed through {cmd:map()} with {cmd:"oldname (file, year)"} while
stacking yearly file releases. Those mapped variables are
{helpb srcfind}-searchable with no srctag call at all, and {cmd:srctag}
can then add what the stamp lacks (an agency, a URL) without disturbing
it; add {cmd:replace} only if you mean to overwrite combineall's
stamp:{p_end}

{cmd}{...}
        . combineall using "panel", cmethod(append) directory("raw") map(renames.csv)
        . srcfind , all                        // combineall's stamps, ready to search
        . srctag wage, agency(TWC) url(https://twc.texas.gov)
{txt}{...}

{pstd}
{bf:datadictionary} (SSC: {cmd:ssc install datadictionary}) is where the
tags leave Stata. Its codebook workbook harvests {cmd:char[source]} into
a dedicated {cmd:srctag} column (labeled "char [source] (written by
srctag/combineall)") with every other characteristic, the structured
{cmd:src_*} fields included, collected beside it, so the finished
codebook answers the provenance question for someone who does not have
Stata:{p_end}

{cmd}{...}
        . srctag q_wage q_hours, source(TWC wage file) vintage(2026q2)
        . srctag sign
        . datadictionary, excel("codebook.xlsx") replace
{txt}{...}

{pstd}
{cmd:datadictionary}'s {cmd:dofile()} option closes the loop in the
other direction. It writes a relabel do-file that snapshots the current
metadata (labels, formats, notes, and {it:all variable characteristics,
lineage tags included}), so when the data go out as a bare CSV to a
collaborator in R, Python, or Excel and come back edited, one {cmd:do}
restores every tag exactly as stamped:{p_end}

{cmd}{...}
        . datadictionary, dofile("relabel.do")
        . export delimited using "share.csv", nolabel replace
        . * ... collaborator edits share.csv and returns it ...
        . import delimited using "share.csv", varnames(1) case(preserve) clear
        . do relabel.do                        // labels AND srctags restored
        . srctag sign                          // re-fingerprint the returned data
{txt}{...}

{pstd}
The last line is {cmd:sign}, not {cmd:verify}: the signature lives in
dataset-level characteristics, which a CSV cannot carry, so the returned
file has no signature to check. Look the restored data over, then sign
it fresh.{p_end}

{marker review}{...}
{pstd}
{bf:Human review of the metadata itself.} A reviewer who spots a wrong
vintage or a misnamed agency needs a way to correct the {it:tags}, not
the data. {helpb srcfind}'s {opt saving()} exports every tag as an
editable dataset, one row per variable per characteristic, and
{cmd:srctag apply} folds the corrected file back in, with the overwrite
guard and a receipt that accounts for every row. (Edits typed into the
{cmd:datadictionary} workbook cannot travel back this way: the workbook
is for reading. Route metadata corrections through this file
instead.){p_end}

{cmd}{...}
        . srcfind , all saving("lineage.dta", replace) noreport
        . * ... a reviewer corrects values in lineage.dta ...
        . srctag apply using "lineage.dta", replace
        . srctag sign
        . datadictionary, excel("codebook.xlsx") replace
{txt}{...}

{pstd}
The last two lines matter: re-sign so the signing timestamp postdates the
corrections, and rebuild the codebook so what people read matches what
the file now says. If a relabel do-file exists (from
{cmd:datadictionary, dofile()}), regenerate it too -- an old one would
restore the uncorrected tags on the next data round trip.{p_end}


{marker examples}{...}
{title:Examples}

{pstd}Every example runs as written, top to bottom.{p_end}

{pstd}Stamp two variables with a source and vintage, then read the stamps
back:{p_end}
{cmd}{...}
        . sysuse auto, clear
        . srctag price mpg, source(dealer file 2026) vintage(2026-07)
        . srcfind dealer
{txt}{...}

{pstd}Changing a tag needs {cmd:replace}; re-stamping the same value does
not:{p_end}
{cmd}{...}
        . srctag price, source(EPA extract)          // error 110
        . srctag price, source(EPA extract) replace  // changed
        . srctag price, source(EPA extract)          // no-op, no error
{txt}{...}

{pstd}Record a caveat with the tag, where the next analyst will find
it:{p_end}
{cmd}{...}
        . srctag weight, source(dealer file 2026)                    ///
              notes(self-reported; overstated for pre-1975 models)
{txt}{...}

{pstd}Structured fields for a client-facing project, plus a custom
field:{p_end}
{cmd}{...}
        . srctag headroom, agency(TWC) dataset(wage ledger)          ///
              url(https://example.gov/twc) vintage(2025q3) category(labor)
        . srctag headroom, key(src_confidence) value(high)
        . srctag show headroom
{txt}{...}

{pstd}Each structured field is separately searchable, so the agency and
the dataset answer different questions later:{p_end}
{cmd}{...}
        . srcfind TWC, char(src_agency)       // everything from this agency
        . srcfind ledger, char(src_dataset)   // everything from this table
{txt}{...}

{pstd}The dataset-level manifest lists every source in the file:{p_end}
{cmd}{...}
        . char list _dta[sources]
{txt}{...}

{pstd}Fingerprint the data the tags describe, and catch staleness
later:{p_end}
{cmd}{...}
        . srctag sign
        . srctag verify                    // ok: data unchanged
        . replace price = price + 1 in 1
        . srctag verify                    // error 459: data changed
{txt}{...}


{marker results}{...}
{title:Stored results}

{pstd}{cmd:srctag} is {help return:rclass} and stores:{p_end}

{synoptset 16 tabbed}{...}
{p2col 5 16 20 2: Scalars}{p_end}
{synopt:{cmd:r(n)}}number of variables stamped{p_end}
{synopt:{cmd:r(match)}}({cmd:verify}) 1 when the signature matches{p_end}
{p2col 5 16 20 2: Macros}{p_end}
{synopt:{cmd:r(signature)}}({cmd:sign}) the stored data signature{p_end}
{p2colreset}{...}


{marker authors}{...}
{title:Authors}

{pstd}
Eric A. Booth{break}
{browse "mailto:eric.a.booth@gmail.com":eric.a.booth@gmail.com}{p_end}

{pstd}
Elizabeth Teas{break}
{browse "mailto:elizabeth@farharbor.com":elizabeth@farharbor.com}{p_end}

{pstd}
Companion package to {it:Applied Program Evaluation Using Stata}.{p_end}

{hline}
