import { Container, Button } from "@mui/material";
import { formatEther } from "ethers/lib/utils";
import { MintForm } from "./components/MintForm";
import { ListForm } from "./components/ListForm";
import networkMapping from "../../chain-info/deployments/map.json";
import { ethers } from "ethers";
import { useCallback, useEffect, useState } from "react";
declare let window: any;

export const Market: React.FC = () => {
  const [account, setAccount] = useState("");
  const [etherBalance, setEtherBalance] = useState("");

  const tokenAddress: string = networkMapping["97"]["Nft"][0];
  const [isConnected, setIsconnected] = useState(window.ethereum.isConnected());
  const connectUser = useState(async () => {
    const provider = new ethers.providers.Web3Provider(window.ethereum);
    const signer = provider.getSigner();
    const address = await signer.getAddress();
    const balance = await provider.getBalance(address);
    setEtherBalance(String(formatEther(balance)));
    setAccount(address);
    setIsconnected(window.ethereum.isConnected());
  });

  const [state, setState] = useState(connectUser);
  const handleConnect = () => {
    window.ethereum
      .request({ method: "eth_requestAccounts" })
      .then(() => {})
      .catch((error: any) => {
        if (error.code === 4001) {
          // EIP-1193 userRejectedRequest error
          console.log("Please connect to MetaMask.");
        } else {
          console.error(error);
        }
      });
    setState(connectUser);
  };
  window.ethereum.on("accountsChanged", function (account: any) {
    setAccount(account);
  });
  window.ethereum.on("chainChanged", function (chainId: string) {
    console.log("Chain ID:", chainId === "0x61");
    setState(connectUser);
  });
  console.log("isConnected:", isConnected);
  console.log("Account:", account);
  console.log("Account:", state);
  return (
    <>
      {isConnected && account !== null ? (
        <></>
      ) : (
        <Button onClick={handleConnect} color="primary" variant="contained">
          Connect
        </Button>
      )}
      <div>
        {account && <p>Account: {account}</p>}
        {etherBalance && <p>Balance: {etherBalance}</p>}
      </div>
      {isConnected ? (
        <>
          <MintForm tokenAddress={tokenAddress} />
          <ListForm tokenAddress={tokenAddress} />
        </>
      ) : (
        <></>
      )}
    </>
  );
};
