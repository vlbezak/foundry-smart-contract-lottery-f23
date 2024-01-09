-include .env

.PHONY: all install display-anvil-key test deploy fund-subscription-sepolia

ANVIL_PRIVATE_KEY ?= "10xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
DEFAULT_ANVIL_KEY := $(ANVIL_PRIVATE_KEY)

display-anvil-key:
	echo "$(DEFAULT_ANVIL_KEY)"
	
help: 
	@echo "Usage:"
	@echo "make deploy [ARGS=...]"

buid:
	forge build

install:
	forge install Cyfrin/foundry-devops --no-commit
	forge install smartcontractkit/chainlink-brownie-contracts@0.6.1 --no-commit
	forge install transmissions11/solmate --no-commit
	forge install foundry-rs/forge-std@1.7.4 --no-commit

fund-subscription-sepolia:
	forge script script/Interactions.s.sol:FundVRFSubscription --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast

test:
	forge test


NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

# if --network sepolia is used, then use sepolia, otherwise use anvil
ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvv
endif

deploy:
	forge script script/DeployRaffle.s.sol:DeployRaffle $(NETWORK_ARGS)		