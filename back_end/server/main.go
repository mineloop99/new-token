package server

import (
	"fmt"
	"log"
	"os"
	"os/signal"
)

func InitServer(host string, port string) {
	var s, lis = registerServer(host, port)
	go func() {
		fmt.Printf("Server listening at %s:%s\n", host, port)
		if err := s.Serve(lis); err != nil {
			log.Fatalf("Failed to serve: %v", err)
		}
	}()
	ch := make(chan os.Signal, 1)
	signal.Notify(ch, os.Interrupt)
	<-ch
	fmt.Println("Stopping the server")
	s.Stop()
	fmt.Println("Closing the listener")
	lis.Close()
	fmt.Println("End of Program")
}
