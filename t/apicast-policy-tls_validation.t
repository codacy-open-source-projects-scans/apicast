use lib 't';
use Test::APIcast::Blackbox 'no_plan';

env_to_apicast(
    'APICAST_HTTPS_PORT' => "$Test::Nginx::Util::ServerPortForClient",
    'APICAST_HTTPS_CERTIFICATE' => "$Test::Nginx::Util::ServRoot/html/server.crt",
    'APICAST_HTTPS_CERTIFICATE_KEY' => "$Test::Nginx::Util::ServRoot/html/server.key",
    'APICAST_HTTPS_SESSION_REUSE' => 'on',
);

add_block_preprocessor(sub {
    my $block = shift;
    my $custom_config = $block->custom_config;
    my $sites_d = $block->sites_d || '';


    if (defined $custom_config) {

      $sites_d .= <<_EOC_;
        $custom_config
_EOC_

      $block->set_value('sites_d', $sites_d)
    }
});

$ENV{TEST_NGINX_HTML_DIR} ||= "$Test::Nginx::Util::ServRoot/html";

run_tests();

__DATA__

=== TEST 1: TLS Client Certificate is whitelisted and valid
--- configuration eval
use JSON qw(to_json);
use File::Slurp qw(read_file);

to_json({
  services => [{
    proxy => {
        hosts => ['test'],
        policy_chain => [
          { name => 'apicast.policy.tls_validation',
            configuration => {
              whitelist => [
                { pem_certificate => CORE::join('', read_file('t/fixtures/CA/client.crt')) }
              ]
            }
          },
          { name => 'apicast.policy.echo' },
        ]
    }
  }]
});
--- test env
proxy_ssl_verify on;
proxy_ssl_trusted_certificate $TEST_NGINX_SERVER_ROOT/html/ca.crt;
proxy_ssl_certificate $TEST_NGINX_SERVER_ROOT/html/client.crt;
proxy_ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/client.key;
proxy_pass https://$server_addr:$apicast_port/t;
proxy_set_header Host test;
log_by_lua_block { collectgarbage() }
--- response_body
GET /t HTTP/1.0
--- error_code: 200
--- no_error_log
[error]
--- user_files fixture=CA/files.pl eval



=== TEST 2: TLS Client Certificate CA is whitelisted
--- configuration eval
use JSON qw(to_json);
use File::Slurp qw(read_file);

to_json({
  services => [{
    proxy => {
        hosts => ['test'],
        policy_chain => [
          { name => 'apicast.policy.tls_validation',
            configuration => {
              whitelist => [
                { pem_certificate => CORE::join('', read_file('t/fixtures/CA/intermediate-ca.crt')) }
              ]
            }
          },
          { name => 'apicast.policy.echo' },
        ]
    }
  }]
});
--- test env
proxy_ssl_verify on;
proxy_ssl_trusted_certificate $TEST_NGINX_SERVER_ROOT/html/ca.crt;
proxy_ssl_certificate $TEST_NGINX_SERVER_ROOT/html/client.crt;
proxy_ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/client.key;
proxy_pass https://$server_addr:$apicast_port/t;
proxy_set_header Host test;
log_by_lua_block { collectgarbage() }
--- response_body
GET /t HTTP/1.0
--- error_code: 200
--- no_error_log
[error]
--- user_files fixture=CA/files.pl eval



=== TEST 3: TLS Client Certificate is not whitelisted
--- configuration eval
use JSON qw(to_json);
use File::Slurp qw(read_file);

to_json({
  services => [{
    proxy => {
        hosts => ['test'],
        policy_chain => [
          { name => 'apicast.policy.tls_validation',
            configuration => {
              whitelist => [ ]
            }
          },
          { name => 'apicast.policy.echo' },
        ]
    }
  }]
});
--- test env
proxy_ssl_verify on;
proxy_ssl_trusted_certificate $TEST_NGINX_SERVER_ROOT/html/ca.crt;
proxy_ssl_certificate $TEST_NGINX_SERVER_ROOT/html/client.crt;
proxy_ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/client.key;
proxy_pass https://$server_addr:$apicast_port/t;
proxy_set_header Host test;
log_by_lua_block { collectgarbage() }
--- response_body
TLS certificate validation failed
--- error_code: 400
--- no_error_log
[error]
--- user_files fixture=CA/files.pl eval



