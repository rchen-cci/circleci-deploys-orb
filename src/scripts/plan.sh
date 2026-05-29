COMPONENT_ARG=""
ENV_ARG=""
NAMESPACE_ARG=""
VERSION="${PARAM_TARGET_VERSION:-${CIRCLE_SHA1:0:7}}"
if [ -n "$PARAM_COMPONENT_NAME" ]; then
  COMPONENT_ARG="--component-name=$PARAM_COMPONENT_NAME"
fi
if [ -n "$PARAM_ENVIRONMENT_NAME" ]; then
  ENV_ARG="--environment-name=$PARAM_ENVIRONMENT_NAME"
fi
if [ -n "$PARAM_NAMESPACE" ]; then
  NAMESPACE_ARG="--namespace=$PARAM_NAMESPACE"
fi
circleci run release plan "$PARAM_DEPLOY_NAME" \
  $COMPONENT_ARG \
  $ENV_ARG \
  $NAMESPACE_ARG \
  --target-version="$VERSION"
