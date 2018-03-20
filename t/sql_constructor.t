# vim:set ft=lua ts=4 sw=4 et ft=perl:

################################################################################
# DO NOT EDIT THIS FILE.                                                       #
# Use ./t/build_ngx_ut.sh to regenerate this wrapper file.                     #
################################################################################

use Test::Nginx::Socket "no_plan";

no_long_string();

# Env TEST_VERBOSE is set by command "prove"
#
# Only env var starting with TEST_NGINX_ will be evaluated in the "--- config"
# block.
$ENV{TEST_NGINX_ACID_UT_VERBOSE} = $ENV{TEST_VERBOSE} || 0;

run_tests();

__DATA__

=== TEST 1: sql_constructor
--- http_config
    lua_shared_dict        shared_dict_lock 1m;
    lua_shared_dict        test_shared      10m;
    lua_check_client_abort on;

    lua_package_path "./lib/?.lua;;";
    lua_package_cpath "./lib/?.so;;";
--- config
    location /t {
        content_by_lua_block {
            require("acid.unittest").ngx_test_modules(
                { "test_sql_constructor", },
                { debug = ($TEST_NGINX_ACID_UT_VERBOSE == 1), }
            )
        }
    }
--- request
GET /t
--- response_body_like
.*tests all passed.*
