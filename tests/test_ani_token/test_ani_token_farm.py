from brownie import AniwarToken
import pytest

from scripts.helper import get_account


@pytest.mark.second
def test_ani_token_farm():
    # Get Contract
    account = get_account()
    aniToken = AniwarToken[-1]
    print(aniToken)
