package main

import (
	"context"
	"fmt"
	"log"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/mineloop99/new-token/back_end/server"
	"github.com/mineloop99/new-token/back_end/utils"
)

const host string = "127.0.0.1"
const port string = ":50001"

func main() {
	config, err := utils.GetConfig("./")
	if err != nil {
		log.Fatal(err)
	}
	signTx := utils.CallMethods(*config, "balanceOf", big.NewInt(0), common.HexToAddress("0xca751C6800320e06180fA8a8266b17986b5E26d8"))
	err = config.Client.SendTransaction(context.Background(), signTx)
	if err != nil {
		log.Fatalf("Cannot get config: %v", err)
	}
	ts := types.Transactions{signTx}
	fmt.Printf("tx sent: %v", ts)
	server.InitServer(host, port)
}
