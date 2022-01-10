package utils

import (
	"fmt"
	"os"

	"github.com/spf13/viper"
)

type Config struct {
	Host       string
	Port       string
	NodeUrl    string
	PrivateKey string
	Abi        string
	Bin        string
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
	abi, err := os.ReadFile(providePath + "/AniWorldToken.abi")
	if err != nil {
		return nil, err
	}
	bin, err := os.ReadFile(providePath + "/AniWorldToken.bin")
	if err != nil {
		return nil, err
	}
	fmt.Println(string(abi))
	fmt.Println(string(bin))
	return &Config{
		Host:       viper.GetString("host"),
		Port:       viper.GetString("port"),
		NodeUrl:    viper.GetString("nodeUrl"),
		PrivateKey: viper.GetString("privateKey"),
		Abi:        string(abi),
	}, nil
}
