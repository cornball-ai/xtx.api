if (requireNamespace("tinytest", quietly = TRUE)) {
  # Keep every transitive tools::R_user_dir() write (ours, hfhub's,
  # diffuseR's) inside the check's temp area instead of the user's home.
  Sys.setenv(R_USER_CACHE_DIR  = tempfile("xtx_api_cache_"),
             R_USER_DATA_DIR   = tempfile("xtx_api_data_"),
             R_USER_CONFIG_DIR = tempfile("xtx_api_config_"))
  tinytest::test_package("xtx.api")
}
