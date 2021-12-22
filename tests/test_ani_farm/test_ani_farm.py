from brownie import AniwarToken, AniwarFarm
import pytest

from scripts.helper import get_account


@pytest.mark.order1
def test_ani_token_farm():
    # Get Contract
    account = get_account()
    aniToken = AniwarToken.deploy({"from": account})
    aniFarm = AniwarFarm.deploy(aniToken.address, {"from": account})
    #
    # aniFarm.addAllowedTokens(, {'from': Account})
    print(aniToken)
