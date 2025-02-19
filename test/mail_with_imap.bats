
load 'test_helper/common'

setup_file() {
    local PRIVATE_CONFIG
    PRIVATE_CONFIG=$(duplicate_config_for_container .)
    docker run -d --name mail_with_imap \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    -e ENABLE_SASLAUTHD=1 \
    -e POSTMASTER_ADDRESS=postmaster@localhost.localdomain \
    -e SASLAUTHD_MECH_OPTIONS=127.0.0.1 \
    -e SASLAUTHD_MECHANISMS=rimap \
    -e PERMIT_DOCKER=container \
    -h mail.my-domain.com -t "${NAME}"
    wait_for_smtp_port_in_container mail_with_imap
}

teardown_file() {
    docker rm -f mail_with_imap
}

#
# RIMAP
#

# dovecot
@test "checking dovecot: ldap rimap connection and authentication works" {
  run docker exec mail_with_imap /bin/sh -c "nc -w 1 0.0.0.0 143 < /tmp/docker-mailserver-test/auth/imap-auth.txt"
  assert_success
}

# saslauthd
@test "checking saslauthd: sasl rimap authentication works" {
  run docker exec mail_with_imap bash -c "testsaslauthd -u user1@localhost.localdomain -p mypassword"
  assert_success
}

@test "checking saslauthd: rimap smtp authentication" {
  run docker exec mail_with_imap /bin/sh -c "nc -w 5 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/smtp-auth-login.txt | grep 'Authentication successful'"
  assert_success
}

# master account
@test "checking dovecot: master account can login" {
  run docker exec mail_with_imap bash -c "testsaslauthd -u user1@localhost.localdomain*masterusername -p masterpassword"
  assert_success
}
