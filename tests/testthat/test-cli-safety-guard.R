# Static guard: text metasalmon did not author must never become a cli template.
#
# cli glue-interpolates every element of a condition message vector, so passing
# through a computed value lets braces in that text be evaluated (or, if
# unbalanced, replace the message with a parse error). The rule enforced here
# is that a cli condition message must be built from literals and the escaping
# helpers in R/cli-safety.R.
#
# This walks the installed namespace rather than grepping R/: under
# `R CMD check` tests run against the installed package, where R/ holds
# metasalmon.rdb and no source files, so a grep-based test would skip exactly
# where enforcement matters. The cost is that failures name the function, not a
# line number; use `scripts/` tooling if you need the exact site.
#
# LIMITATIONS, stated plainly: it resolves locals assigned in the same body but
# not values returned by other helpers, it cannot see through a function
# parameter (hence the forwarding-wrapper allowlist), and it reports function
# names rather than line numbers. It is a drift guard, not a proof.

# The `.ms_*_abort` helpers forward their first argument straight to
# `cli_abort()`, so it is a cli template and belongs here rather than on the
# allowlist. Allowlisting the wrapper instead meant its callers were never
# examined, which hid a live injection: a decomposition column named
# `{Sys.getenv("...")}` reached cli through
# `.ms_sdp_decomposition_normalize_rows()` and its value was evaluated into the
# message.
cli_message_fns <- c(
  "cli_abort", "cli_warn", "cli_inform", "cli_text", "cli_bullets",
  "cli_alert", "cli_alert_info", "cli_alert_success", "cli_alert_warning",
  "cli_alert_danger",
  ".ms_sssom_abort", ".ms_sdp_decomposition_abort",
  ".ms_sdp_extension_abort", ".ms_sdp_reproducibility_abort"
)

# Functions whose message argument is legitimately computed. Two shapes only:
#   (a) wrapper aborts that forward a caller-supplied template, and
#   (b) locally assembled templates whose every element is a string literal.
# Adding an entry here is a claim that you checked it. Do not add one to
# silence a failure you have not read.
cli_template_allowlist <- c(
  # The `.ms_*_abort` wrappers are NOT listed here: they are treated as cli
  # message functions above so that their callers are checked. Only the bodies
  # of the wrappers themselves are exempt, because they legitimately forward a
  # caller-supplied template.
  ".ms_sssom_abort_body_exempt",
  # `null_message` defaults to a literal and every call site passes one
  # (R/chat-decomposition.R, R/semantic-bundle-review.R); the snippet it appends
  # is value-interpolated inside a literal template.
  ".ms_llm_review_response_data",
  # (b) locally assembled all-literal templates
  ".ms_create_sdp_seed_note",
  ".ms_create_sdp_update_note"
)

# The escaping helpers, plus vetted builders whose every element is a literal
# (they carry their own allowlist entry for the cli calls inside them).
safe_call_fns <- c(
  ".ms_cli_escape", ".ms_cli_bullets",
  ".ms_create_sdp_seed_note", ".ms_create_sdp_update_note"
)

# Messages are commonly assembled into a local first, then passed. Collect every
# `name <- value` in a body so a symbol argument can be resolved to what it was
# built from; without this the guard would need whole functions allowlisted,
# which would also silence their future cli calls.
collect_assignments <- function(node, acc = new.env(parent = emptyenv())) {
  if (is.call(node)) {
    head <- node[[1]]
    if (is.name(head) && as.character(head) %in% c("<-", "=", "<<-") &&
        length(node) == 3L && is.name(node[[2]])) {
      nm <- as.character(node[[2]])
      acc[[nm]] <- c(acc[[nm]], list(node[[3]]))
    }
  }
  if (is.call(node) || is.pairlist(node)) {
    for (part in as.list(node)) {
      if (!missing(part) && (is.call(part) || is.pairlist(part))) {
        collect_assignments(part, acc)
      }
    }
  }
  acc
}

