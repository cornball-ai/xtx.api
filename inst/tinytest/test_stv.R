# Test STV (Speech-to-Video) functions

# --- stv_base() input validation ---

# Save and restore options
old_stv <- getOption("xtx.stv_base")
old_wan2gp <- getOption("xtx.wan2gp_api_base")
on.exit({
  options(xtx.stv_base = old_stv)
  options(xtx.wan2gp_api_base = old_wan2gp)
}, add = TRUE)

# Must be non-empty character
expect_error(stv_base(NULL), pattern = "non-empty character")
expect_error(stv_base(""), pattern = "non-empty character")
expect_error(stv_base(123), pattern = "non-empty character")
expect_error(stv_base(c("a", "b")), pattern = "non-empty character")

# Valid URL sets option
stv_base("http://localhost:10364")
expect_equal(getOption("xtx.stv_base"), "http://localhost:10364")

# Returns previous value invisibly
old <- stv_base("http://new:10364")
expect_equal(old, "http://localhost:10364")

# --- wan2gp_api_base() input validation ---

expect_error(wan2gp_api_base(NULL), pattern = "non-empty character")
expect_error(wan2gp_api_base(""), pattern = "non-empty character")
expect_error(wan2gp_api_base(123), pattern = "non-empty character")

wan2gp_api_base("http://localhost:8000")
expect_equal(getOption("xtx.wan2gp_api_base"), "http://localhost:8000")

# --- .stv_get_base() errors when unset ---

options(xtx.stv_base = NULL)
expect_error(xtx.api:::.stv_get_base(), pattern = "not set")

# --- stv() argument validation ---

# backend must be valid
expect_error(
  stv(image = "x.jpg", audio = "x.wav", backend = "invalid"),
  pattern = "arg"
)

# sadtalker: needs image or face_id
options(xtx.stv_base = "http://localhost:10364")
expect_error(
  stv(image = NULL, audio = "x.wav", backend = "sadtalker"),
  pattern = "image.*face_id"
)

# wan2gp_api: needs image
expect_error(
  stv(image = NULL, audio = "x.wav", backend = "wan2gp_api"),
  pattern = "image.*required"
)

# wan2gp: needs image
expect_error(
  stv(image = NULL, audio = "x.wav", backend = "wan2gp"),
  pattern = "image.*required"
)

# --- stv_face_create() input validation ---

expect_error(
  stv_face_create("nonexistent_file_xyz.jpg"),
  pattern = "not found"
)
