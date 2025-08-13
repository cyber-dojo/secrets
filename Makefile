
ROOT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

test_secrets:
	@${ROOT_DIR}/test/run_all.sh
