# Test option setters

# Save original options
old_base <- getOption("xtx.api_base")
old_key <- getOption("xtx.api_key")
old_tti <- getOption("xtx.tti_base")
old_stv <- getOption("xtx.stv_base")
old_itv <- getOption("xtx.itv_base")
on.exit({
  options(xtx.api_base = old_base)
  options(xtx.api_key = old_key)
  options(xtx.tti_base = old_tti)
  options(xtx.stv_base = old_stv)
  options(xtx.itv_base = old_itv)
}, add = TRUE)

# Test set_api_base
set_api_base("http://localhost:8000")
expect_equal(getOption("xtx.api_base"), "http://localhost:8000")

# Test set_api_key
set_api_key("test-key-123")
expect_equal(getOption("xtx.api_key"), "test-key-123")

# Test tti_base
tti_base("http://localhost:8001")
expect_equal(getOption("xtx.tti_base"), "http://localhost:8001")

# Test stv_base
stv_base("http://localhost:10364")
expect_equal(getOption("xtx.stv_base"), "http://localhost:10364")

# Test itv_base
itv_base("http://localhost:8002")
expect_equal(getOption("xtx.itv_base"), "http://localhost:8002")
