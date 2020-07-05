.PHONY: all clean store init benchmark-compute

all: build

build:
	RUSTFLAGS='-C link-arg=-s' cargo build --release --target wasm32-unknown-unknown --locked
	wasm-opt -Os ./target/wasm32-unknown-unknown/release/*.wasm -o ./contract.wasm
	cat contract.wasm | gzip -9 > contract.wasm.gz

clean:
	cargo clean
	-rm -f ./contract.wasm ./contract.wasm.gz

store: all
	secretcli tx compute store contract.wasm.gz --source "https://github.com/enigmampc/BenchmarkSecretContracts" --from mykey --yes --gas 1000000 -b block

init:
	$(eval CODE_ID := $(shell secretcli q compute list-code | jq -c '.[] | select(.source == "https://github.com/enigmampc/BenchmarkSecretContracts")' | tail -1 | jq .id))
	secretcli tx compute instantiate "$(CODE_ID)" '{}' --label benchmark --from mykey --yes -b block | jq .txhash | xargs secretcli q compute tx

benchmark-compute:
	$(eval CODE_ID := $(shell secretcli q compute list-code | jq -c '.[] | select(.source == "https://github.com/enigmampc/BenchmarkSecretContracts")' | tail -1 | jq .id))
	$(eval CONTRACT_ADDRESS := $(shell secretcli q compute list-contract-by-code $(CODE_ID) | jq -rc '.[].address' | head -1))
	seq 1 1000 | parallel -P 1000 --bar secretcli tx compute execute "$(CONTRACT_ADDRESS)" '{\"calculate\":{\"x\":1,\"y\":2}}' --from {} --yes