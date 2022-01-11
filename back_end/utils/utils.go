package utils

import (
	"context"
	"crypto/ecdsa"
	"encoding/json"
	"io/ioutil"
	"log"
	"math/big"
	"os"
	"strings"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/spf13/viper"
)

const GAS_LIMIT = uint64(3000000) // in units

type Config struct {
	Host            string
	Port            string
	NodeUrl         string
	AccountAddress  string
	PrivateKey      string
	AniTokenAddress string
	Client          *ethclient.Client
	AniABI          abi.ABI
}

var config Config

func InitConfig(providePath string) error {
	viper.SetConfigName("config") // name of config file (without extension)
	viper.SetConfigType("yaml")   // REQUIRED if the config file does not have the extension in the name
	viper.AddConfigPath("../")    // path to look for the config file in
	viper.AddConfigPath(".")      // optionally look for config in the working directory
	err := viper.ReadInConfig()   // Find and read the config file
	if err != nil {               // Handle errors reading the config file
		log.Fatalf("Config: Cannot read ConfigYaml: %v", err)
	}
	client, err := ethclient.Dial(viper.GetString("nodeUrl"))
	if err != nil {
		log.Fatalf("Config: Cannot Connect to node url: %v", err)
	}
	aniABIC := make(chan abi.ABI)
	mapResultC := make(chan string)
	go func() {
		// Open our jsonFile
		jsonAbiFile, err := os.Open(providePath + "chain-info/contracts/AniwarToken.json")
		// if we os.Open returns an error then handle it
		if err != nil {
			log.Fatalf("Config: Cannot Open ABI json file: %v", err)
		}
		defer jsonAbiFile.Close()

		abiBytes, err := ioutil.ReadAll(jsonAbiFile)
		if err != nil {
			log.Fatalf("Config: Cannot read ABI: %v", err)
		}
		var result map[string]interface{}
		err = json.Unmarshal(abiBytes, &result)
		if err != nil {
			log.Fatalf("Config: Cannot Unmarshal ABI file json: %v", err)
		}
		dataAbiJson, err := json.Marshal(result["abi"])
		if err != nil {
			log.Fatalf("Config: Cannot Marshal ABI file json: %v", err)
		}
		_aniABI, err := abi.JSON(strings.NewReader(string(dataAbiJson)))
		if err != nil {
			log.Fatalf("Config: Cannot pack ABI: %v", err)
		}
		aniABIC <- _aniABI
	}()

	go func() {
		jsonMapFile, err := os.Open(providePath + "chain-info/deployments/map.json")
		if err != nil {
			log.Fatalf("Config: Cannot Open map.json: %v", err)
		}
		defer jsonMapFile.Close()

		mapBytes, err := ioutil.ReadAll(jsonMapFile)
		if err != nil {
			log.Fatalf("Config: Cannot Read map.json: %v", err)
		}

		var _mapResult map[string]map[string][]string
		json.Unmarshal(mapBytes, &_mapResult)
		mapResultC <- _mapResult["4"]["AniwarToken"][0]
	}()

	host := viper.GetString("host")
	port := viper.GetString("port")
	nodeUrl := viper.GetString("nodeUrl")
	accountAddress := viper.GetString("accountAddress")
	privateKey := viper.GetString("privateKey")
	config = Config{
		Host:            host,
		Port:            port,
		NodeUrl:         nodeUrl,
		AccountAddress:  accountAddress,
		PrivateKey:      privateKey,
		AniTokenAddress: <-mapResultC,
		Client:          client,
		AniABI:          <-aniABIC,
	}
	return nil
}
func GetConfig() (Config, error) {
	return config, nil
}

func CallMethods(config Config, methodName string, valueInWei *big.Int, args ...interface{}) *types.Transaction {
	privateKey, err := crypto.HexToECDSA(config.PrivateKey)
	if err != nil {
		log.Fatalf("SendMethods: Cannot convert Private key: %v", err)
	}

	publicKey := privateKey.Public()
	publicKeyECDSA, ok := publicKey.(*ecdsa.PublicKey)
	if !ok {
		log.Fatal("SendMethods: error casting public key to ECDSA")
	}

	fromAddress := crypto.PubkeyToAddress(*publicKeyECDSA)
	d := time.Now().Add(time.Second * 2)
	ctx, cancel := context.WithDeadline(context.Background(), d)
	defer cancel()

	toAddress := common.HexToAddress(config.AniTokenAddress)

	gasPrice, err := config.Client.SuggestGasPrice(ctx)
	if err != nil {
		log.Fatalf("SendMethods: Gas Price suggest error: %v", err)
	}

	nonce, err := config.Client.PendingNonceAt(ctx, fromAddress)
	if !ok {
		log.Fatalf("SendMethods: Nonce pending error: %v", err)
	}

	chainID, err := config.Client.NetworkID(ctx)
	if err != nil {
		log.Fatalf("SendMethods: Cannot get ChainID: %v", err)
	}

	data, err := config.AniABI.Pack(methodName, args...)
	if err != nil {
		log.Fatalf("SendMethods: Cannot Pack Method: %v", err)
	}

	tx := types.NewTransaction(nonce, toAddress, valueInWei, GAS_LIMIT, gasPrice, data)

	signedTx, err := types.SignTx(tx, types.NewEIP155Signer(chainID), privateKey)
	if err != nil {
		log.Fatalf("SendMethods: Cannot sign transaction: %v", err)
	}

	err = config.Client.SendTransaction(context.Background(), signedTx)
	if err != nil {
		log.Fatalf("Cannot send transaction: %v", err)
	}

	return signedTx
}

func CallViewMethods(config Config, methodName string, valueInWei *big.Int, args ...interface{}) []interface{} {

	d := time.Now().Add(time.Second * 2)
	ctx, cancel := context.WithDeadline(context.Background(), d)
	defer cancel()

	data, err := config.AniABI.Pack(methodName, args...)
	if err != nil {
		log.Fatalf("CallViewMethods: Cannot Pack Method: %v", err)
	}

	contractAddress := common.HexToAddress(config.AniTokenAddress)
	if err != nil {
		log.Fatalf("CallViewMethods: Cannot convert Contract Address: %v", err)
	}

	msg := ethereum.CallMsg{From: common.HexToAddress(config.AccountAddress), To: &contractAddress, Value: big.NewInt(0), Data: data}
	if err != nil {
		log.Fatalf("CallViewMethods: Cannot convert Msg: %v", err)
	}

	respone, err := config.Client.CallContract(ctx, msg, nil)
	if err != nil {
		log.Fatalf("CallViewMethods: Cannot Call Contract: %v", err)
	}

	var result []interface{}
	result, err = config.AniABI.Unpack(methodName, respone)
	if err != nil {
		log.Fatalf("CallViewMethods: Cannot Unpack Result: %v", err)
	}

	return result
}
