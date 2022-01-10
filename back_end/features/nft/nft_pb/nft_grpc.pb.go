// Code generated by protoc-gen-go-grpc. DO NOT EDIT.

package nft_pb

import (
	context "context"
	grpc "google.golang.org/grpc"
	codes "google.golang.org/grpc/codes"
	status "google.golang.org/grpc/status"
)

// This is a compile-time assertion to ensure that this generated file
// is compatible with the grpc package it is being compiled against.
// Requires gRPC-Go v1.32.0 or later.
const _ = grpc.SupportPackageIsVersion7

// NftServiceClient is the client API for NftService service.
//
// For semantics around ctx use and closing/ending streaming RPCs, please refer to https://pkg.go.dev/google.golang.org/grpc/?tab=doc#ClientConn.NewStream.
type NftServiceClient interface {
	// Sends a Random Reward
	GetNftOwnership(ctx context.Context, in *GetNftOwnershipRequest, opts ...grpc.CallOption) (*GetNftOwnershipResponse, error)
}

type nftServiceClient struct {
	cc grpc.ClientConnInterface
}

func NewNftServiceClient(cc grpc.ClientConnInterface) NftServiceClient {
	return &nftServiceClient{cc}
}

func (c *nftServiceClient) GetNftOwnership(ctx context.Context, in *GetNftOwnershipRequest, opts ...grpc.CallOption) (*GetNftOwnershipResponse, error) {
	out := new(GetNftOwnershipResponse)
	err := c.cc.Invoke(ctx, "/nft_pb.NftService/GetNftOwnership", in, out, opts...)
	if err != nil {
		return nil, err
	}
	return out, nil
}

// NftServiceServer is the server API for NftService service.
// All implementations must embed UnimplementedNftServiceServer
// for forward compatibility
type NftServiceServer interface {
	// Sends a Random Reward
	GetNftOwnership(context.Context, *GetNftOwnershipRequest) (*GetNftOwnershipResponse, error)
	mustEmbedUnimplementedNftServiceServer()
}

// UnimplementedNftServiceServer must be embedded to have forward compatible implementations.
type UnimplementedNftServiceServer struct {
}

func (UnimplementedNftServiceServer) GetNftOwnership(context.Context, *GetNftOwnershipRequest) (*GetNftOwnershipResponse, error) {
	return nil, status.Errorf(codes.Unimplemented, "method GetNftOwnership not implemented")
}
func (UnimplementedNftServiceServer) mustEmbedUnimplementedNftServiceServer() {}

// UnsafeNftServiceServer may be embedded to opt out of forward compatibility for this service.
// Use of this interface is not recommended, as added methods to NftServiceServer will
// result in compilation errors.
type UnsafeNftServiceServer interface {
	mustEmbedUnimplementedNftServiceServer()
}

func RegisterNftServiceServer(s grpc.ServiceRegistrar, srv NftServiceServer) {
	s.RegisterService(&NftService_ServiceDesc, srv)
}

func _NftService_GetNftOwnership_Handler(srv interface{}, ctx context.Context, dec func(interface{}) error, interceptor grpc.UnaryServerInterceptor) (interface{}, error) {
	in := new(GetNftOwnershipRequest)
	if err := dec(in); err != nil {
		return nil, err
	}
	if interceptor == nil {
		return srv.(NftServiceServer).GetNftOwnership(ctx, in)
	}
	info := &grpc.UnaryServerInfo{
		Server:     srv,
		FullMethod: "/nft_pb.NftService/GetNftOwnership",
	}
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		return srv.(NftServiceServer).GetNftOwnership(ctx, req.(*GetNftOwnershipRequest))
	}
	return interceptor(ctx, in, info, handler)
}

// NftService_ServiceDesc is the grpc.ServiceDesc for NftService service.
// It's only intended for direct use with grpc.RegisterService,
// and not to be introspected or modified (even as a copy)
var NftService_ServiceDesc = grpc.ServiceDesc{
	ServiceName: "nft_pb.NftService",
	HandlerType: (*NftServiceServer)(nil),
	Methods: []grpc.MethodDesc{
		{
			MethodName: "GetNftOwnership",
			Handler:    _NftService_GetNftOwnership_Handler,
		},
	},
	Streams:  []grpc.StreamDesc{},
	Metadata: "nft_pb/nft.proto",
}
