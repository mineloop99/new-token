package server

import (
	"log"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
)

func initTls() grpc.ServerOption {
	certFile := "openssl/server.crt"
	keyFile := "openssl/server.pem"
	creds, sslErr := credentials.NewServerTLSFromFile(certFile, keyFile)
	if sslErr != nil {
		log.Fatalf("Failed loading certificates: %v", sslErr)
	}

	return grpc.Creds(creds)
}
