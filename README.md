# Socks
Socks is an experimental server developed with the purpose of learning how to build a real-time multi-client application with C and Löve2D.

## Client

Needs [Love2d](https://love2d.org/)! 

- Install Love2d
- Download the client
- Configure its host editing the source
- Open a terminal in the folder
- Execute
```bash
love .
```
It's that easy! Try opening multiple clients with the server on!

## Server

Written in POSIX C.
Compile server with gcc, then execute. Should have no problems with that.

## Features

At the current stage, Socks implements a basic "connection" protocol defined at application level based on UDP packets (which are actually connectionless datagrams). This is a workaround used by many online games to keep the performances high and still allow for connections. 

Users are allowed to connect with a unique ID to the server (uniqueness check not yet implemented, in next revision the ID will be assigned from the server itself, instead of client). 

- __Movement Prediction__: 
A connected client starts periodically sending packets containing player position and movement direction.
If the server recognizes a movement change, it sends a packet containing that information to all the clients.
This way, the clients can render the movement in that direction.
As soon as the server recognizes another movement change, it sends that info to all the clients again, so that they can re-adjust the current position and movement of the player moving.
This allows for only two packets per direction change to be exchanged instead of a periodical exchange of the actual position which could easily congest the network and appear laggy for any user. 
The clients are actually rendering a predicted movement which isn't validated by the server until a direction change packet arrives.

- __Chat__:
An ASCII chat with server-based spam timeout and hash control for integrity. It just works.
