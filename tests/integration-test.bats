#!/usr/bin/env bats

CLICKHOUSE_CLIENT_IMAGE="yandex/clickhouse-client:21"
CLICKHOUSE_HOST="tcp://clickhouse:9000"
TEST_PREFIX="tests_"
TEST_NETWORK="${TEST_PREFIX}test"

docker_test_run() {
  docker run --rm --network="$TEST_NETWORK" "$@"
}

setup() {
  load 'test_helper/bats-support/load'
  load 'test_helper/bats-assert/load'

  docker_test_run jwilder/dockerize:latest  \
    -wait "$CLICKHOUSE_HOST" -timeout 10s

  docker cp freeradius/test-scripts "${TEST_PREFIX}freeradius_1:/"
}

show_tables() {
  docker_test_run "$CLICKHOUSE_CLIENT_IMAGE" --host clickhouse --query \
    "SHOW TABLES"
}

acct_send() {
  TYPE="$1"

  docker-compose exec -T freeradius /bin/sh -c "cd /test-scripts && ./acct-send $TYPE"
  docker_test_run "$CLICKHOUSE_CLIENT_IMAGE" --host clickhouse --format=TSKV --query \
    "SELECT * FROM radacct WHERE AcctSessionId='5ff1ad49/7c:5c:f8:a5:08:07/121/1';" 2>&1
}

acct_start() {
  acct_send start
}

acct_interim_update() {
  acct_send interim-update
}

acct_stop() {
  acct_send stop
}

acct_off_on() {
  docker-compose exec -T freeradius /bin/sh -c "cd /test-scripts && ./acct-send start 2"
  docker-compose exec -T freeradius /bin/sh -c "cd /test-scripts && ./acct-send interim-update 2"
  docker-compose exec -T freeradius /bin/sh -c "cd /test-scripts && ./acct-send interim-update 2"
  docker-compose exec -T freeradius /bin/sh -c "cd /test-scripts && ./acct-send accounting-off"
  docker-compose exec -T freeradius /bin/sh -c "cd /test-scripts && ./acct-send accounting-on"

  docker_test_run "$CLICKHOUSE_CLIENT_IMAGE" --host clickhouse --format=TSKV --query \
    "SELECT * FROM radacct WHERE AcctSessionId='5ff1ad49/7c:5c:f8:a5:08:07/121/2';" 2>&1
}

@test "All tables are created" {
  run show_tables

  [ "${status}" -eq 0 ]
  [ "${lines[0]}" = "radacct" ]
  [ "${lines[1]}" = "radacct_active" ]
  [ "${lines[2]}" = "radacct_live" ]
  [ "${lines[3]}" = "radacct_mv" ]
  [ "${lines[4]}" = "radacct_raw" ]
}

@test "Accounting 'start' recorded" {
  run acct_start

  [ "${status}" -eq 0 ]

  assert_output --partial 'AcctUniqueId=6f630ec6513478d6e1d7fff6ce94e0b6'
  assert_output --partial 'AcctSessionId=5ff1ad49/7c:5c:f8:a5:08:07/121/1'
  assert_output --partial 'UserName=user.1'
  assert_output --partial 'Realm='
  assert_output --partial 'NASIPAddress=::ffff:192.168.1.254'
  assert_output --partial 'NASPortId=3'
  assert_output --partial 'NASPortType=Wireless-802.11'
  assert_output --partial 'AcctLastStatusType=Start'
  assert_output --partial 'AcctStartTime=2021-01-03 14:41:42'
  assert_output --partial 'AcctStopTime=\N'
  assert_output --partial 'AcctUpdateTime=2021-01-03 14:41:42'
  assert_output --partial 'AcctSessionTime=' # ignore the value, just validate that AcctSessionTime exists
  assert_output --partial 'AcctTerminateCause=\N'
  assert_output --partial 'AcctAuthentic=RADIUS'
  assert_output --partial 'ConnectInfoStart=\N'
  assert_output --partial 'ConnectInfoStop=\N'
  assert_output --partial 'AcctInputOctets=0'
  assert_output --partial 'AcctOutputOctets=0'
  assert_output --partial 'CalledStationId=AP2:@Stronghold Passpoint'
  assert_output --partial 'CallingStationId=7c-5c-f8-a5-08-07'
  assert_output --partial 'ServiceType=\N'
  assert_output --partial 'FramedProtocol=\N'
  assert_output --partial 'FramedIPAddress=192.168.1.73'
  assert_output --partial 'FramedIPv6Address=\N'
  assert_output --partial 'FramedIPv6Prefix=\N'
  assert_output --partial 'FramedIPv6PrefixSize=\N'
  assert_output --partial 'FramedInterfaceId=\N'
  assert_output --partial 'DelegatedIPv6Prefix=\N'
  assert_output --partial 'DelegatedIPv6PrefixSize=\N'
}

@test "Accounting 'interim-update' recorded" {
  run acct_interim_update

  [ "${status}" -eq 0 ]

  assert_output --partial 'AcctSessionId=5ff1ad49/7c:5c:f8:a5:08:07/121/1'
  assert_output --partial 'AcctLastStatusType=Interim-Update'
  refute_output --partial 'AcctUpdateTime=2021-01-03 14:41:42' # The AcctUpdateTime should be changed
  assert_output --partial 'AcctTerminateCause=\N'
  assert_output --partial 'AcctInputOctets=1014658'
  assert_output --partial 'AcctOutputOctets=1073746'
}

@test "Accounting 'stop' recorded" {
  run acct_stop

  [ "${status}" -eq 0 ]

  assert_output --partial 'AcctSessionId=5ff1ad49/7c:5c:f8:a5:08:07/121/1'
  assert_output --partial 'AcctLastStatusType=Stop'
  refute_output --partial 'AcctUpdateTime=2021-01-03 14:41:42' # The AcctUpdateTime should be changed
  assert_output --partial 'AcctTerminateCause=User-Request'
  assert_output --partial 'AcctInputOctets=10146580'
  assert_output --partial 'AcctOutputOctets=10737460'
}

@test "Accounting 'off/on' recorded" {
  run acct_off_on

  [ "${status}" -eq 0 ]

  assert_output --partial 'AcctSessionId=5ff1ad49/7c:5c:f8:a5:08:07/121/2'
  refute_output --partial 'AcctUpdateTime=2021-01-03 14:41:42' # The AcctUpdateTime should be changed
  assert_output --partial 'AcctTerminateCause=NAS-Reboot'
}
