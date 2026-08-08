{smcl}
{* *! version 2.0.0 08aug2026 Eric A. Booth and Elizabeth Teas}{...}
{vieweralsosee "srctag" "help srctag"}{...}
{vieweralsosee "[P] char" "help char"}{...}
{vieweralsosee "[D] lookfor" "help lookfor"}{...}
{viewerjumpto "Syntax"         "srcfind##syntax"}{...}
{viewerjumpto "Description"    "srcfind##description"}{...}
{viewerjumpto "Options"        "srcfind##options"}{...}
{viewerjumpto "Warehouse scan" "srcfind##warehouse"}{...}
{viewerjumpto "Audits"         "srcfind##audits"}{...}
{viewerjumpto "Subcommands"    "srcfind##subcommands"}{...}
{viewerjumpto "Examples"       "srcfind##examples"}{...}
{viewerjumpto "Stored results" "srcfind##results"}{...}
{viewerjumpto "Authors"        "srcfind##authors"}{...}
{hline}
{pstd}help for {hi:srcfind}{p_end}
{hline}

{title:Title}

{p 4 8 2}
{bf:srcfind} {hline 2} find variables by the source lineage that
{helpb srctag} stamped into them: in memory, or across a whole folder of
{cmd:.dta} files.{p_end}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:srcfind} [{it:pattern}] [{cmd:,} {opt so:urce(text)} {opt ch:ar(name)}
{cmd:all} {opt unt:agged} {cmd:not} {opt ex:act} {opt wild:card}
{opt case:sensitive} {opt dir(folder)} {opt loc:al(macname)}
{opt into(macname)} {opt sav:ing(filename[, replace])} {opt prof:ile}
{opt norep:ort}]

{p 8 16 2}
{cmd:srcfind} {cmd:tags} [{cmd:,} {cmd:all} {opt nol:inks}]

{p 8 16 2}
{cmd:srcfind} {cmd:values} {it:charname} [{cmd:,} {opt nol:inks}]


{marker description}{...}
{title:Description}

{pstd}
{cmd:srcfind} matches {it:pattern} against the lineage characteristics
{helpb srctag} writes: the {cmd:source} slot plus every structured
{cmd:src_*} field. The default match is case-insensitive and matches any
part of the tag, so {cmd:srcfind dealer} finds a variable tagged
{cmd:dealer file 2026}. Each match prints beside its tag value and, in
parentheses, its vintage:{p_end}

{cmd}{...}
        . srcfind TWC
        q_wage          TWC wage file (2026q2)
        q_hours         TWC wage file (2026q2)
{txt}{...}

