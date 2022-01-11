package token

import (
	"context"
	"log"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/mineloop99/new-token/back_end/features/token/token_pb"
	"github.com/mineloop99/new-token/back_end/utils"
	"google.golang.org/grpc"
)

type Server struct {
	token_pb.UnimplementedTokenServiceServer
}

func RewardRegister(s grpc.ServiceRegistrar) {
	token_pb.RegisterTokenServiceServer(s, &Server{})
}

func (*Server) GetTokenBalance(ctx context.Context, in *token_pb.GetTokenBalanceRequest) (*token_pb.GetTokenBalanceResponse, error) {
	config, err := utils.GetConfig()
	if err != nil {
		log.Fatalf("GetNftOwnerShip: Cannot get config: %v", err)
	}
	address := in.GetAddress()

	result := utils.CallViewMethods(config, "balanceOf", big.NewInt(0), common.HexToAddress(address))
	response := result[0].(*big.Int).String()
	println(response)
	return &token_pb.GetTokenBalanceResponse{
		Balance: response,
	}, nil
}
