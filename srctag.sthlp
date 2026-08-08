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
{viewerjumpto "Codebooks"      "srctag##codebooks"}{...}
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


{marker codebooks}{...}
{title:Codebooks: srctag with datadictionary}

{pstd}
The tags are most useful when they leave Stata. {helpb datadictionary}
(SSC: {cmd:ssc install datadictionary}) builds a codebook workbook from
the data in memory, and it harvests {cmd:char[source]} into a dedicated
{cmd:srctag} column, with every other characteristic (the structured
{cmd:src_*} fields included) collected beside it. The three-command
recipe:{p_end}

{cmd}{...}
        . srctag q_wage q_hours, source(TWC wage file) vintage(2026q2)
        . srctag sign
        . datadictionary, excel("codebook.xlsx") replace
{txt}{...}

{pstd}
gives a codebook in which every variable's row already answers the
provenance question, readable by someone who does not have Stata. For a
machine-readable inventory instead, see {helpb srcfind}'s {opt saving()}
option, which exports the tags as a dataset.{p_end}


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

{pstd}Structured fields for a client-facing project, plus a custom
field:{p_end}
{cmd}{...}
        . srctag headroom, agency(TWC) dataset(wage ledger)          ///
              url(https://example.gov/twc) vintage(2025q3) category(labor)
        . srctag headroom, key(src_confidence) value(high)
        . srctag show headroom
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
