package reward

import (
	"context"
	"strconv"

	"github.com/mineloop99/ani-blockchain-server/features/reward/reward_pb"
	"google.golang.org/grpc"
)

type Server struct {
	reward_pb.UnimplementedRewardServiceServer
}

func RewardRegister(s grpc.ServiceRegistrar) {
	reward_pb.RegisterRewardServiceServer(s, &Server{})
}

func (*Server) GetRewardByRandom(ctx context.Context, in *reward_pb.GetRewardByRandomRequest) (*reward_pb.GetRewardByRandomResponse, error) {
	message := in.GetNumber()
	res := "Random Number is: " + strconv.FormatInt(message+2, 10)
	return &reward_pb.GetRewardByRandomResponse{
		Message: res,
	}, nil
}
