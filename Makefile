.PHONY: all clean store init benchmark-compute

all:
	RUSTFLAGS='-C link-arg=-s' cargo build --release --target wasm32-unknown-unknown --locked
	wasm-opt -Os ./target/wasm32-unknown-unknown/release/*.wasm -o ./contract.wasm

clean:
	cargo clean
	-rm -f ./contract.wasm

store:
	secretcli tx compute store contract.wasm --source "https://github.com/enigmampc/BenchmarkSecretContracts" --from mykey --yes --gas 1000000

init:
	$(eval CODE_ID := $(shell secretcli q compute list-code | jq -c '.[] | select(.source == "https://github.com/enigmampc/BenchmarkSecretContracts")' | tail -1 | jq .id))
	secretcli tx compute instantiate "$(CODE_ID)" '{"init":{}}' --label benchmark --from mykey --yes

benchmark-compute:
	$(eval CODE_ID := $(shell secretcli q compute list-code | jq -c '.[] | select(.source == "https://github.com/enigmampc/BenchmarkSecretContracts")' | tail -1 | jq .id))
	$(eval CONTRACT_ADDRESS := $(shell secretcli q compute list-contract-by-code $(CODE_ID) | jq -rc '.[].address' | head -1))
	$(eval ACCOUNT_ADDRESS := $(shell secretcli keys show -a mykey))
	$(eval ACCOUNT_NUMBER := $(shell secretcli q account $(ACCOUNT_ADDRESS) | jq '.value.account_number'))
	$(eval SEQUENCE_START := $(shell secretcli q account $(ACCOUNT_ADDRESS) | jq '(.value.sequence)'))
	$(eval SEQUENCE_END := $(shell secretcli q account $(ACCOUNT_ADDRESS) | jq '(.value.sequence + 10)'))
	seq "$(SEQUENCE_START)" "$(SEQUENCE_END)" | parallel -P 1 -v --bar secretcli tx compute execute "$(CONTRACT_ADDRESS)" '{"calculate":{"x":1,"y":2}}}' --from mykey --yes -s {} -a "$(ACCOUNT_NUMBER)"