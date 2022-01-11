package server

import (
	"log"
	"net"
	"time"

	"github.com/mineloop99/new-token/back_end/features/nft"
	"github.com/mineloop99/new-token/back_end/features/reward"
	"github.com/mineloop99/new-token/back_end/features/token"

	"google.golang.org/grpc"
)

func registerServer(host string, port string) (*grpc.Server, net.Listener) {

	var s *grpc.Server
	var opts []grpc.ServerOption
	opts = append(opts, grpc.ConnectionTimeout(time.Second*1))
	//opts = append(opts, initTls())
	s = grpc.NewServer(opts...)
	lis, err := net.Listen("tcp", host+":"+port)
	if err != nil {
		log.Fatalf("Failed to serve: %v", err)
	} else {
		println("Initilize Account Auth Server...")
	}
	s = grpc.NewServer(opts...)
	reward.RewardRegister(s)
	nft.RewardRegister(s)
	token.RewardRegister(s)

	return s, lis
}