=== TEST 4: TLS Client Certificate is not provided
--- configuration eval
use JSON qw(to_json);
use File::Slurp qw(read_file);

to_json({
  services => [{
    proxy => {
        hosts => ['test'],
        policy_chain => [
          { name => 'apicast.policy.tls_validation',
            configuration => {
              whitelist => [ ]
            }
          },
          { name => 'apicast.policy.echo' },
        ]
    }
  }]
});
--- test env
proxy_ssl_verify on;
proxy_ssl_trusted_certificate $TEST_NGINX_SERVER_ROOT/html/ca.crt;
proxy_pass https://$server_addr:$apicast_port/t;
proxy_set_header Host test;
log_by_lua_block { collectgarbage() }
--- response_body
No required TLS certificate was sent
--- error_code: 400
--- no_error_log
[error]
[alert]
--- user_files fixture=CA/files.pl eval



=== TEST 5: TLS Client Certificate contains whole certificate chain
--- env eval
("APICAST_HTTPS_VERIFY_DEPTH" => 2)
--- configuration eval
use JSON qw(to_json);
use File::Slurp qw(read_file);

to_json({
  services => [{
    proxy => {
        hosts => ['test'],
        policy_chain => [
          { name => 'apicast.policy.tls_validation',
            configuration => {
              whitelist => [
                { pem_certificate => CORE::join('', read_file('t/fixtures/CA/intermediate-ca.crt')) }
              ]
            }
          },
          { name => 'apicast.policy.echo' },
        ]
    }
  }]
});
--- test env
proxy_ssl_verify on;
proxy_ssl_trusted_certificate $TEST_NGINX_SERVER_ROOT/html/ca.crt;
proxy_ssl_certificate $TEST_NGINX_SERVER_ROOT/html/client-bundle.crt;
proxy_ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/client.key;
proxy_pass https://$server_addr:$apicast_port/t;
proxy_set_header Host test;
log_by_lua_block { collectgarbage() }
--- response_body
GET /t HTTP/1.0
--- error_code: 200
--- no_error_log
[error]
--- user_files fixture=CA/files.pl eval



=== TEST 6: TLS Client Certificate request client certificate when "APICAST_HTTPS_VERIFY_CLIENT: off"
and the policy is in the chain
--- configuration eval
use JSON qw(to_json);
use File::Slurp qw(read_file);

to_json({
  services => [{
    proxy => {
        hosts => ['test'],
        policy_chain => [
          { name => 'apicast.policy.tls_validation',
            configuration => {
              whitelist => [
                { pem_certificate => CORE::join('', read_file('t/fixtures/CA/intermediate-ca.crt')) }
              ]
            }
          },
          { name => 'apicast.policy.echo' },
        ]
    }
  }]
});
--- test env
proxy_ssl_verify on;
proxy_ssl_trusted_certificate $TEST_NGINX_SERVER_ROOT/html/ca.crt;
proxy_ssl_certificate $TEST_NGINX_SERVER_ROOT/html/client.crt;
proxy_ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/client.key;
proxy_pass https://$server_addr:$apicast_port/t;
proxy_set_header Host test;
log_by_lua_block { collectgarbage() }
--- response_body
GET /t HTTP/1.0
--- error_code: 200
--- no_error_log
[error]
--- user_files fixture=CA/files.pl eval



=== TEST 7: TLS Client Certificate request client certificate with path routing enabled
--- env eval
('APICAST_PATH_ROUTING' => '1')
--- configuration eval
use JSON qw(to_json);
use File::Slurp qw(read_file);

