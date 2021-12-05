from brownie import AniwarToken, network, config, exceptions, Contract
from scripts.helper import get_account
import pytest


def test_deploy_token():
    # Deploy Token
    account = get_account()
    aniToken = AniwarToken.deploy(
        {"from": account},
        publish_source=config["networks"][network.show_active()]["verify"],
    )
    # Transfer with paused()
    aniToken.pause()
    oldBalance = aniToken.balanceOf(account.address)
    with pytest.raises(exceptions.VirtualMachineError):
        tx = aniToken.transfer(
            config["networks"][network.show_active()]["recipient"], 5000000
        )
        tx.wait(1)
    assert aniToken.balanceOf(account.address) == oldBalance
    # Transfer when unpaused()
    oldBalance2 = aniToken.balanceOf(account.address)
    aniToken.unpause()
    tx = aniToken.transfer(
        config["networks"][network.show_active()]["recipient"], 5000000
    )
    tx.wait(1)
    assert aniToken.balanceOf(account.address) < oldBalance2


def test_aniwar_farm():
    # Get Contract
    account = get_account()
    aniToken = AniwarToken[-1]
    print(aniToken)
