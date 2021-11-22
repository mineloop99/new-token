from brownie.network.web3 import Web3
from scripts.helper import get_account
from brownie import BEP20, config, network


def deploy_token():
    account = get_account()
    ani_token = BEP20.deploy(
        {"from": account},
        publish_source=config["networks"][network.show_active()]["verify"],
    )


def main():
    # deploy_token_farm_and_ani_token()
    deploy_token()