to_json({
  services => [{
    id => 2,
    backend_version => 1,
    proxy => {
        hosts => ['test'],
        policy_chain => [
          { name => 'apicast.policy.tls_validation',
            configuration => {
              whitelist => [
                { pem_certificate => CORE::join('', read_file('t/fixtures/CA/intermediate-ca.crt')) }
              ]
            }
          },
          { name => 'apicast.policy.echo' },
        ]
      }
  }, {
    id => 3,
    backend_version => 1,
    proxy => {
        hosts => ['test'],
        policy_chain => [
          { name => 'apicast.policy.echo', configuration => { status => 404 }}
        ]
      }
  }]
});
--- test env
proxy_ssl_verify on;
proxy_ssl_trusted_certificate $TEST_NGINX_SERVER_ROOT/html/ca.crt;
proxy_ssl_certificate $TEST_NGINX_SERVER_ROOT/html/client.crt;
proxy_ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/client.key;
proxy_pass https://$server_addr:$apicast_port/t;
proxy_set_header Host test;
log_by_lua_block { collectgarbage() }
--- response_body
GET /t HTTP/1.0
--- error_code: 200
--- no_error_log
[error]
--- user_files fixture=CA/files.pl eval



=== TEST 8: TLS Client Certificate request client certificate with "APICAST_HTTPS_VERIFY_CLIENT: off"
and path routing enabled
When path routing is enabled, APIcast will not able to select the correct service and build the
corresponding policy chain during the TLS handshake. It will then fallback to the setting defined by
`ssl_client_verify` and with `APICAST_HTTPS_VERIFY_CLIENT` is set to `off`, no client certificate will
be requested.
--- env eval
(
  'APICAST_PATH_ROUTING' => '1',
  'APICAST_HTTPS_VERIFY_CLIENT' => 'off'
)
--- configuration eval
use JSON qw(to_json);
use File::Slurp qw(read_file);

to_json({
  services => [{
    id => 2,
    backend_version => 1,
    proxy => {
        hosts => ['test'],
        policy_chain => [
          { name => 'apicast.policy.tls_validation',
            configuration => {
              whitelist => [
                { pem_certificate => CORE::join('', read_file('t/fixtures/CA/intermediate-ca.crt')) }
              ]
            }
          },
          { name => 'apicast.policy.echo' },
        ]
      }
  }, {
    id => 3,
    backend_version => 1,
    proxy => {
        hosts => ['test'],
        policy_chain => [
          { name => 'apicast.policy.echo', configuration => { status => 404 }}
        ]
      }
  }]
});
--- test env
proxy_ssl_verify on;
proxy_ssl_trusted_certificate $TEST_NGINX_SERVER_ROOT/html/ca.crt;
proxy_ssl_certificate $TEST_NGINX_SERVER_ROOT/html/client.crt;
proxy_ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/client.key;
proxy_pass https://$server_addr:$apicast_port/t;
proxy_set_header Host test;
log_by_lua_block { collectgarbage() }
--- response_body
No required TLS certificate was sent
--- error_code: 400
--- no_error_log
[error]
--- user_files fixture=CA/files.pl eval



=== TEST 9: TLS Client Certificate is whitelisted but allow_partial_chain set to false
--- configuration eval
use JSON qw(to_json);
use File::Slurp qw(read_file);

to_json({
  services => [{
    proxy => {
        hosts => ['test'],
        policy_chain => [
          { name => 'apicast.policy.tls_validation',
            configuration => {
              whitelist => [
                { pem_certificate => CORE::join('', read_file('t/fixtures/CA/client.crt')) }
              ],
              allow_partial_chain => JSON::false
            }
          },
          { name => 'apicast.policy.echo' },
        ]
    }
  }]
});
--- test env
proxy_ssl_verify on;
proxy_ssl_trusted_certificate $TEST_NGINX_SERVER_ROOT/html/ca.crt;
proxy_ssl_certificate $TEST_NGINX_SERVER_ROOT/html/client.crt;
proxy_ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/client.key;
proxy_pass https://$server_addr:$apicast_port/t;
proxy_set_header Host test;
log_by_lua_block { collectgarbage() }
--- error_code: 400
--- error_log
unable to get local issuer certificate
--- user_files fixture=CA/files.pl eval



