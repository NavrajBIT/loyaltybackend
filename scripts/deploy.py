from eth_account import Account
from scripts.tools import get_account
from brownie import Loyalty2, network, config
from web3 import Web3
import json
from brownie import chain
import time

contract_data = {"mainContract": ""}


def deploy():
    account = get_account()
    print(account)
    max_supply = 1000
    main_contract = Loyalty2.deploy(max_supply, {"from": account})
    # main_contract.setOwner('0xc388C5e09964A06684C782C6E8090B5CF50c40EA', {'from': account})
    contract_data["mainContract"] = main_contract.address
    save_data()


def save_data():
    with open("./Frontend/loyalty/contractData.json", "w") as outfile:
        json.dump(contract_data, outfile)
    main_contract_compiled = json.load(open("./build/contracts/Loyalty2.json"))
    with open("./Frontend/loyalty/compiledContract.json", "w") as outfile:
        json.dump(main_contract_compiled, outfile)


def main():
    deploy()
