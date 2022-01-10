import { useState, useEffect } from "react";
import {
  Input,
  CircularProgress,
  Button,
  Snackbar,
  Alert,
} from "@mui/material";
import { useMintToken } from "../../../hooks";

export const MintForm: React.FC<{
  tokenAddress: string;
}> = (props) => {
  // Set Nft Name
  const [nftName, setnftName] = useState<
    number | string | Array<number | string>
  >("");
  const handleInputTokenNameChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    const newTokenId = event.target.value === "" ? "" : event.target.value;
    setnftName(newTokenId);
  };

  // Approve and List call
  const { mintNft, mintNftState } = useMintToken(props.tokenAddress);
  const handleMintNftSubmit = () => {
    return mintNft(String(nftName));
  };

  const isMining = mintNftState.status === "Mining";
  const [showMintNftSuccess, setShowMintNftSuccess] = useState(false);
  const handleCloseSnack = () => {
    setShowMintNftSuccess(false);
  };
  useEffect(() => {
    if (mintNftState.status === "Success") {
      setShowMintNftSuccess(true);
    }
  }, [mintNftState]);
  return (
    <>
      <div>
        <div>
          <h6>TokenName</h6>
          <Input onChange={handleInputTokenNameChange} />
        </div>
        <div>
          <Button onClick={handleMintNftSubmit} color="primary" size="large">
            {isMining ? <CircularProgress size={26} /> : "Mint Token!"}
          </Button>
        </div>
      </div>
      <Snackbar
        open={showMintNftSuccess}
        autoHideDuration={5000}
        onClose={handleCloseSnack}
      >
        <Alert onClose={handleCloseSnack} severity="success">
          Minted Nft Succeed!
        </Alert>
      </Snackbar>
    </>
  );
};
