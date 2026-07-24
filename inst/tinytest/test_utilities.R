# Test utility functions

# Test backends returns expected backends
backends <- backends()
expect_true(is.list(backends))
expect_true("openai" %in% names(backends))
expect_true("diffuser" %in% names(backends))

# Test ip_adapter_types function exists (requires live server to call)
expect_true(is.function(ip_adapter_types))

# Test benchmark function exists
expect_true(is.function(benchmark))

# Test supported_models returns data frame
models <- supported_models()
expect_true(is.data.frame(models))
expect_true("model" %in% names(models))
expect_true("backend" %in% names(models))