{pstd}
The matches land in {cmd:r(varlist)} and, with {opt local()}, in a macro
of your choosing, so a search feeds the next command:
{cmd:srcfind TWC, local(v)} then {cmd:summarize `v'}.{p_end}

{pstd}
Where Stata's {helpb lookfor} searches names and variable labels, and
{helpb findname} (Stata Journal) selects on generic characteristics,
{cmd:srcfind} knows {cmd:srctag}'s provenance schema: it searches both
schemas at once, prints vintages, scans warehouses on disk, and audits for
variables no one has tagged yet.{p_end}


{marker options}{...}
{title:Options}

{phang}
{opt source(text)} supplies the pattern as an option instead of an
argument; the two forms are equivalent.{p_end}

{phang}
{opt char(name)} restricts the search to one characteristic:
{cmd:srcfind BLS, char(src_agency)} matches only agency tags, not a BLS
that appears in some URL.{p_end}

{phang}
{cmd:all} lists every variable that carries any lineage tag, with no
pattern needed.{p_end}

{phang}
{opt untagged} lists the variables with {it:no} lineage tag at all; see
{help srcfind##audits:Audits} below.{p_end}

{phang}
{cmd:not} inverts the match: the variables that do {it:not} match the
pattern, tagged or not. A tagged non-match prints with its actual tag, an
untagged one prints {cmd:(no source tag)}.{p_end}

{phang}
{opt exact} requires the whole tag to equal the pattern; {opt wildcard}
matches with {cmd:*} and {cmd:?} (see {helpb strmatch()}). The default
matches any part of the tag. {opt casesensitive} turns off case
folding in any mode.{p_end}

{phang}
{opt dir(folder)} scans every {cmd:.dta} file in {it:folder} instead of
the data in memory; see
{help srcfind##warehouse:Warehouse scan} below.{p_end}

{phang}
{opt local(macname)} leaves the matching varlist in a local macro in the
calling scope, following the convention of {helpb findname}.
{opt into(macname)} is a synonym kept for older scripts.{p_end}

{phang}
{opt saving(filename[, replace])} exports the results as a dataset: one
row per matched variable per lineage characteristic, with columns
{cmd:file}, {cmd:varname}, {cmd:charname}, and {cmd:value}. An untagged
variable selected by {opt untagged} or {cmd:not} gets one row with empty
{cmd:charname}. This is the machine-readable inventory; for a
human-readable codebook see {helpb srctag}'s
{help srctag##codebooks:datadictionary recipe}.{p_end}

{phang}
{opt profile} runs {cmd:srctag show} on each match (in-memory searches
only).{p_end}

{phang}
{opt noreport} suppresses the listing; the results are still
stored.{p_end}


{marker warehouse}{...}
{title:Warehouse scan}

{pstd}
{cmd:srcfind {it:pattern}, dir({it:folder})} answers the provenance
question across a folder of {cmd:.dta} files: which files hold variables
from this source? Each file is opened in a scratch {help frames:frame},
first observation only, so the scan reads headers and characteristics
without loading the data and without disturbing what is in memory.
Matches print grouped under their file name:{p_end}

{cmd}{...}
        . srcfind TWC, dir("warehouse")
        tagged.dta:
          q_wage          TWC wage file (2026q2)
          q_hours         TWC wage file (2026q2)
{txt}{...}

{pstd}
A file that cannot be read is reported and skipped rather than stopping
the scan. {cmd:r(nfiles)} counts the files scanned and {cmd:r(files)}
lists the ones with at least one match.{p_end}


{marker audits}{...}
{title:Audits: enforcing a tagging discipline}

{pstd}
Tagging pays off only if it is complete, and completeness is checkable.
{cmd:srcfind, untagged} lists the variables that carry no lineage tag;
an empty answer means the file is fully documented. Two lines make it a
contract at the top of a do-file:{p_end}

{cmd}{...}
        . srcfind , untagged noreport
        . assert r(n) == 0
{txt}{...}

{pstd}
{helpb srctag}'s {cmd:sign}/{cmd:verify} pair covers the other failure
mode, tags that describe data that has since changed.{p_end}


{marker subcommands}{...}
{title:Subcommands}

{phang}
{cmd:srcfind tags} lists the lineage characteristic {it:names} present in
memory, with the count of variables carrying each; every name is a
clickable {cmd:srcfind values} search. {cmd:all} widens the sweep to
every characteristic, not just the lineage schemas. {opt nolinks} prints
plain text.{p_end}

{phang}
{cmd:srcfind values} {it:charname} lists the distinct {it:values} that
characteristic takes, with counts; every value is a clickable
{cmd:srcfind} search. The two subcommands together answer "what tagging
vocabulary does this file already use?" before you add to it.{p_end}


{marker examples}{...}
{title:Examples}

{pstd}Set up some tagged data, then search it:{p_end}
{cmd}{...}
        . sysuse auto, clear
        . srctag price mpg, source(dealer file 2026) vintage(2026-07)
        . srctag headroom, agency(TWC) dataset(wage ledger)
        . srcfind dealer
        . srcfind ledger
{txt}{...}

{pstd}Feed a search into the next command:{p_end}
{cmd}{...}
        . srcfind dealer, local(v) noreport
        . summarize `v'
{txt}{...}

{pstd}Match modes:{p_end}
{cmd}{...}
        . srcfind "dealer file 2026", exact
        . srcfind "dealer*", wildcard
        . srcfind DEALER, casesensitive        // no matches
{txt}{...}

{pstd}Audit for untagged variables, and for everything except one
source:{p_end}
{cmd}{...}
        . srcfind , untagged
        . srcfind dealer, not
{txt}{...}

{pstd}Search one characteristic only:{p_end}
{cmd}{...}
        . srcfind TWC, char(src_agency)
{txt}{...}

{pstd}Browse the tagging vocabulary already in use:{p_end}
{cmd}{...}
        . srcfind tags
        . srcfind values source
{txt}{...}

{pstd}Export a machine-readable inventory of every tag:{p_end}
{cmd}{...}
        . srcfind , all saving("lineage.dta", replace) noreport
{txt}{...}

{pstd}Scan a warehouse folder without touching the data in memory:{p_end}
{cmd}{...}
        . srcfind TWC, dir("warehouse")
{txt}{...}


{marker results}{...}
{title:Stored results}

{pstd}{cmd:srcfind} is {help return:rclass} and stores:{p_end}

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(n)}}number of matching variables (total across files with {opt dir()}){p_end}
{synopt:{cmd:r(nfiles)}}({opt dir()}) number of files scanned{p_end}
{synopt:{cmd:r(N_tags)}}({cmd:tags}) number of distinct tag names{p_end}
{synopt:{cmd:r(N_values)}}({cmd:values}) number of distinct values{p_end}
{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(varlist)}}the matching variables (in-memory searches){p_end}
{synopt:{cmd:r(files)}}({opt dir()}) files with at least one match{p_end}
{synopt:{cmd:r(tags)}}({cmd:tags}) the distinct tag names{p_end}
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
