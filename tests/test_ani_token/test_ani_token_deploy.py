from brownie import ContractContainer, AniwarToken, network, config, exceptions
import pytest

from scripts.deploy_token import deploy_token
from scripts.helper import get_account


@pytest.mark.first
def test_ani_token_deploy():
    # Deploy Token
    account = get_account()
    aniToken = deploy_token(account)
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
