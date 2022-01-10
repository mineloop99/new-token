import { Market } from "./features/market/Market";
import { ethers } from "ethers";
import { useEffect, useState } from "react";

// const provider =
//   "https://speedy-nodes-nyc.moralis.io/9485086d85846cac9a1e6060/bsc/testnet";
declare let window: any;
//const localProvider = "http://127.0.0.1:7545";

// const config = {
//   readOnlyChainId: ChainId.BSCTestnet,
//   readOnlyUrls: {
//     [ChainId.BSCTestnet]: provider,
//   },
//   suportChains: [ChainId.BSCTestnet, ChainId.BSC],
//   notifications: {
//     expirationPeriod: 1000,
//     checkInterval: 1000,
//   },
//   autoConnect: false,
// };

export const App: React.FC = () => {
  return (
    <>
      <Market />
    </>
  );
};
export default App;
