package utils

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"strings"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/spf13/viper"
)

type Config struct {
	Host              string
	Port              string
	NodeUrl           string
	PrivateKey        string
	ContractInterface abi.ABI
}

func GetConfig(providePath string) (*Config, error) {
	viper.SetConfigName("config") // name of config file (without extension)
	viper.SetConfigType("yaml")   // REQUIRED if the config file does not have the extension in the name
	viper.AddConfigPath("../")    // path to look for the config file in
	viper.AddConfigPath(".")      // optionally look for config in the working directory
	err := viper.ReadInConfig()   // Find and read the config file
	if err != nil {               // Handle errors reading the config file
		return nil, err
	}
	// Open our jsonFile
	jsonFile, err := os.Open(providePath + "chain-info/contracts/AniwarToken.json")
	// if we os.Open returns an error then handle it
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println("Successfully Opened users.json")
	// defer the closing of our jsonFile so that we can parse it later on
	defer jsonFile.Close()

	byteValue, _ := ioutil.ReadAll(jsonFile)

	var result map[string]interface{}
	json.Unmarshal([]byte(byteValue), &result)
	abiBytes, err := json.Marshal(result["abi"])
	if err != nil {
		log.Fatalf("Cannot read ABI: %v", err)
	}
	contractInterface, err := abi.JSON(strings.NewReader(string(abiBytes)))
	if err != nil {
		log.Fatalf("Cannot pack ABI: %v", err)
	}
	return &Config{
		Host:              viper.GetString("host"),
		Port:              viper.GetString("port"),
		NodeUrl:           viper.GetString("nodeUrl"),
		PrivateKey:        viper.GetString("privateKey"),
		ContractInterface: contractInterface,
	}, nil
}
