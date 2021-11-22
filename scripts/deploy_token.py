from os import access
from brownie import MlemToken

from scripts.helper import get_account


def deploy_token():
    account = get_account()
    mlem = MlemToken.deploy({"from": account})
    print(mlem)
