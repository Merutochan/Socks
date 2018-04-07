/*

// Meru
// UDP SERVER
// merutochan@gmail.com

*/

#define DEFAULT_PORT 42069
#define BUFFER_LENGTH 512
#define TIMEOUT_TIME 5
#define RETRANSMISSIONS 1 

#define MSG_LOGOUT 2
#define MSG_MOVEMENT 3

#include <stdio.h> /* for IO and perror */
#include <stdlib.h> /* for duh... malloc and such*/
#include <string.h> /* for strings */
#include <sys/socket.h> /* for sockets */
#include <time.h> /* for clock() */
#include <fcntl.h> /* for fcntl() on socket */
#include <netinet/in.h> /* for sockaddr_in and such */
#include <arpa/inet.h> /* for in_addr and such */
#include <unistd.h> /* for close() */
#include "gameServer.h" /* define basics for S/C interaction */

// Check error function
void error(char *msg){
    perror(msg);
    exit(1);
}

int main(int argc, char **argv){

	char buffer[BUFFER_LENGTH];
	char messageData[BUFFER_LENGTH - sizeof(char)*2 - sizeof(int)*2];
	
	struct sockaddr_in serverAddress, clientAddress;
	socklen_t socketLength;
	client_t * knownClients = NULL, *d = NULL, *dd = NULL;
	struct clientRemoval *rem = NULL;
	int nKnownClients=0;
	
	int newClientConnected;
	
	int portNo;
	int socketServer;
	
	int x, y, dx, dy;
	
	int i, j;
	unsigned int receivedID, receivedType;
	
	/* ================================================ */

    // Port Number
    portNo = (argc==2) ? atoi(argv[1]) : DEFAULT_PORT;

	// Open Socket
    socketServer=socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (socketServer<0)
		error("Errore Socket");
	
    // Set socket as Non-Blocking
    fcntl(socketServer, F_SETFL, O_NONBLOCK);
	
	// Mem set to 0
	memset((char *) &serverAddress, 0, sizeof(serverAddress));
	
	rem = malloc(sizeof(struct clientRemoval));
	d = malloc(sizeof(client_t));
	
    // Define Address
    serverAddress.sin_family = AF_INET;
    serverAddress.sin_addr.s_addr = htonl(INADDR_ANY);
    serverAddress.sin_port = htons(portNo);

	// Bind Socket
    if (bind(socketServer,(struct sockaddr*) &serverAddress, 
		sizeof(serverAddress)) < 0)
			error("Bind Error");

	// Main cycle
    while(1){
		// Reset flag
		newClientConnected = 0;
		
		// TIMEOUT ROUTINE
		rem = removeClientByTimeout(knownClients);	
		if (rem!=NULL){
			knownClients = rem->list;
			if(rem->removedID != 0){
				printf("ID %d disconnected...\n", rem->removedID);
				nKnownClients--;
				// Prepare packet to forward
				sprintf(buffer, "%d %d", rem->removedID, MSG_LOGOUT);
				// Send LOGOUT info to all other clients
				for (d=knownClients;d!=NULL;d=d->next){
					for(i=0;i<RETRANSMISSIONS;i++){
						j = sendto(socketServer, buffer, BUFFER_LENGTH, 
									0, (struct sockaddr *) d->address,
									d->len);
						if (j < 0)
							error("SendTo Error");
					}
				}
			}
		}
		
		// RECEIVE ROUTINE
		if(recvfrom(socketServer, buffer, BUFFER_LENGTH, 0, 
		   (struct sockaddr *) &clientAddress, &socketLength) > 0){
			
			// Scan first int of buffer to identify client ID 
			// and second int of buffer to identify packet type
			sscanf(buffer, "%d %d %[^\n]", &receivedID, 
										   &receivedType, messageData);
			
			// For some reason server might read a false address
			if (strcmp(inet_ntoa(clientAddress.sin_addr),"0.0.0.0")!=0){
				// Add client to list if necessary
				if (!matchID(knownClients, receivedID)){
					d = createClient(clientAddress, receivedID, 
									 socketLength);
					knownClients = addClient(knownClients, d);
					nKnownClients++;
					newClientConnected = 1;
					printf("ID %d connected...\n", receivedID);
				} else {
					// Update the timeout of the client ID
					updateTimeout(knownClients, receivedID);
				}
				
				// PROCESSING PACKET (depending on receivedType)
				switch (receivedType){
					case MSG_LOGOUT:
						break; // Yet to implement
					case MSG_MOVEMENT:
						// Extract the info structured as:
						sscanf(messageData, "%d %d %d %d;", &x, &y, &dx,
															&dy);
						// If direction changed or new client connected
						if (updatePosition(knownClients, receivedID,
							x, y, dx, dy)!=0){
							// Write info to buffer			
							sprintf(buffer, "%d %d %d %d %d %d\n", 
									receivedID,	MSG_MOVEMENT, x, y, dx,
									dy);
							// Send buffer to all clients
							for(i=0;i<RETRANSMISSIONS;i++){
								for (d=knownClients;d!=NULL;d=d->next){
									j = sendto(socketServer, buffer, 
									BUFFER_LENGTH, 0, 
									(struct sockaddr *) d->address, 
									d->len);
									if (j < 0)
										error("SendTo Error");
								}
							}
						}
				}
				
				// Erase buffer
				memset(buffer, 0, BUFFER_LENGTH);
				
				// If a new client was connected, we ought to give 
				// everybody every info just to be sure
				// (could actually send to new client all info about
				// others and to others only infos about the new client)
				if (newClientConnected){
					for(d=knownClients;d!=NULL;d=d->next){
						sprintf(buffer, "%d %d %d %d %d %d\n", d->id,
									MSG_MOVEMENT, d->x, d->y, d->dx, 
									d->dy);
						for(dd=knownClients;dd!=NULL;dd=dd->next){
							for(i=0;i<RETRANSMISSIONS;i++){
								j = sendto(socketServer, buffer, 
									BUFFER_LENGTH, 0, 
									(struct sockaddr *) dd->address, 
									dd->len);
								if (j < 0)
									error("SendTo Error");
							}
						}
						// Erase buffer
						memset(buffer, 0, BUFFER_LENGTH);
					}
				}
			}
		}
	}
	close(socketServer);
    return 0;
}
