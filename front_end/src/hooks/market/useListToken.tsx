import { useEffect, useState } from "react";
import { useContractFunction } from "@usedapp/core";
import { constants, utils } from "ethers";
import Market from "../../chain-info/contracts/Market.json";
import Nft from "../../chain-info/contracts/Nft.json";
import { Contract } from "@ethersproject/contracts";
import networkMapping from "../../chain-info/deployments/map.json";

export const useListToken = (nftContractAddress: string) => {
  // address
  // abi
  // chainId
  const abi = Market.abi;
  const marketInterface = new utils.Interface(abi);
  const marketAddress = networkMapping["97"]["Market"][0];
  const marketContract = new Contract(marketAddress, marketInterface);

  const nftAbi = Nft.abi;
  const nftInfterface = new utils.Interface(nftAbi);
  const nftContract = new Contract(nftContractAddress, nftInfterface);
  // Check Approval For All
  const { send: checkApprovalSend, state: checkApprovalState } =
    useContractFunction(nftContract, "isApprovedForAll", {
      transactionName: "Check Approval For All Nft transfer",
    });
  // Approve For  All
  const { send: approveNftSend, state: approveAndListNftState } =
    useContractFunction(nftContract, "setApprovalForAll", {
      transactionName: "Approve Nft transfer",
    });
  // List
  const { send: listTokenSend, state: listTokenState } = useContractFunction(
    marketContract,
    "listToken",
    {
      transactionName: "List Token",
    }
  );
  const [priceToList, setPriceToList] = useState(["", ""]);

  // Execute
  const approveAndList = async (tokenId: string, price: string) => {
    await checkApprovalSend(account, marketAddress);
    setPriceToList([tokenId, price]);
    try {
      if (
        checkApprovalState.status === "Success" &&
        !checkApprovalState.transaction
      ) {
        return approveNftSend(marketAddress, "true");
      }
    } catch {}
  };
  //useEffect
  useEffect(() => {
    try {
      if (
        approveAndListNftState.status === "Success" ||
        checkApprovalState.transaction
      ) {
        listTokenSend(nftContractAddress, priceToList[0], priceToList[1]);
      }
    } catch {}
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    approveAndListNftState,
    priceToList,
    nftContractAddress,
    checkApprovalState.transaction,
  ]);

  const [state, setState] = useState(approveAndListNftState);

  useEffect(() => {
    try {
      if (
        approveAndListNftState.status === "Success" ||
        checkApprovalState.transaction
      ) {
        setState(listTokenState);
      } else {
        setState(approveAndListNftState);
      }
    } catch {}
  }, [approveAndListNftState, checkApprovalState.transaction, listTokenState]);

  return { approveAndList, state };
};
