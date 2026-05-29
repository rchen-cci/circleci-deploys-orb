FAILURE_ARG=""
if [ -n "$PARAM_FAILURE_REASON" ]; then
  FAILURE_ARG="--failure-reason=$PARAM_FAILURE_REASON"
fi
circleci run release update "$PARAM_DEPLOY_NAME" \
  --status="$PARAM_STATUS" \
  $FAILURE_ARG
