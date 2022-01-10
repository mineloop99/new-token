package nft

import (
	"context"
	"log"

	"github.com/mineloop99/new-token/back_end/features/nft/nft_pb"
	"github.com/mineloop99/new-token/back_end/utils"
	"google.golang.org/grpc"
)

type Server struct {
	nft_pb.UnimplementedNftServiceServer
}

func RewardRegister(s grpc.ServiceRegistrar) {
	nft_pb.RegisterNftServiceServer(s, &Server{})
}

func (*Server) GetNftOwnership(ctx context.Context, in *nft_pb.GetNftOwnershipRequest) (*nft_pb.GetNftOwnershipResponse, error) {
	_, err := utils.GetConfig("../../")
	if err != nil {
		log.Fatalf("GetNftOwnerShip: Cannot get config: %v", err)
	}
	tokenId := in.GetTokenId()

	res := "Random Number is: " + tokenId
	return &nft_pb.GetNftOwnershipResponse{
		Owner: res,
	}, nil
}
