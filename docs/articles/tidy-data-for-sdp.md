# Tidy Data for Salmon Data Packages

## Overview

A Salmon Data Package describes your data one column and one row at a
time. `column_dictionary.csv` says what each column means; `tables.csv`
says what one row of each table represents. That description only works
if your table is actually shaped that way — one variable per column, one
observation per row.

Spreadsheets encourage a different shape. A year per column, a species
per column, a run of `count_1`, `count_2`, `count_3` — these are natural
to type and natural to read, and they are the shape that the SDP
metadata has nothing to say about. Since metasalmon 0.2.6,
[`validate_salmon_datapackage()`](https://salmon-data-mobilization.github.io/metasalmon/reference/validate_salmon_datapackage.md)
looks for that mismatch and tells you about it, instead of accepting the
package silently and implying it had checked.

This guide explains what the two tidy checks do, what their messages
mean, and how to reshape a table that fails them. Everything here runs
offline. Code chunks are not executed when this page is built, so you
can copy them and run them yourself; console output shown in plain
blocks is real output from those chunks.

### What “Tidy” Means Here

Three rules, from the tidy data conventions the tidyverse is built on:

1.  **Each variable forms a column.** If “survey year” is something you
    measured or recorded, it is a column called `survey_year` — not the
    *names* of several columns.
2.  **Each observation forms a row.** One row is one thing that
    happened: one stream in one year, one fish, one sample.
3.  **Each table holds one kind of observation.** A table of stream-year
    counts and a table of individual fish biosamples are two tables, not
    one.

Rule 3 matters more than it looks. It is what makes the rest of the SDP
work: `primary_key` can only identify a row if all the rows are the same
kind of thing, and — since sdp-0.3.0 — a table-level `method_iri` only
makes sense when the whole table was produced the same way. The
[migration
guide](https://salmon-data-mobilization.github.io/metasalmon/articles/migrating-to-sdp-0-3-0.md)
covers that second point.

### Check 1: A Declared Primary Key Must Identify a Row

`tables.csv` has a `primary_key` field: the column, or comma-separated
set of columns, whose values are unique within the table. Declaring it
is optional. If you do declare one, metasalmon now tests it, and a key
that does not hold is a **hard error**.

This is worth stating plainly, because it is the check most likely to
surprise you: before 0.2.6 the field was written and read by nothing
that tested it, so a package could claim a key and ship duplicate rows.

Declare it in `tables.csv`:

``` r

tables <- readr::read_csv("escapement-sdp/metadata/tables.csv", na = "")

tables$primary_key[tables$table_id == "escapement"] <- "stream_id,survey_year"

readr::write_csv(tables, "escapement-sdp/metadata/tables.csv", na = "")
```

Three things can go wrong, and each produces a different message.

#### The Key Repeats

``` r

validate_salmon_datapackage("escapement-sdp", require_iris = FALSE)
```

    Error:
    ! Salmon Data Package validation failed with 1 structural issue.
    ✖ Table 'escapement' declares primary key 'stream_id, survey_year' but 1 row
      repeats it.

Two rows share the same `stream_id` and `survey_year`. Either your key
needs another column — perhaps the same stream really was surveyed twice
in a year, and `survey_date` or `pass_number` is what separates the rows
— or you have duplicate records to remove. The error does not tell you
which, because only you know.

#### The Key Contains Blanks

    Error:
    ! Salmon Data Package validation failed with 1 structural issue.
    ✖ Table 'escapement' declares primary key 'stream_id, survey_year' but column
      stream_id contains missing values.

A missing value in a key column is as fatal as a duplicate: that row has
no identity at all. This is checked separately from duplication on
purpose, because a blank would otherwise slip through — two rows with a
blank `stream_id` are not literally equal, so they would not be reported
as repeats, while identifying nothing.

#### The Key Names a Column That Is Not There

    Error:
    ! Salmon Data Package validation failed with 1 structural issue.
    ✖ Table 'escapement' primary_key references columns not present in data:
      survey_year.

Usually a typo, or a column that was renamed in the data but not in the
metadata.

#### Choosing a Primary Key

Ask what one row *is*, then list the columns that answer it:

| One row is…                         | Primary key                          |
|-------------------------------------|--------------------------------------|
| One stream in one year              | `stream_id,survey_year`              |
| One stream on one survey date       | `stream_id,survey_date`              |
| One individual fish                 | `sample_id`                          |
| One stream-year-species combination | `stream_id,survey_year,species_code` |

If you cannot name a set of columns that is unique, that is useful
information: it usually means the table holds more than one kind of
observation, and rule 3 above applies. Leaving `primary_key` blank is
still allowed — the check only runs on a key you declare — but a key you
can state is a key your collaborators can join on.

### Check 2: Column Names That Look Like Data Values

The second check reads your **column names** and reports names that look
like data. It is a **warning, never an error**. The SDP will still
package untidy data; it just stops implying that it checked.

``` r

wide <- tibble::tibble(
  stream_id = c("BEAR", "COHO"),
  `2021`    = c(310L, 980L),
  `2022`    = c(288L, 1105L),
  `2023`    = c(412L, 1204L)
)

pkg_path <- create_sdp(
  wide,
  path = file.path(tempdir(), "wide-demo-sdp"),
  dataset_id = "wide-demo",
  table_id = "escapement",
  seed_semantics = FALSE,
  check_updates = FALSE,
  overwrite = TRUE
)

validate_salmon_datapackage(pkg_path, require_iris = FALSE)
```

The relevant part of the output (a freshly created package also warns
about unfilled placeholders and empty semantic fields — both normal, and
both discussed at the end of this guide):

    ✔ Salmon Data Package validation passed

    Warning message:
    Table "escapement" may not be tidy: 3 column names look like data values.
    ✖ 2021, 2022, 2023
    ℹ Tidy data puts each variable in a column and each observation in a row.
    ℹ Consider `tidyr::pivot_longer()` before packaging.

Note that validation **passed**. The warning sits beside a successful
result, which is exactly the intent: you are being told something worth
knowing, not being stopped. `seed_semantics = FALSE` above simply keeps
the example offline and focused on shape; it has nothing to do with the
tidy checks.

#### What Gets Flagged

The check is a heuristic, and a deliberately quiet one. It looks for two
shapes, and both need at least **three** matching columns so that an
ordinary `x2`/`x3` pair is not flagged:

- **Bare year-like names**: `1998`, `2023`, `X2023` — a four-digit
  number starting with `19` or `20`, optionally with a leading `X`
  (which is what R adds when it repairs a name that starts with a
  digit).
- **A shared stem with numeric tails**: `count_1998`, `count_1999`,
  `count_2000`, or `pass1`, `pass2`, `pass3`. The separator can be `_`,
  `.`, `-`, or nothing.

``` r

# Flagged: three columns share the stem "count" with numeric tails.
c("stream_id", "count_1998", "count_1999", "count_2000")

# Not flagged: only two share a stem.
c("stream_id", "length_1", "length_2")
```

Because it is a heuristic, it can be wrong in both directions. A genuine
variable called `pass1` in a three-pass electrofishing design will be
flagged; a wide table whose columns are named `coho`, `chinook`,
`sockeye` will not be, because nothing about those names looks numeric.
Read the warning as a prompt to look, not as a verdict.

#### Why This Shape Is a Problem

Consider what the metadata has to say about the wide table above:

- `column_dictionary.csv` gets a row for `2021`, a row for `2022`, and a
  row for `2023`. Each needs a `column_description`, a `value_type`, and
  — if you want the package to be semantically useful — a `term_iri`.
  All three descriptions would say the same thing, and all three would
  link to the same term.
- `tables.csv` has to say what one row is. “One stream” is true but
  useless: the years are in the row too, spread sideways.
- Add 2024 next year and you change the *schema*, not just the data.
  Everything downstream that named those columns breaks.

The long form fixes all three at once. One dictionary row for
`survey_year`, one for `spawner_count`, a primary key of
`stream_id,survey_year`, and next year’s data is three new rows in a
file whose shape never changes.

### Reshaping Wide Data With `pivot_longer()`

[`tidyr::pivot_longer()`](https://tidyr.tidyverse.org/reference/pivot_longer.html)
turns columns into rows. You tell it which columns hold values, what to
call the column made from their *names*, and what to call the column
made from their *values*.

``` r

long <- tidyr::pivot_longer(
  wide,
  cols = c(`2021`, `2022`, `2023`),
  names_to = "survey_year",
  values_to = "spawner_count",
  names_transform = list(survey_year = as.integer)
)

long
```

    # A tibble: 6 × 3
      stream_id survey_year spawner_count
      <chr>           <int>         <int>
    1 BEAR             2021           310
    2 BEAR             2022           288
    3 BEAR             2023           412
    4 COHO             2021           980
    5 COHO             2022          1105
    6 COHO             2023          1204

Three arguments do the real work:

- `cols` selects the columns that hold values rather than variables. You
  can also write it as `cols = -stream_id` (“everything except the
  identifier”), which is easier to maintain when years keep being added.
- `names_to` names the new variable made from the old column names. Name
  it after what those names *are* — `survey_year`, not `name`.
- `names_transform` converts the new column to the right type. Column
  names are always text, so without this you get `"2021"` as a string
  rather than the integer `2021`, and `value_type` in your dictionary
  would have to say `string`.

Then package the long form and declare the key you now have:

``` r

pkg_path <- create_sdp(
  long,
  path = file.path(tempdir(), "escapement-sdp"),
  dataset_id = "escapement",
  table_id = "escapement",
  seed_semantics = FALSE,
  check_updates = FALSE,
  overwrite = TRUE
)

tables <- readr::read_csv(
  file.path(pkg_path, "metadata", "tables.csv"),
  show_col_types = FALSE, na = ""
)
tables$primary_key[tables$table_id == "escapement"] <- "stream_id,survey_year"
readr::write_csv(tables, file.path(pkg_path, "metadata", "tables.csv"), na = "")

validate_salmon_datapackage(pkg_path, require_iris = FALSE)
```

    ✔ Loaded Salmon Data Package from '.../escapement-sdp'
    ✔ Dictionary validation passed
    ✔ Salmon Data Package validation passed

No tidy warning, and the declared key holds. The placeholder and
missing-semantic-field warnings are still there — they are the ordinary
to-do list for a package created seconds ago, and they are what the rest
of the workflow is for.

#### When the Column Names Hold Two Things

Sometimes a wide column name packs more than one variable — `coho_2021`,
`chinook_2021`, `coho_2022`. Split them in one step with `names_sep`:

``` r

wide_two <- tibble::tibble(
  stream_id    = c("BEAR", "COHO"),
  coho_2021    = c(310L, 980L),
  coho_2022    = c(288L, 1105L),
  chinook_2021 = c(44L, 190L),
  chinook_2022 = c(51L, 205L)
)

tidyr::pivot_longer(
  wide_two,
  cols = -stream_id,
  names_to = c("species", "survey_year"),
  names_sep = "_",
  values_to = "spawner_count",
  names_transform = list(survey_year = as.integer)
)
```

    # A tibble: 8 × 4
      stream_id species survey_year spawner_count
      <chr>     <chr>         <int>         <int>
    1 BEAR      coho           2021           310
    2 BEAR      coho           2022           288
    3 BEAR      chinook        2021            44
    4 BEAR      chinook        2022            51
    5 COHO      coho           2021           980
    6 COHO      coho           2022          1105
    7 COHO      chinook        2021           190
    8 COHO      chinook        2022           205

Now `species` is a real column, which means it can also become a **code
column** with its values defined in `metadata/codes.csv` and linked to
taxon terms. That is a substantial gain in what your package can say —
and it was unavailable while the species names were column headings.

### One Warning You Should Expect on a Fresh Package

Separately from the tidy checks, a package you just created will warn
about placeholders:

    Warning message:
    8 metadata fields still hold a placeholder.
    ✖ column_dictionary.csv$column_description, dataset.csv$contact_email,
      dataset.csv$contact_name, dataset.csv$creator, dataset.csv$description,
      dataset.csv$license
    ℹ Replace them before publication; `require_iris = TRUE` reports these as
      errors.

This is normal on a package created seconds ago, and it is a to-do list
rather than a defect:
[`create_sdp()`](https://salmon-data-mobilization.github.io/metasalmon/reference/create_sdp.md)
deliberately writes `MISSING METADATA:` and `MISSING DESCRIPTION:`
markers so the package is immediately reviewable in Excel. Fill them in
before publishing.

### What Is Not Checked

Being explicit about the limits, so you do not read a clean validation
as more than it is:

- An **undeclared** primary key is accepted. Nothing forces you to
  declare one, and nothing infers one for you.
- Long-format data with a genuine duplicate is only caught if you
  declared the key that the duplicate violates.
- Wide tables whose column names are words rather than numbers — `coho`,
  `chinook`, `sockeye` — are not flagged by the heuristic.
- Rule 3 (one kind of observation per table) is not checked at all. It
  is a judgement, and it is yours.

### Related Reading

- [5-Minute
  Quickstart](https://salmon-data-mobilization.github.io/metasalmon/articles/metasalmon.md)
  — creating a package from a ready-to-package table.
- [Publishing Data
  Packages](https://salmon-data-mobilization.github.io/metasalmon/articles/data-dictionary-publication.md)
  — the manual assembly path, where you write `tables.csv` and set
  `primary_key` by hand.
- [Migrating to SDP
  0.3.0](https://salmon-data-mobilization.github.io/metasalmon/articles/migrating-to-sdp-0-3-0.md)
  — why a coherent observational unit is a precondition for table-level
  methods.
- [Glossary of
  Terms](https://salmon-data-mobilization.github.io/metasalmon/articles/glossary.md)
  — column roles, code lists, and the rest of the vocabulary used above.
