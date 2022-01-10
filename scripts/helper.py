import os
import shutil 
from brownie import accounts, config, network, AniwarVesting

NETWORKS = ["ropsten", "rinkeby", "bsc-test"]
# Rinkerby
OPENSEA_URL = "https://testnets.opensea.io/assets/{}/{}"


def get_account():
    if network.show_active() in NETWORKS:
        account = accounts.add(config["wallets"]["private_key"])
    account = accounts[0]
    return account


def deploy_vesting_contract(account, aniwarToken):
    vestingContract = AniwarVesting.deploy(aniwarToken, {"from": account})
    return vestingContract


def update_back_end():
    # Send build to front end
    copy_build_to_client("./build", "./back_end/chain-info")



def copy_build_to_client(src, dest):
    if os.path.exists(dest):
        shutil.rmtree(dest)
    shutil.copytree(src, dest)

def get_nft_url(
    nftContractAddress="0xca751C6800320e06180fA8a8266b17986b5E26d8", tokenId=0
):
    return OPENSEA_URL.format(nftContractAddress, tokenId)