=== TEST 10: TLS Client Certificate with Certificate Revoke List (CRL)
--- configuration eval
use JSON qw(to_json);
use File::Slurp qw(read_file);

to_json({
  services => [{
    proxy => {
        hosts => ['test'],
        policy_chain => [
          { name => 'apicast.policy.tls_validation',
            configuration => {
              whitelist => [
                { pem_certificate => CORE::join('', read_file('t/fixtures/CA/intermediate-ca.crt')) }
              ],
              revoke_list => [
                { pem_certificate => CORE::join('', read_file('t/fixtures/CA/crl.pem')) }
              ],
              revocation_check_type => 'crl'
            }
          },
          { name => 'apicast.policy.echo' },
        ]
    }
  }]
});
--- test env
proxy_ssl_verify on;
proxy_ssl_trusted_certificate $TEST_NGINX_SERVER_ROOT/html/ca.crt;
proxy_ssl_certificate $TEST_NGINX_SERVER_ROOT/html/client.crt;
proxy_ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/client.key;
proxy_pass https://$server_addr:$apicast_port/t;
proxy_set_header Host test;
log_by_lua_block { collectgarbage() }
--- error_code: 200
--- no_error_log
[error]
--- user_files fixture=CA/files.pl eval



=== TEST 11: TLS Client Certificate with Certificate Revoke List (CRL) and
revoked certificate
--- configuration eval
use JSON qw(to_json);
use File::Slurp qw(read_file);

to_json({
  services => [{
    proxy => {
        hosts => ['test'],
        policy_chain => [
          { name => 'apicast.policy.tls_validation',
            configuration => {
              whitelist => [
                { pem_certificate => CORE::join('', read_file('t/fixtures/CA/intermediate-ca.crt')) }
              ],
              revoke_list => [
                { pem_certificate => CORE::join('', read_file('t/fixtures/CA/crl.pem')) }
              ],
              revocation_check_type => 'crl'
            }
          },
          { name => 'apicast.policy.echo' },
        ]
    }
  }]
});
--- test env
proxy_ssl_verify on;
proxy_ssl_trusted_certificate $TEST_NGINX_SERVER_ROOT/html/ca.crt;
proxy_ssl_certificate $TEST_NGINX_SERVER_ROOT/html/revoked_client.crt;
proxy_ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/revoked_client.key;
proxy_pass https://$server_addr:$apicast_port/t;
proxy_set_header Host test;
log_by_lua_block { collectgarbage() }
--- error_code: 400
--- error_log
TLS certificate validation failed, err: certificate revoked
--- user_files fixture=CA/files.pl eval



=== TEST 12: TLS Client Certificate with OCSP and cert without no responder URL
--- configuration eval
use JSON qw(to_json);
use File::Slurp qw(read_file);

to_json({
  services => [{
    proxy => {
        hosts => ['test'],
        policy_chain => [
          { name => 'apicast.policy.tls_validation',
            configuration => {
              whitelist => [
                { pem_certificate => CORE::join('', read_file('t/fixtures/CA/intermediate-ca.crt')) }
              ],
              revocation_check_type => 'ocsp'
            }
          },
          { name => 'apicast.policy.echo' },
        ]
    }
  }]
});
--- test env
proxy_ssl_verify on;
proxy_ssl_trusted_certificate $TEST_NGINX_SERVER_ROOT/html/ca.crt;
proxy_ssl_certificate $TEST_NGINX_SERVER_ROOT/html/client.crt;
proxy_ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/client.key;
proxy_pass https://$server_addr:$apicast_port/t;
proxy_set_header Host test;
log_by_lua_block { collectgarbage() }
--- error_code: 400
--- error_log
TLS certificate validation failed, err: could not extract OCSP responder URL, the client certificate may be missing the required extensions
--- user_files fixture=CA/files.pl eval



