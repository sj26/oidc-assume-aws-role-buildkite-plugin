#!/usr/bin/env bats

load "$BATS_PLUGIN_PATH/load.bash"

# Uncomment to enable stub debugging
# export AWS_STUB_DEBUG=/dev/tty

# Source the command and print environment variables to allow for assertions.
# This could be done by skipping the "run" command, but it makes for a more readable test.
run_test_command() {
  source "$@"

  echo "TESTRESULT:AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-"<value not set>"}"
  echo "TESTRESULT:AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-"<value not set>"}"
  echo "TESTRESULT:AWS_SESSION_TOKEN=${AWS_SESSION_TOKEN:-"<value not set>"}"
}

@test "calls aws sts and exports AWS_ env vars" {
  export BUILDKITE_JOB_ID="job-uuid-42"
  export BUILDKITE_PLUGIN_AWS_ASSUME_ROLE_WITH_WEB_IDENTITY_ROLE_ARN="role123"

  stub buildkite-agent "oidc request-token --audience sts.amazonaws.com * : echo 'buildkite-oidc-token'"
  stub aws "sts assume-role-with-web-identity --role-arn role123 --role-session-name buildkite-job-job-uuid-42 --web-identity-token buildkite-oidc-token : cat tests/sts.json"

  run run_test_command $PWD/hooks/environment

  assert_success
  assert_output --partial "Role ARN: role123"
  assert_output --partial "Assumed role: assumed-role-id-value"

  assert_output --partial "TESTRESULT:AWS_ACCESS_KEY_ID=access-key-id-value"
  assert_output --partial "TESTRESULT:AWS_SECRET_ACCESS_KEY=secret-access-key-value"
  assert_output --partial "TESTRESULT:AWS_SESSION_TOKEN=session-token-value"

  unstub aws
  unstub buildkite-agent
}

@test "failure to get token" {
  export BUILDKITE_JOB_ID="job-uuid-42"
  export BUILDKITE_PLUGIN_AWS_ASSUME_ROLE_WITH_WEB_IDENTITY_ROLE_ARN="role123"

  stub buildkite-agent "oidc request-token --audience sts.amazonaws.com * : echo 'failed to get OIDC token' >&2; false"

  run run_test_command $PWD/hooks/environment

  assert_failure
  assert_output <<EOF
~~~ Assuming IAM role role123 ...
Not authorized to perform sts:AssumeRoleWithWebIdentity
EOF

  unstub buildkite-agent
}
@test "failure to assume role" {
  export BUILDKITE_JOB_ID="job-uuid-42"
  export BUILDKITE_PLUGIN_AWS_ASSUME_ROLE_WITH_WEB_IDENTITY_ROLE_ARN="role123"

  stub buildkite-agent "oidc request-token --audience sts.amazonaws.com * : echo 'buildkite-oidc-token'"
  stub aws "sts assume-role-with-web-identity --role-arn role123 --role-session-name buildkite-job-job-uuid-42 --web-identity-token buildkite-oidc-token : echo 'Not authorized to perform sts:AssumeRoleWithWebIdentity' >&2; false"

  run run_test_command $PWD/hooks/environment

  assert_failure
  assert_output <<EOF
~~~ Assuming IAM role role123 ...
Not authorized to perform sts:AssumeRoleWithWebIdentity
EOF

  unstub aws
  unstub buildkite-agent
}

@test "calls aws sts with custom duration" {
  export BUILDKITE_JOB_ID="job-uuid-42"
  export BUILDKITE_PLUGIN_AWS_ASSUME_ROLE_WITH_WEB_IDENTITY_ROLE_ARN="role123"
  export BUILDKITE_PLUGIN_AWS_ASSUME_ROLE_WITH_WEB_IDENTITY_ROLE_SESSION_DURATION="43200"

  stub buildkite-agent "oidc request-token --audience sts.amazonaws.com --lifetime 43200 : echo 'buildkite-oidc-token'"
  stub aws "sts assume-role-with-web-identity --role-arn role123 --role-session-name buildkite-job-job-uuid-42 --web-identity-token buildkite-oidc-token --duration-seconds 43200 : cat tests/sts.json"

  run run_test_command $PWD/hooks/environment

  assert_success
  assert_output --partial "Role ARN: role123"
  assert_output --partial "Assumed role: assumed-role-id-value"

  assert_output --partial "TESTRESULT:AWS_ACCESS_KEY_ID=access-key-id-value"
  assert_output --partial "TESTRESULT:AWS_SECRET_ACCESS_KEY=secret-access-key-value"
  assert_output --partial "TESTRESULT:AWS_SESSION_TOKEN=session-token-value"

  unstub aws
  unstub buildkite-agent
}