is_literal_message <- function(node, assignments = NULL, seen = character()) {
  # Any atomic constant is safe: a number or logical cannot carry a brace, and
  # a string constant is an authored template. NULL is a literal too -- it is
  # how a conditional bullet is omitted -- and `is.atomic(NULL)` is FALSE from
  # R 4.4, so it needs its own case.
  if (is.null(node)) {
    return(TRUE)
  }
  if (is.atomic(node)) {
    return(TRUE)
  }
  if (is.name(node)) {
    nm <- as.character(node)
    # A symbol already being resolved up the stack is the `x <- c(x, ...)`
    # accumulator shape. Every assignment to it is checked independently, so
    # the self-reference contributes nothing new — treating it as unsafe would
    # reject the most common message-building idiom in the package.
    if (nm %in% seen) {
      return(TRUE)
    }
    if (is.null(assignments) || is.null(assignments[[nm]])) {
      return(FALSE)
    }
    return(all(vapply(
      assignments[[nm]],
      function(rhs) is_literal_message(rhs, assignments, c(seen, nm)),
      logical(1)
    )))
  }
  if (!is.call(node)) {
    return(FALSE)
  }
  head <- node[[1]]
  head_name <- if (is.name(head)) {
    as.character(head)
  } else if (is.call(head) && length(head) == 3L &&
             identical(as.character(head[[1]]), "::")) {
    as.character(head[[3]])
  } else {
    ""
  }
  if (head_name %in% safe_call_fns) {
    return(TRUE)
  }
  # Calls that cannot produce a brace: counts, arithmetic, and comparisons.
  # Interpolating these into a format string is safe by construction, which is
  # what most `sprintf("%d issue%s", nrow(x), ...)` messages do.
  if (head_name %in% c(
    "nrow", "ncol", "NROW", "NCOL", "length", "sum", "seq_len", "seq_along",
    "which", "round", "signif", "abs",
    "+", "-", "*", "/", "==", "!=", "<", ">", "<=", ">=", "(", "!"
  )) {
    return(TRUE)
  }
  # `min()` and `max()` return their argument's type, so on character input they
  # pass the string straight through -- safe only if the argument is.
  # Composition is safe only if every part is safe. `if`/`ifelse` are included
  # so the common `x <- if (cond) c("a") else c("b")` shape resolves.
  if (head_name %in% c("c", "paste", "paste0", "sprintf", "setNames", "if", "ifelse", "{",
                       "min", "max")) {
    args <- as.list(node)[-1]
    # The condition of if/ifelse never reaches the message text.
    if (head_name %in% c("if", "ifelse") && length(args) >= 1L) {
      args <- args[-1]
    }
    if (length(args) == 0L) {
      return(TRUE)
    }
    return(all(vapply(
      args,
      function(a) is_literal_message(a, assignments, seen),
      logical(1)
    )))
  }
  FALSE
}

collect_unsafe <- function(node, fn_name, assignments = NULL, acc = list()) {
  if (is.call(node)) {
    head <- node[[1]]
    head_name <- if (is.name(head)) {
      as.character(head)
    } else if (is.call(head) && length(head) == 3L &&
               identical(as.character(head[[1]]), "::")) {
      as.character(head[[3]])
    } else {
      ""
    }

    if (head_name %in% cli_message_fns && length(node) >= 2L) {
      args <- as.list(node)[-1]
      named <- names(args)
      # `cli_abort(message = x)` and `cli_alert_info(text = x)` are both valid
      # spellings and cli still treats the value as the template, so checking
      # only positional arguments would let either past. The alert/text APIs name
      # their first argument `text`, the condition APIs name it `message`.
      message_arg <- if (!is.null(named) && any(named %in% c("message", "text"))) {
        args[named %in% c("message", "text")]
      } else if (is.null(named)) {
        args
      } else {
        args[!nzchar(named)]
      }
      if (length(message_arg) >= 1L &&
          !is_literal_message(message_arg[[1]], assignments)) {
        acc[[length(acc) + 1L]] <- list(
          fn = fn_name,
          call = paste(deparse(node), collapse = " ")
        )
      }
    }
  }

  if (is.call(node) || is.pairlist(node)) {
    for (part in as.list(node)) {
      if (!missing(part) && (is.call(part) || is.pairlist(part))) {
        acc <- collect_unsafe(part, fn_name, assignments, acc)
      }
    }
  }
  acc
}

