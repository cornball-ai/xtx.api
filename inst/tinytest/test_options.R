# Test option setters

# Save original options
old_base <- getOption("xtxapi.api_base")
old_key <- getOption("xtxapi.api_key")
old_tti <- getOption("xtxapi.tti_base")
old_stv <- getOption("xtxapi.stv_base")
old_itv <- getOption("xtxapi.itv_base")
on.exit({
  options(xtxapi.api_base = old_base)
  options(xtxapi.api_key = old_key)
  options(xtxapi.tti_base = old_tti)
  options(xtxapi.stv_base = old_stv)
  options(xtxapi.itv_base = old_itv)
}, add = TRUE)

# Test xtx_set_api_base
xtx_set_api_base("http://localhost:8000")
expect_equal(getOption("xtxapi.api_base"), "http://localhost:8000")

# Test xtx_set_api_key
xtx_set_api_key("test-key-123")
expect_equal(getOption("xtxapi.api_key"), "test-key-123")

# Test tti_base
tti_base("http://localhost:8001")
expect_equal(getOption("xtxapi.tti_base"), "http://localhost:8001")

# Test stv_base
stv_base("http://localhost:10364")
expect_equal(getOption("xtxapi.stv_base"), "http://localhost:10364")

# Test itv_base
itv_base("http://localhost:8002")
expect_equal(getOption("xtxapi.itv_base"), "http://localhost:8002")
