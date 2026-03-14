# Test TTI (Text-to-Image) functions

# --- tti_base() input validation ---

old_tti <- getOption("xtx.tti_base")
on.exit(options(xtx.tti_base = old_tti), add = TRUE)

expect_error(tti_base(NULL), pattern = "non-empty character")
expect_error(tti_base(""), pattern = "non-empty character")
expect_error(tti_base(123), pattern = "non-empty character")
expect_error(tti_base(c("a", "b")), pattern = "non-empty character")

tti_base("http://localhost:8000")
expect_equal(getOption("xtx.tti_base"), "http://localhost:8000")

# --- tti() input validation ---

# prompt must be non-empty character
expect_error(tti(NULL), pattern = "non-empty character")
expect_error(tti(""), pattern = "non-empty character")
expect_error(tti(123), pattern = "non-empty character")
expect_error(tti(c("a", "b")), pattern = "non-empty character")

# backend must be valid
expect_error(tti("a cat", backend = "invalid"), pattern = "arg")

# --- xtx_supported_models() ---

models <- xtx_supported_models()
expect_true(is.data.frame(models))
expect_true("model" %in% names(models))
expect_true("backend" %in% names(models))
expect_true(nrow(models) > 0)

# --- xtx_backends() ---

backends <- xtx_backends()
expect_true(is.list(backends))
expect_true("openai" %in% names(backends))