=== TEST 13: TLS Client Certificate with OCSP and cert with ocsp supported (no issuer)
--- env eval
(
  'APICAST_HTTPS_CERTIFICATE' => "$Test::Nginx::Util::ServRoot/html/server.pem",
  'APICAST_HTTPS_CERTIFICATE_KEY' => "$Test::Nginx::Util::ServRoot/html/server-key.pem",
  'APICAST_HTTPS_SESSION_REUSE' => 'on',
)
--- configuration eval
use JSON qw(to_json);
use File::Slurp qw(read_file);
to_json({
  services => [{
    proxy => {
        hosts => ['test.com'],
        policy_chain => [
          { name => 'apicast.policy.tls_validation',
            configuration => {
              whitelist => [
                { pem_certificate => CORE::join('', read_file('t/fixtures/ocsp/intermediate_ca.pem')) }
              ],
              revocation_check_type => 'ocsp'
            }
          },
          { name => 'apicast.policy.echo' },
        ]
    }
  }]
});
--- test env
proxy_ssl_verify on;
proxy_ssl_trusted_certificate $TEST_NGINX_SERVER_ROOT/html/ca.pem;
proxy_ssl_certificate $TEST_NGINX_SERVER_ROOT/html/client.pem;
proxy_ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/client-key.pem;
proxy_pass https://$server_addr:$apicast_port/t;
proxy_set_header Host test.com;
log_by_lua_block { collectgarbage() }
--- error_code: 400
--- error_log
no issuer certificate in chain
--- user_files fixture=ocsp/files.pl eval



=== TEST 14: TLS Client Certificate with OCSP and cert with ocsp supported (issuer
cert not next to the leaf cert)
--- env eval
(
  'APICAST_HTTPS_CERTIFICATE' => "$Test::Nginx::Util::ServRoot/html/server.pem",
  'APICAST_HTTPS_CERTIFICATE_KEY' => "$Test::Nginx::Util::ServRoot/html/server-key.pem",
  'APICAST_HTTPS_SESSION_REUSE' => 'on',
  'APICAST_HTTPS_VERIFY_DEPTH' => 2
)
--- configuration eval
use JSON qw(to_json);
use File::Slurp qw(read_file);
to_json({
  services => [{
    proxy => {
        hosts => ['test'],
        policy_chain => [
          { name => 'apicast.policy.tls_validation',
            configuration => {
              whitelist => [
                { pem_certificate => CORE::join('', read_file('t/fixtures/ocsp/intermediate_ca.pem')) }
              ],
              revocation_check_type => 'ocsp'
            }
          },
          { name => 'apicast.policy.echo' },
        ]
    }
  }]
});
--- test env
proxy_ssl_verify on;
proxy_ssl_trusted_certificate $TEST_NGINX_SERVER_ROOT/html/ca.pem;
proxy_ssl_certificate $TEST_NGINX_SERVER_ROOT/html/wrong-issuer-order-chain.pem;
proxy_ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/client-key.pem;
proxy_pass https://$server_addr:$apicast_port/t;
proxy_set_header Host test;
log_by_lua_block { collectgarbage() }
--- error_code: 400
--- error_log
issuer certificate not next to leaf
--- user_files fixture=ocsp/files.pl eval



=== TEST 15: TLS Client Certificate with OCSP and unreachable OCSP responder URL
--- env eval
(
  'APICAST_HTTPS_CERTIFICATE' => "$Test::Nginx::Util::ServRoot/html/server.pem",
  'APICAST_HTTPS_CERTIFICATE_KEY' => "$Test::Nginx::Util::ServRoot/html/server-key.pem",
  'APICAST_HTTPS_SESSION_REUSE' => 'on',
  'APICAST_HTTPS_VERIFY_DEPTH' => 2
)
--- configuration eval
use JSON qw(to_json);
use File::Slurp qw(read_file);
to_json({
  services => [{
    proxy => {
        hosts => ['test'],
        policy_chain => [
          { name => 'apicast.policy.tls_validation',
            configuration => {
              whitelist => [
                { pem_certificate => CORE::join('', read_file('t/fixtures/ocsp/intermediate_ca.pem')) }
              ],
              revocation_check_type => 'ocsp'
            }
          },
          { name => 'apicast.policy.echo' },
        ]
    }
  }]
});
--- test env
proxy_ssl_verify on;
proxy_ssl_trusted_certificate $TEST_NGINX_SERVER_ROOT/html/ca.pem;
proxy_ssl_certificate $TEST_NGINX_SERVER_ROOT/html/chain.pem;
proxy_ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/client-key.pem;
proxy_pass https://$server_addr:$apicast_port/t;
proxy_set_header Host test;
log_by_lua_block { collectgarbage() }
--- error_code: 400
--- error_log
ocsp-responder.test could not be resolved (3: Host not found)
--- user_files fixture=ocsp/files.pl eval



