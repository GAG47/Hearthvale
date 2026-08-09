class_name ChestState
extends WorldObjectState

enum Status {
	CLOSED,
	OPEN,
}

var status: Status


func _init(initial_status: Status = Status.CLOSED) -> void:
	status = initial_status
