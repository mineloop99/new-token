import { Contract, errors, ethers, utils } from "ethers";
import { useCallback, useState } from "react";
import { LogDescription } from "ethers/lib/utils";
import { JsonRpcSigner } from "@ethersproject/providers";
import {
  TransactionOptions,
  TransactionResponse,
  TransactionState,
  TransactionStatus,
} from "./transaction/transaction";
import { useTransactionsContext } from "./transaction/context";

declare let window: any;
export function connectContractToSigner(
  contract: Contract,
  options?: TransactionOptions,
  singer?: JsonRpcSigner
) {
  if (contract.signer) {
    return contract;
  }

  if (options?.signer) {
    return contract.connect(options.signer);
  }

  if (singer !== null && window.ethereum) {
    const provider = new ethers.providers.Web3Provider(window.ethereum);
    return contract.connect(provider.getSigner());
  }

  throw new TypeError("No signer available in contract, options or library");
}

export function addressEqual(
  firstAddress: string,
  secondAddress: string
): boolean {
  try {
    return utils.getAddress(firstAddress) === utils.getAddress(secondAddress);
  } catch {
    throw new TypeError("Invalid input, address can't be parsed");
  }
}

export function useContractFunction(
  contract: Contract,
  functionName: string,
  options?: TransactionOptions
) {
  const [events, setEvents] = useState<LogDescription[] | undefined>(undefined);
  const { promiseTransaction, state } = usePromiseTransaction(97, options);

  const send = useCallback(
    async (...args: any[]) => {
      const contractWithSigner = connectContractToSigner(contract, options);
      const receipt = await promiseTransaction(
        contractWithSigner[functionName](...args)
      );
      if (receipt?.logs) {
        const events = receipt.logs.reduce((accumulatedLogs, log) => {
          try {
            return addressEqual(log.address, contract.address)
              ? [...accumulatedLogs, contract.interface.parseLog(log)]
              : accumulatedLogs;
          } catch (_err) {
            return accumulatedLogs;
          }
        }, [] as LogDescription[]);
        setEvents(events);
      }
    },
    [contract, functionName, options, promiseTransaction]
  );
  return { send, state, events };
}

const isDroppedAndReplaced = (e: any) =>
  e?.code === errors.TRANSACTION_REPLACED &&
  e?.replacement &&
  (e?.reason === "repriced" || e?.cancelled === false);

export function usePromiseTransaction(
  chainId: number | undefined,
  options?: TransactionOptions
) {
  const [state, setState] = useState<TransactionStatus>({ status: "None" });
  const { addTransaction } = useTransactionsContext();

  const promiseTransaction = useCallback(
    async (transactionPromise: Promise<TransactionResponse>) => {
      if (!chainId) return;
      let transaction: TransactionResponse | undefined = undefined;
      try {
        transaction = await transactionPromise;

        setState({ transaction, status: "Mining", chainId });
        addTransaction({
          transaction: {
            ...transaction,
            chainId: chainId,
          },
          submittedAt: Date.now(),
          transactionName: options?.transactionName,
        });
        const receipt = await transaction.wait();
        setState({ receipt, transaction, status: "Success", chainId });
        return receipt;
      } catch (e: any) {
        const errorMessage =
          e.error?.message ?? e.reason ?? e.data?.message ?? e.message;
        if (transaction) {
          const droppedAndReplaced = isDroppedAndReplaced(e);

          if (droppedAndReplaced) {
            const status: TransactionState =
              e.receipt.status === 0 ? "Fail" : "Success";

            setState({
              status,
              transaction: e.replacement,
              originalTransaction: transaction,
              receipt: e.receipt,
              errorMessage,
              chainId,
            });
          } else {
            setState({
              status: "Fail",
              transaction,
              receipt: e.receipt,
              errorMessage,
              chainId,
            });
          }
        } else {
          setState({ status: "Exception", errorMessage, chainId });
        }
        return undefined;
      }
    },
    [chainId, addTransaction, options?.transactionName]
  );

  return { promiseTransaction, state };
}
