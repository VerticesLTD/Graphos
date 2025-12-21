## Represents a vertex (node) in a graph.
## Stores adjacency information and algorithm metadata.
## This class is data-oriented and intentionally not a Node.
class_name Vertex
extends Object # A vertex is an object which means it has a brain without a body. Pure logic.

## Emitted when values like color or position change. 
## The Sprite hears this and repaints itself.
signal state_changed

## Emitted when this vertex is removed from the graph.
## The VertexView hears this and calls queue_free().
signal vanished

## Emitted when a new connection is made. 
## The Graph hears this and spawns a new Line (EdgeView).
signal edge_added(new_edge: Edge)

## Emitted when a connection is broken. 
## The Graph hears this and deletes the corresponding Line.
signal edge_removed(target_edge: Edge)

## Constant used to represent infinity in graph algorithms.
const INF: float = 1e18

## Unique identifier of the vertex.
var id: int

## Number of incident edges.
var degree: int = 0

## Head of the adjacency list (linked list of Edge).
var edges: Edge = null


## Constructs a new Vertex.
## @param _id        Unique vertex identifier.
## @param _color     Optional color.
## @param _distance  Initial distance value.
## @param _key       Initial key value.
## @param _x         Optional x-coordinate.
## @param _y         Optional y-coordinate.
func _init(
	_id: int,
	_color: Color = Color.WHITE,
	_distance: float = INF,
	_key: float = INF,
	_pos: Vector2 = Vector2.ZERO,
) -> void:
	self.id = _id
	self.color = _color
	self.distance = _distance
	self.key = _key
	self.pos = _pos

####################### SETTER FUNCTIONS & REACTION LOGIC #######################

## WHY SETTERS?
## We want to keep the "Brain" (this Vertex data) separate from the "Body" (the Sprite).
## In the old way, the Graph had to do all the work to redraw the whole screen. 
## Now, the Algorithm just updates these numbers, and the Vertex "shouts" when it changes.
##
## THE FLOW:
## 1. BFS says: "You are now Yellow." (`vertex.color = Color.YELLOW`)
## 2. The Setter (below) catches that change instantly.
## 3. It fires the `state_changed` signal.
## 4. The Sprite (the visual node) is listening for that shout.It, 
##    wakes up, and repaints itself without us having to call `queue_redraw()`.
##
## Thats great for undo/execute: 
## for example: if we put the old color back into this variable, the Sprite hears the change 
## and "reverts" its look automatically. No extra logic needed.

var color: Color = Color.WHITE: # defult color to our var is white,
	set(value): # called every time we change the color
		color = value # Change the color
		state_changed.emit() # emit the signal

var distance: float = INF:
	set(value):
		distance = value
		state_changed.emit()

var key: float = INF:
	set(value):
		key = value
		state_changed.emit()

var pos: Vector2 = Vector2.ZERO:
	set(value):
		pos = value
		state_changed.emit()
		
var parent: Vertex = null:
	set(value):
		parent = value
		state_changed.emit() # UI draws "Parent Arrow"
		
## Adds an outgoing edge from this vertex to the destination vertex.
## If an edge already exists, no modification is performed.
## @param dest   Destination vertex.
## @param weight Weight assigned to the edge.
func connect_vertices(dest: Vertex, weight: int = 1) -> void:
	## Check if the edge is already in the graph
	var curr: Edge = edges
	while curr:
		if curr.dst == dest:
			return
		curr = curr.next

	## Add the new  edge to the linked list
	var new_edge: Edge = Edge.new(weight, self, dest, edges)
	edges = new_edge
	degree += 1
	
	## Tell the Graph to create a visual line for this data
	edge_added.emit(new_edge)

## Removes the outgoing edge to the given destination vertex.
## @param dest  The vertex we are disconnecting from.
## @param shout If true, signals will be sent to update the UI/Algorithms. 
##              Set to false for the "second half" of undirected edge deletions.
## @return      True if an edge was found and removed, false otherwise.
func delete_edge(dest: Vertex, shout: bool = true) -> bool:
	var prev: Edge = null
	var curr: Edge = edges

	# Traverse the linked list of edges
	while curr:
		if curr.dst == dest:
			# If shouting is enabled, we notify the rest of the system
			if shout:
				## GLOBAL NOTIFICATION: Tells the Graph/Algorithms that the logic changed.
				edge_removed.emit(curr) 
				
				## DIRECT COMMAND: Tells the specific EdgeView (Line2D) to delete itself.
				## This triggers 'queue_free()' in the visual script.
				curr.vanished.emit()			
			
			# Re-link the list to bypass the current edge (Standard Linked List removal)
			if prev == null:
				# We are removing the head of the list
				edges = curr.next
			else:
				# We are removing a middle or tail element
				prev.next = curr.next

			# Update metadata
			degree -= 1
			return true

		# Move to the next link in the chain
		prev = curr
		curr = curr.next

	return false
## Returns all outgoing edges as an Array.
## NOTE:
## Godot does not support Array[Edge] typing.
func get_neighbors_edges() -> Array:
	var out: Array = []
	var e: Edge = edges
	while e:
		out.append(e)
		e = e.next
	return out

## Returns all vertices neighbors as an Array.
func get_neighbor_vertices() -> Array:
	var neighbors: Array = []
	var e: Edge = edges # The head of your linked list
	while e:
		neighbors.append(e.dst) # dst is the Vertex on the other side
		e = e.next
	return neighbors
