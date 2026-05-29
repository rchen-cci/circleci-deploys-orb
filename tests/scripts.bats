#!/usr/bin/env bats

# Mock circleci by writing a tiny executable into a temp bin dir and prepending
# it to PATH. This avoids `export -f` which can be unreliable across subshells.
# The mock appends its arguments to $CALLS so tests can assert on them.

setup() {
  MOCK_BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$MOCK_BIN"
  export CALLS="$BATS_TEST_TMPDIR/calls"

  cat > "$MOCK_BIN/circleci" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$CALLS"
EOF
  chmod +x "$MOCK_BIN/circleci"
  export PATH="$MOCK_BIN:$PATH"

  # Defaults every test can override
  export CIRCLE_SHA1="abc1234567890"
  export PARAM_DEPLOY_NAME="deploy"
  export PARAM_COMPONENT_NAME=""
  export PARAM_ENVIRONMENT_NAME=""
  export PARAM_NAMESPACE=""
  export PARAM_TARGET_VERSION=""
  export PARAM_STATUS="SUCCESS"
  export PARAM_FAILURE_REASON=""
}

# ─── plan.sh ──────────────────────────────────────────────────────────────────

@test "plan: uses explicit target_version when provided" {
  export PARAM_TARGET_VERSION="v1.2.3"
  run bash src/scripts/plan.sh
  [ "$status" -eq 0 ]
  grep -q -- '--target-version=v1.2.3' "$CALLS"
}

@test "plan: falls back to short CIRCLE_SHA1 when target_version is empty" {
  export PARAM_TARGET_VERSION=""
  run bash src/scripts/plan.sh
  [ "$status" -eq 0 ]
  grep -q -- '--target-version=abc1234' "$CALLS"
}

@test "plan: omits --component-name when component_name is empty" {
  run bash src/scripts/plan.sh
  [ "$status" -eq 0 ]
  ! grep -q -- '--component-name' "$CALLS"
}

@test "plan: includes --component-name when component_name is set" {
  export PARAM_COMPONENT_NAME="my-service"
  run bash src/scripts/plan.sh
  [ "$status" -eq 0 ]
  grep -q -- '--component-name=my-service' "$CALLS"
}

@test "plan: omits --environment-name when environment_name is empty" {
  run bash src/scripts/plan.sh
  [ "$status" -eq 0 ]
  ! grep -q -- '--environment-name' "$CALLS"
}

@test "plan: includes --environment-name when environment_name is set" {
  export PARAM_ENVIRONMENT_NAME="production"
  run bash src/scripts/plan.sh
  [ "$status" -eq 0 ]
  grep -q -- '--environment-name=production' "$CALLS"
}

@test "plan: omits --namespace when namespace is empty" {
  run bash src/scripts/plan.sh
  [ "$status" -eq 0 ]
  ! grep -q -- '--namespace' "$CALLS"
}

@test "plan: includes --namespace when namespace is set" {
  export PARAM_NAMESPACE="kube-system"
  run bash src/scripts/plan.sh
  [ "$status" -eq 0 ]
  grep -q -- '--namespace=kube-system' "$CALLS"
}

@test "plan: passes deploy_name to CLI" {
  export PARAM_DEPLOY_NAME="frontend-deploy"
  run bash src/scripts/plan.sh
  [ "$status" -eq 0 ]
  grep -q 'release plan frontend-deploy' "$CALLS"
}

# ─── log.sh ───────────────────────────────────────────────────────────────────

@test "log: uses explicit target_version when provided" {
  export PARAM_TARGET_VERSION="v2.0.0"
  run bash src/scripts/log.sh
  [ "$status" -eq 0 ]
  grep -q -- '--target-version=v2.0.0' "$CALLS"
}

@test "log: falls back to short CIRCLE_SHA1 when target_version is empty" {
  export PARAM_TARGET_VERSION=""
  run bash src/scripts/log.sh
  [ "$status" -eq 0 ]
  grep -q -- '--target-version=abc1234' "$CALLS"
}

@test "log: omits optional flags when all params are empty" {
  run bash src/scripts/log.sh
  [ "$status" -eq 0 ]
  ! grep -q -- '--component-name' "$CALLS"
  ! grep -q -- '--environment-name' "$CALLS"
  ! grep -q -- '--namespace' "$CALLS"
}

@test "log: includes all optional flags when all params are set" {
  export PARAM_COMPONENT_NAME="api"
  export PARAM_ENVIRONMENT_NAME="staging"
  export PARAM_NAMESPACE="default"
  run bash src/scripts/log.sh
  [ "$status" -eq 0 ]
  grep -q -- '--component-name=api' "$CALLS"
  grep -q -- '--environment-name=staging' "$CALLS"
  grep -q -- '--namespace=default' "$CALLS"
}

@test "log: calls release log subcommand (not plan)" {
  run bash src/scripts/log.sh
  [ "$status" -eq 0 ]
  grep -q 'release log' "$CALLS"
  ! grep -q 'release plan' "$CALLS"
}

# ─── update_status.sh ─────────────────────────────────────────────────────────

@test "update_status: passes deploy_name and status to CLI" {
  export PARAM_DEPLOY_NAME="backend-deploy"
  export PARAM_STATUS="SUCCESS"
  run bash src/scripts/update_status.sh
  [ "$status" -eq 0 ]
  grep -q 'release update backend-deploy' "$CALLS"
  grep -q -- '--status=SUCCESS' "$CALLS"
}

@test "update_status: omits --failure-reason when failure_reason is empty" {
  export PARAM_FAILURE_REASON=""
  run bash src/scripts/update_status.sh
  [ "$status" -eq 0 ]
  ! grep -q -- '--failure-reason' "$CALLS"
}

@test "update_status: includes --failure-reason when failure_reason is set" {
  export PARAM_STATUS="FAILED"
  export PARAM_FAILURE_REASON="deploy timed out"
  run bash src/scripts/update_status.sh
  [ "$status" -eq 0 ]
  grep -q -- '--failure-reason=deploy timed out' "$CALLS"
}

@test "update_status: works for each valid status value" {
  for s in RUNNING SUCCESS FAILED CANCELED; do
    rm -f "$CALLS"
    export PARAM_STATUS="$s"
    run bash src/scripts/update_status.sh
    [ "$status" -eq 0 ]
    grep -q -- "--status=$s" "$CALLS"
  done
}
