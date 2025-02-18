#!/bin/bash
if [[ $# -eq 0 ]]; then
  echo "no test name provided"
  exit 1
fi

# the local sbin paths are relative to the project root
SBIN=$(dirname "$(readlink -f "$0")")
SBIN="$(
  cd "$SBIN"
  pwd
)"
. $SBIN/utils/utils.sh
ROOT_DIR=$SBIN/..

###### Process handling ######
trap ctrl_c INT

function cleanup() {
  echo "Cleaning up processes..."
  pgrep geth | xargs kill
  pgrep sidecar | xargs kill
  pgrep magi | xargs kill
  L1_PORT=4012
  if [ -n "$L1_PORT" ]; then
    L1_PORT_PID=$(lsof -i tcp:${L1_PORT} | awk 'NR!=1 {print $2}')
    if [ -n "$L1_WS_PID" ]; then
      echo "Killing proc on $L1_PORT"
      kill $L1_PORT_PID
    fi
  fi
  # Clean up
  $SBIN/clean.sh
}

function ctrl_c() {
  cleanup
  exit
}

##############################

# Check that the all required dotenv files exists.
reqdotenv "paths" ".paths.env"
reqdotenv "sidecar" ".sidecar.env"

WORKSPACE_DIR=./workspace-test
mkdir -p $WORKSPACE_DIR
cd $WORKSPACE_DIR

echo "Cleaning $WORKSPACE_DIR"
$SBIN/clean.sh
# Copy config files to cwd.
echo "Copying local_devnet config files to cwd..."
cp -a $CONFIG_DIR/e2e_test/. .

# Start L1
yes | $SBIN/generate_secrets.sh -d
yes | $SBIN/start_l1.sh -d -s &

# Parse url into host:port
L1_HOST_AND_PORT=${L1_ENDPOINT#*://}
# Wait for services
$SBIN/wait-for-it.sh -t 60 $L1_HOST_AND_PORT | sed "s/^/[WAIT] /"
echo "L1 endpoint is available"
until [ -f ".deployed" ]; do
  echo "waiting for L1 to be fully deployed..."
  sleep 4
done

reqdotenv "deployments" ".deployments.env"

# Start sp-geth
$SBIN/start_sp_geth.sh -c &>proc.out &
sleep 1

# Start sp-magi
$SBIN/start_sp_magi.sh &>proc2.out &
sleep 1

# Start sidecar
$SBIN/start_sidecar.sh &>proc3.out &
sleep 1

cd $CONTRACTS_DIR
echo "Running test: $1"
# Run testing script
case $1 in
transactions)
  npx hardhat run scripts/e2e/test_transactions.ts
  RESULT=$?
  ;;
deposit)
  npx hardhat run scripts/e2e/bridge/test_standard_bridge_deposit_eth.ts
  RESULT=$?
  ;;
withdraw)
  npx hardhat run scripts/e2e/bridge/test_standard_bridge_withdraw_eth.ts
  RESULT=$?
  ;;
erc20)
  npx hardhat run scripts/e2e/bridge/test_standard_bridge_erc20.ts
  RESULT=$?
  ;;
*)
  echo "unknown test"
  RESULT=1
  ;;
esac

cleanup
exit $RESULT