=== TEST 15: TLS Client Certificate with OCSP and invalid OCSP respond
--- init eval
$Test::Nginx::Util::ENDPOINT_SSL_PORT = Test::APIcast::get_random_port();
--- env eval
(
  'APICAST_HTTPS_CERTIFICATE' => "$Test::Nginx::Util::ServRoot/html/server.pem",
  'APICAST_HTTPS_CERTIFICATE_KEY' => "$Test::Nginx::Util::ServRoot/html/server-key.pem",
  'APICAST_HTTPS_SESSION_REUSE' => 'on',
  'APICAST_HTTPS_VERIFY_DEPTH' => 2
)
--- configuration env eval
use JSON qw(to_json);
use File::Slurp qw(read_file);
to_json({
  services => [{
    proxy => {
        hosts => ['test'],
        policy_chain => [
          { name => 'apicast.policy.tls_validation',
            configuration => {
              whitelist => [
                { pem_certificate => CORE::join('', read_file('t/fixtures/ocsp/intermediate_ca.pem')) }
              ],
              revocation_check_type => 'ocsp',
              ocsp_responder_url => "https://127.0.0.1:$Test::Nginx::Util::ENDPOINT_SSL_PORT/ocsp",
            }
          },
          { name => 'apicast.policy.echo' },
        ]
    }
  }]
});
--- custom_config eval
<<EOF
server {
  listen $Test::Nginx::Util::ENDPOINT_SSL_PORT ssl;
  ssl_certificate $Test::Nginx::Util::ServRoot/html/server.pem;
  ssl_certificate_key $Test::Nginx::Util::ServRoot/html/server-key.pem;

  server_name custom default_server;

  location / {
    content_by_lua_block {
      ngx.say('invalid');
    }
  }
}
EOF
--- test env
proxy_ssl_verify on;
proxy_ssl_trusted_certificate $TEST_NGINX_SERVER_ROOT/html/ca.pem;
proxy_ssl_certificate $TEST_NGINX_SERVER_ROOT/html/chain.pem;
proxy_ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/client-key.pem;
proxy_pass https://$server_addr:$apicast_port/t;
proxy_set_header Host test;
log_by_lua_block { collectgarbage() }
--- error_code: 400
--- error_log
failed to validate OCSP response: d2i_OCSP_RESPONSE() failed
--- user_files fixture=ocsp/files.pl eval



=== TEST 16: TLS Client Certificate with OCSP and good OCSP respond
--- init eval
$Test::Nginx::Util::ENDPOINT_SSL_PORT = Test::APIcast::get_random_port();
--- env eval
(
  'APICAST_HTTPS_CERTIFICATE' => "$Test::Nginx::Util::ServRoot/html/server.pem",
  'APICAST_HTTPS_CERTIFICATE_KEY' => "$Test::Nginx::Util::ServRoot/html/server-key.pem",
  'APICAST_HTTPS_SESSION_REUSE' => 'on',
  'APICAST_HTTPS_VERIFY_DEPTH' => 2
)
--- backend
  location /ocsp {
    content_by_lua_block {
    }
  }
