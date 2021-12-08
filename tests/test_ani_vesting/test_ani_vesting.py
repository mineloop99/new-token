from brownie import AniwarToken, AniwarVesting

from scripts.deploy_token import deploy_token
from scripts.helper import get_account, deploy_vesting_contract

import pytest
import time

vestingSchedule = 0
sleepingTimeDuration = 30


@pytest.mark.first
def test_ani_vesting_deploy():
    # Deploy and Transfer Token to Contract
    account = get_account()
    aniToken = deploy_token(account)
    vestingContract = deploy_vesting_contract(account, aniToken)
    aniToken.balanceOf(account.address)
    tx = aniToken.transfer(vestingContract.address, 500)
    tx.wait(1)
    assert (
        aniToken.balanceOf(account.address)
        + aniToken.balanceOf(vestingContract.address)
        == aniToken.totalSupply()
    )


@pytest.mark.second
def test_ani_vesting_createVestingSchedule():
    account = get_account()
    # Declare Variables
    address1 = account.address
    start = 0
    end = 0
    duration = sleepingTimeDuration
    amountReleased = 500
    revoked = False
    # Testing Behaviour
    vestingContract = AniwarVesting[-1]
    tx = vestingContract.createVestingSchedule(address1, duration, amountReleased)
    tx.wait(1)
    tx1 = vestingContract.getVestingScheduleByAddressAndIndex(address1, 0)
    assert tx1 == (address1, start, end, duration, amountReleased, revoked)
