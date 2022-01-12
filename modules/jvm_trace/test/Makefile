#CLUSTER?=alpha2
SHORE_URL?=https://test.us.api.shoreline-${CLUSTER}.io
SHORE_TOKEN?=`grep -B1 ${CLUSTER} ~/.ops_auth.yaml | grep "Token:" | tail -n 1 | cut -d':' -f2 | tr -d ' '`

TEST_SCRIPT=./test-jvm.sh

########################################
# Standard CI target:
# Run the full test cycle with install and cleanup
test: check-env
	SHORELINE_URL=$(SHORE_URL) SHORELINE_TOKEN=$(SHORE_TOKEN) CLUSTER=$(CLUSTER) $(TEST_SCRIPT)


########################################
# Manual targets for debugging and testing

# 
init: check-env
	SHORELINE_URL=$(SHORE_URL) SHORELINE_TOKEN=$(SHORE_TOKEN) terraform init

# only install/apply the terraform modules, does not ask for confirmation
install: check-env
	SHORELINE_URL=$(SHORE_URL) SHORELINE_TOKEN=$(SHORE_TOKEN) terraform apply --auto-approve

# only remove/destroy the terraform modules, does not ask for confirmation
remove: check-env
	SHORELINE_URL=$(SHORE_URL) SHORELINE_TOKEN=$(SHORE_TOKEN) terraform destroy --auto-approve

# Full (test) setup of terraform modules and k8s objects
setup: check-env
	SHORELINE_URL=$(SHORE_URL) SHORELINE_TOKEN=$(SHORE_TOKEN) CLUSTER=$(CLUSTER) $(TEST_SCRIPT) setup

# Full (test) cleanup of terraform modules and k8s objects
cleanup: check-env
	SHORELINE_URL=$(SHORE_URL) SHORELINE_TOKEN=$(SHORE_TOKEN) CLUSTER=$(CLUSTER) $(TEST_SCRIPT) cleanup

# run the test only, with no setup or cleanup
test-only: check-env
	SHORELINE_URL=$(SHORE_URL) SHORELINE_TOKEN=$(SHORE_TOKEN) CLUSTER=$(CLUSTER) $(TEST_SCRIPT) test-only

# run the test only, with tracing, with no setup or cleanup
debug-only: check-env
	SHORELINE_URL=$(SHORE_URL) SHORELINE_TOKEN=$(SHORE_TOKEN) CLUSTER=$(CLUSTER) $(TEST_SCRIPT) debug-only

.PHONY: distclean check-env

distclean:
	rm -rf terraform.tfstate terraform.tfstate.backup

check-env:
ifndef CLUSTER
	$(error CLUSTER is undefined)
endif
ifndef SHORE_URL
	$(error SHORE_URL is undefined)
endif


