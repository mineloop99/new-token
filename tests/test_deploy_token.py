from brownie import AniwarToken, networks, config
from scripts.helper import get_account


def test_deploy_token():
    account = get_account()
    
    assert account.address == 
    aniToken = AniwarToken.deploy(
        {"from": account},
        publish_source=config["networks"][networks.show_active()]["verify"],
    )