from brownie import AniwarToken, networks, config
from scripts.helper import get_account


def test_deploy_token():
    account = get_account()
    assert account.address == "0xca751C6800320e06180fA8a8266b17986b5E26d8"
    aniToken = AniwarToken.deploy(
        {"from": account},
        publish_source=config["networks"][networks.show_active()]["verify"],
    )
    assert aniToken.
