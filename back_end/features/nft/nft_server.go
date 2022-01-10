package nft

import (
	"context"
	"log"

	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/mineloop99/ani-blockchain-server/features/nft/nft_pb"
	"github.com/mineloop99/ani-blockchain-server/utils"
	"google.golang.org/grpc"
)

type Server struct {
	nft_pb.UnimplementedNftServiceServer
}

func RewardRegister(s grpc.ServiceRegistrar) {
	nft_pb.RegisterNftServiceServer(s, &Server{})
}

func (*Server) GetNftOwnership(ctx context.Context, in *nft_pb.GetNftOwnershipRequest) (*nft_pb.GetNftOwnershipResponse, error) {
	config, err := utils.GetConfig()
	if err != nil {
		log.Fatalf("Cannot get config: %v", err)
	}
	tokenId := in.GetTokenId()
	_, err = ethclient.Dial(config.NodeUrl)
	if err != nil {
		log.Fatalf("Cannot Connect to ethclient: %v", err)
	}
	res := "Random Number is: " + tokenId
	return &nft_pb.GetNftOwnershipResponse{
		Owner: res,
	}, nil
}