test_that("cli condition messages are built from literals or the escaping helpers", {
  ns <- asNamespace("metasalmon")
  findings <- list()

  wrapper_bodies <- c(
    ".ms_sssom_abort", ".ms_sdp_decomposition_abort",
    ".ms_sdp_extension_abort", ".ms_sdp_reproducibility_abort"
  )
  for (nm in ls(ns, all.names = TRUE)) {
    if (nm %in% c(cli_template_allowlist, wrapper_bodies)) {
      next
    }
    obj <- tryCatch(get(nm, envir = ns), error = function(e) NULL)
    if (!is.function(obj)) {
      next
    }
    body_node <- body(obj)
    if (is.null(body_node)) {
      next
    }
    findings <- c(
      findings,
      collect_unsafe(body_node, nm, collect_assignments(body_node))
    )
  }

  if (length(findings) > 0) {
    detail <- vapply(
      findings,
      function(f) paste0(f$fn, ": ", substr(f$call, 1, 160)),
      character(1)
    )
    fail(paste0(
      "cli condition messages must not interpolate computed text.\n",
      "Wrap external text with .ms_cli_escape()/.ms_cli_bullets(), or add the\n",
      "function to cli_template_allowlist after checking every element is a literal.\n",
      paste(detail, collapse = "\n")
    ))
  }

  succeed()
})


test_that("the guard detects an unsafe cli message", {
  # Without this, a guard that silently stopped matching would look like a pass.
  unsafe <- function(external) {
    cli::cli_abort(c("Header", "x" = external))
  }
  safe <- function(external) {
    cli::cli_abort(c("Header", "x" = .ms_cli_escape(external)))
  }
  safe_local <- function(external) {
    lines <- c("Header", "x" = .ms_cli_escape(external))
    lines <- c(lines, "i" = "Try again.")
    cli::cli_abort(lines)
  }

  named_unsafe <- function(external) {
    cli::cli_abort(message = c("Header", "x" = external))
  }
  named_text_unsafe <- function(external) {
    cli::cli_alert_info(text = external)
  }
  named_text_safe <- function(external) {
    cli::cli_alert_info(text = .ms_cli_escape(external))
  }
  # min()/max() return their argument's type, so character input passes through.
  character_max_unsafe <- function(external) {
    cli::cli_abort(max(external))
  }
  numeric_max_safe <- function(x) {
    cli::cli_abort(sprintf("Saw %d rows.", max(nrow(x), 1L)))
  }

  expect_length(collect_unsafe(body(unsafe), "unsafe", collect_assignments(body(unsafe))), 1L)
  expect_length(
    collect_unsafe(body(named_unsafe), "named_unsafe", collect_assignments(body(named_unsafe))),
    1L
  )
  expect_length(
    collect_unsafe(body(named_text_unsafe), "n", collect_assignments(body(named_text_unsafe))),
    1L
  )
  expect_length(
    collect_unsafe(body(named_text_safe), "n", collect_assignments(body(named_text_safe))),
    0L
  )
  expect_length(
    collect_unsafe(body(character_max_unsafe), "n", collect_assignments(body(character_max_unsafe))),
    1L
  )
  expect_length(
    collect_unsafe(body(numeric_max_safe), "n", collect_assignments(body(numeric_max_safe))),
    0L
  )
  expect_length(collect_unsafe(body(safe), "safe", collect_assignments(body(safe))), 0L)
  expect_length(
    collect_unsafe(body(safe_local), "safe_local", collect_assignments(body(safe_local))),
    0L
  )
})