--- configuration env eval
use JSON qw(to_json);
use File::Slurp qw(read_file);
to_json({
  services => [{
    proxy => {
        hosts => ['test'],
        policy_chain => [
          { name => 'apicast.policy.tls_validation',
            configuration => {
              whitelist => [
                { pem_certificate => CORE::join('', read_file('t/fixtures/ocsp/intermediate_ca.pem')) }
              ],
              revocation_check_type => 'ocsp',
              ocsp_responder_url => "https://127.0.0.1:$Test::Nginx::Util::ENDPOINT_SSL_PORT/ocsp",
            }
          },
          { name => 'apicast.policy.echo' },
        ]
    }
  }]
});
--- custom_config eval
<<EOF
server {
  listen $Test::Nginx::Util::ENDPOINT_SSL_PORT ssl;
  ssl_certificate $Test::Nginx::Util::ServRoot/html/server.pem;
  ssl_certificate_key $Test::Nginx::Util::ServRoot/html/server-key.pem;

  server_name custom default_server;

  location / {
    content_by_lua_block {
      local pl_file = require "pl.file"
      local resp = pl_file.read("t/fixtures/ocsp/ocsp-response-good-response.der")
      ngx.print(resp)
    }
  }
}
EOF
--- test env
proxy_ssl_verify on;
proxy_ssl_trusted_certificate $TEST_NGINX_SERVER_ROOT/html/ca.pem;
proxy_ssl_certificate $TEST_NGINX_SERVER_ROOT/html/chain.pem;
proxy_ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/client-key.pem;
proxy_pass https://$server_addr:$apicast_port/t;
proxy_set_header Host test;
log_by_lua_block { collectgarbage() }
--- error_code: 200
--- no_error_log
[error]
--- user_files fixture=ocsp/files.pl eval



=== TEST 17: TLS Client Certificate with OCSP and revoked OCSP response
--- init eval
$Test::Nginx::Util::ENDPOINT_SSL_PORT = Test::APIcast::get_random_port();
--- env eval
(
  'APICAST_HTTPS_CERTIFICATE' => "$Test::Nginx::Util::ServRoot/html/server.pem",
  'APICAST_HTTPS_CERTIFICATE_KEY' => "$Test::Nginx::Util::ServRoot/html/server-key.pem",
  'APICAST_HTTPS_SESSION_REUSE' => 'on',
  'APICAST_HTTPS_VERIFY_DEPTH' => 2
)
--- backend
  location /ocsp {
    content_by_lua_block {
    }
  }
--- configuration env eval
use JSON qw(to_json);
use File::Slurp qw(read_file);
to_json({
  services => [{
    proxy => {
        hosts => ['test'],
        policy_chain => [
          { name => 'apicast.policy.tls_validation',
            configuration => {
              whitelist => [
                { pem_certificate => CORE::join('', read_file('t/fixtures/ocsp/intermediate_ca.pem')) }
              ],
              revocation_check_type => 'ocsp',
              ocsp_responder_url => "https://127.0.0.1:$Test::Nginx::Util::ENDPOINT_SSL_PORT/ocsp",
            }
          },
          { name => 'apicast.policy.echo' },
        ]
    }
  }]
});
--- custom_config eval
<<EOF
server {
  listen $Test::Nginx::Util::ENDPOINT_SSL_PORT ssl;
  ssl_certificate $Test::Nginx::Util::ServRoot/html/server.pem;
  ssl_certificate_key $Test::Nginx::Util::ServRoot/html/server-key.pem;

  server_name custom default_server;

  location / {
    content_by_lua_block {
      local pl_file = require "pl.file"
      local resp = pl_file.read("t/fixtures/ocsp/ocsp-response-revoked-response.der")
      ngx.print(resp)
    }
  }
}
EOF
--- test env
proxy_ssl_verify on;
proxy_ssl_trusted_certificate $TEST_NGINX_SERVER_ROOT/html/ca.pem;
proxy_ssl_certificate $TEST_NGINX_SERVER_ROOT/html/chain.pem;
proxy_ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/client-key.pem;
proxy_pass https://$server_addr:$apicast_port/t;
proxy_set_header Host test;
log_by_lua_block { collectgarbage() }
--- error_code: 400
--- error_log
failed to validate OCSP response: certificate status "revoked" in the OCSP response
--- user_files fixture=ocsp/files.pl eval
