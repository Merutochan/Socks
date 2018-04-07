/* 

// Meru
// BASIC UDP GAME SERVER LIBRARY
// merutochan@gmail.com

*/

// Contains basic informations
// about a single client connected
typedef struct clientInfo {	
	struct sockaddr_in * address;
	socklen_t len;
	unsigned int id;
	time_t timeout;
	
	int x;
	int y;
	int dx;
	int dy;
	
	struct clientInfo *next;
	
} client_t;

// When removing a client, 
// yields updated list and ID
// of client removed.
struct clientRemoval{
	client_t *list;
	unsigned int removedID;
};

/* ================================================================== */

// matchID(list, c)

// Find out if an element of list has id c.
int matchID(client_t * list, unsigned int c){
	client_t * d;	
	if(!list)
		return 0;
	for (d=list;d!=NULL;d=d->next){
		if ((d->id)==c){
			return 1;
		}
	}
	return 0;
}

// createClient(c, i, l)

// Create a client with given address c, id i and socket length l.
// x, y, dx and dy are initialized as 0 but will be known very soon.
client_t * createClient(struct sockaddr_in c, unsigned int i,
						socklen_t l){
	client_t * d = malloc(sizeof(client_t));
	d->address = malloc(sizeof(struct sockaddr_in));
	memcpy(d->address, &c, sizeof(c));
	d->id = i;
	d->timeout = clock();
	d->len = l;
	d->x = 0;
	d->y = 0;
	d->dx = 0;
	d->dy = 0;
	d->next = NULL;
	return d;
}


// addClient(list, c)

// Adds c to list attaching it to the "next" pointer of last element.
client_t * addClient(client_t *list, client_t *c){
	client_t * d = list;
	if(!d){
		return c;
	}
	if(!(d->next)){
		d->next = c;
		return d;
	} else{
		d->next = addClient(d->next, c);
		return d;
	}
}

// removeClientByTimeout(list)

// Removes an element in the list of Clients if Timeout expires.
// Yields back a struct containing head of list with removed element
// and ID of element removed (so that clients can know who died).
struct clientRemoval * removeClientByTimeout(client_t * list){
	static struct clientRemoval *r = NULL;
	client_t *d = list;
	if(!list)
		return NULL;
	if ((clock() - d->timeout)/CLOCKS_PER_SEC > TIMEOUT_TIME){
		r=malloc(sizeof(struct clientRemoval *));
		// Set removed ID
		r->removedID = d->id;
		// Set next as list return
		r->list = d->next;
		// We can free the node!
		free(d);
		return r;
	}else{
		r = removeClientByTimeout(d->next);
		// Update d->next to eventually remove
		if(r){
			d->next = r->list;
			// Set current as list return
			r->list = d;}
		return r;
	}
}

// updateTimeout(list, id)

// Updates timeout value of the element of list with given id.
void updateTimeout(client_t *list, unsigned int id){
	if(!list)
		return;
	if(list->id==id){
		list->timeout=clock();
		return;
	} else {
		updateTimeout(list->next, id);
	}
}

// updatePosition(list, id, x, y, dx, dy)

// Updates position (and movement) of element of list with given id.
// If the movement changes (e.g. if goes from still to moving up or if
// goes from moving up to moving left) returns 1, else 0.
int updatePosition(client_t *list, unsigned int id, int x, int y, 
					int dx, int dy){
	int result;
	if(!list)
		return 0;
	if(list->id==id){
		list->x=x;
		list->y=y;
		result = (list->dx != dx || list->dy != dy);
		list->dx = dx;
		list->dy = dy;
		return (result);
	} else {
		return updatePosition(list->next, id, x, y, dx, dy);
	}
	return 0;
}
