from brownie import accounts, config, network

NETWORKS = ["ropsten", "rinkeby", "bsc-test"]
# Rinkerby
OPENSEA_URL = "https://testnets.opensea.io/assets/{}/{}"


def get_account():
    if network.show_active() in NETWORKS:
        account = accounts.add(config["wallets"]["private_key"])
    account = accounts[0]
    return account


def get_nft_url(
    nftContractAddress="0xca751C6800320e06180fA8a8266b17986b5E26d8", tokenId=0
):
    return OPENSEA_URL.format(nftContractAddress, tokenId)
