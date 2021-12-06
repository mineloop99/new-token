from brownie import AniwarToken, config, network

from scripts.helper import get_account


def deploy_token(account):
    aniToken = AniwarToken.deploy(
        {"from": account},
        publish_source=config["networks"][network.show_active()]["verify"],
    )
    return aniToken
