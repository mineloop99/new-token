package main

import (
	"github.com/mineloop99/new-token/back_end/server"
	"github.com/mineloop99/new-token/back_end/utils"
)

const host string = "127.0.0.1"
const port string = ":50001"

func main() {
	server.InitServer(host, port)
	utils.GetConfig(".")
}
