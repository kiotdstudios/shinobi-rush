class_name ArenaSort
extends RefCounted
## Draw-order rule for the arena's boxes (PLACEHOLDER blocks), shared by production and tests.
##
## The arena y-sorts its children: a node with a larger global y draws later (in front); equal keys draw in tree order.
## A block is drawn in the three-quarter view (receding axis up-right, visible faces: front, east, top), so one sort
## key cannot be right for the whole box. Each block is therefore two sibling sort pieces:
##   Block     (position = bottom-centre of the front edge, key = pos.y)        draws the front face
##   BlockRear (position = pos - (0, depth), key = pos.y - depth)               draws the east face and the roof
## An actor (feet = its node position) is drawn OVER a piece iff its feet y is greater than the piece's key:
##   south of the front edge        -> over both pieces
##   within the block's depth range -> over the east face and roof, behind the front face
##                                     (east of the block: the east face is behind the actor; west: nothing overlaps)
##   north of the back edge         -> behind both pieces (the actor is hidden by the box, as it should be)
## Godot 4.7 has no per-node y-sort origin, so the keys are the node positions themselves.


## Sort key of the front piece for a block whose front-edge bottom-centre is `pos`.
static func front_key(pos: Vector2) -> float:
	return pos.y


## Sort key of the rear piece (east face and roof). `footprint` is (width, depth).
static func rear_key(pos: Vector2, footprint: Vector2) -> float:
	return pos.y - footprint.y


## Node position of the rear piece; the same code places the node and defines its key.
static func rear_position(pos: Vector2, footprint: Vector2) -> Vector2:
	return pos - Vector2(0.0, footprint.y)


## True if an actor with the given feet y is drawn after (over) a piece with this sort key.
static func actor_over(feet_y: float, key: float) -> bool:
	return feet_y > key


## Is the actor drawn over the front face of the block at `pos`?
static func actor_over_front(feet: Vector2, pos: Vector2) -> bool:
	return actor_over(feet.y, front_key(pos))


## Is the actor drawn over the east face and roof of the block at `pos` with `footprint`?
static func actor_over_rear(feet: Vector2, pos: Vector2, footprint: Vector2) -> bool:
	return actor_over(feet.y, rear_key(pos, footprint))
