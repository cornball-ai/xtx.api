# Test ITV (Image-to-Video) functions

# --- itv_base() input validation ---

old_itv <- getOption("xtx.itv_base")
on.exit(options(xtx.itv_base = old_itv), add = TRUE)

expect_error(itv_base(NULL), pattern = "non-empty character")
expect_error(itv_base(""), pattern = "non-empty character")
expect_error(itv_base(123), pattern = "non-empty character")
expect_error(itv_base(c("a", "b")), pattern = "non-empty character")

itv_base("http://localhost:8000")
expect_equal(getOption("xtx.itv_base"), "http://localhost:8000")

# --- .itv_get_base() errors when unset ---

options(xtx.itv_base = NULL)
expect_error(xtx.api:::.itv_get_base(), pattern = "not set")

# --- itv() argument validation ---

# backend must be valid
expect_error(
  itv(image = "x.jpg", backend = "invalid"),
  pattern = "arg"
)

# wan2gp_api: needs existing image file
expect_error(
  itv(image = "nonexistent_xyz.jpg", backend = "wan2gp_api"),
  pattern = "not found"
)
