import { useContractFunction } from "../../utils";
import { utils } from "ethers";
import Nft from "../../chain-info/contracts/Nft.json";
import { Contract } from "@ethersproject/contracts";

export const useMintToken = (nftContractAddress: string) => {
  // address
  // abi
  // chainId
  const nftAbi = Nft.abi;
  const nftInfterface = new utils.Interface(nftAbi);
  const nftContract = new Contract(nftContractAddress, nftInfterface);
  // approve
  const { send: mintNftSend, state: mintNftState } = useContractFunction(
    nftContract,
    "mintNft",
    {
      transactionName: "Mint Nft",
    }
  );
  const mintNft = (tokenName: string) => {
    return mintNftSend(tokenName);
  };

  return { mintNft, mintNftState };
};
