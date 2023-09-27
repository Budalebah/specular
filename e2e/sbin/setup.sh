#!/bin/bash

# Configure variables
SBIN_DIR=`dirname $0`
SBIN_DIR="`cd "$SBIN_DIR"; pwd`"
set -o allexport
source $SBIN_DIR/configure.sh
set +o allexport

# Make project directory
rm -rf $PROJECT_DIR
mkdir -p $PROJECT_LOG_DIR
mkdir -p $PROJECT_DATA_DIR

# Add keys
cp $DATA_DIR/sequencer.prv $PROJECT_DATA_DIR/sequencer.prv
cp $DATA_DIR/validator.prv $PROJECT_DATA_DIR/validator.prv
cp $DATA_DIR/password.txt $PROJECT_DATA_DIR/password.txt

# Build and add genesis.json
cd $CONTRACTS_DIR
npx hardhat compile

$CONFIG_DIR/sbin/create_genesis.sh
cp $SIDECAR_DIR/data/genesis.json $PROJECT_DATA_DIR/genesis.json

# Build L2 client
cd $SBIN_DIR/../..
make sidecar
