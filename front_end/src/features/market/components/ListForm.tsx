import { useState, useEffect } from "react";
import {
  Input,
  CircularProgress,
  Button,
  Snackbar,
  Alert,
} from "@mui/material";
import { utils } from "ethers";
import { useNotifications } from "@usedapp/core";
import { useListToken } from "../../../hooks";

export const ListForm: React.FC<{
  tokenAddress: string;
}> = (props) => {
  const { notifications } = useNotifications();

  // Set Id
  const [nftId, setNftId] = useState<number | string | Array<number | string>>(
    0
  );
  const handleInputTokenIdChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    const newTokenId =
      event.target.value === "" ? "" : Number(event.target.value);
    setNftId(newTokenId);
  };

  // Set Amount
  const [amount, setAmount] = useState<number | string>(0);
  const handleListAmountChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    const newAmount =
      event.target.value === "" ? "" : Number(event.target.value);
    setAmount(newAmount);
  };

  // Approve and List call
  const { approveAndList, state: approveAndListState } = useListToken(
    props.tokenAddress
  );
  const handleListSubmit = () => {
    const amountAsWei = utils.parseEther(amount.toString());
    return approveAndList(String(nftId), String(amountAsWei));
  };

  const isMining = approveAndListState.status === "Mining";
  const [showNftApprovalSuccess, setShowNftApprovalSuccess] = useState(false);
  const [showListTokenSuccess, setShowListTokenSuccess] = useState(false);
  const [showListTokenError, setShowListTokenError] = useState(false);
  const handleCloseSnack = () => {
    setShowNftApprovalSuccess(false);
    setShowListTokenSuccess(false);
    setShowListTokenError(false);
  };

  useEffect(() => {
    try {
      if (
        notifications.filter(
          (notification) =>
            notification.type === "transactionSucceed" &&
            notification.transactionName === "Approve Nft transfer"
        ).length > 0
      ) {
        setShowNftApprovalSuccess(true);
        setShowListTokenSuccess(false);
      }
      if (!isMining) {
        setShowListTokenError(true);
      }
      if (
        notifications.filter(
          (notification) =>
            notification.type === "transactionSucceed" &&
            notification.transactionName === "List Token"
        ).length > 0
      ) {
        setShowNftApprovalSuccess(false);
        setShowListTokenSuccess(true);
      }
    } catch {}
  }, [notifications, isMining]);
  return (
    <>
      <div>
        <div>
          <h6>TokenId</h6>
          <Input onChange={handleInputTokenIdChange} />
        </div>
        <div>
          <h6>Amount</h6>
          <Input onChange={handleListAmountChange} />
        </div>
        <div>
          <Button
            onClick={handleListSubmit}
            color="primary"
            size="large"
            disabled={isMining}
          >
            {isMining ? <CircularProgress size={26} /> : "List!!!"}
          </Button>
        </div>
      </div>
      <Snackbar
        open={showNftApprovalSuccess}
        autoHideDuration={5000}
        onClose={handleCloseSnack}
      >
        <Alert onClose={handleCloseSnack} severity="success">
          NFT transfer approved! Now approve the 2nd transaction.
        </Alert>
      </Snackbar>
      <Snackbar
        open={showListTokenSuccess}
        autoHideDuration={5000}
        onClose={handleCloseSnack}
      >
        <Alert onClose={handleCloseSnack} severity="success">
          Tokens Listed!
        </Alert>
      </Snackbar>
      {!approveAndListState.errorMessage ||
      approveAndListState.errorMessage.length === 0 ? (
        <></>
      ) : (
        <Snackbar
          open={showListTokenError}
          autoHideDuration={5000}
          onClose={handleCloseSnack}
        >
          <Alert onClose={handleCloseSnack} severity="error">
            {approveAndListState.errorMessage}
          </Alert>
        </Snackbar>
      )}
    </>
  );
};
