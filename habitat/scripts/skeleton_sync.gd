## skeleton_sync.gd
## Copies bone poses from a source Skeleton3D to a target Skeleton3D every frame.
## Attach to any node, then set the two skeleton paths in the Inspector.
## Use this to make an outfit's skeleton follow the main character skeleton.
extends Node

@export var source_skeleton: NodePath
@export var target_skeleton: NodePath

var _source: Skeleton3D
var _target: Skeleton3D

func _ready() -> void:
	_source = get_node_or_null(source_skeleton) as Skeleton3D
	_target = get_node_or_null(target_skeleton) as Skeleton3D
	if not _source:
		push_warning("SkeletonSync: source_skeleton not found at path: " + str(source_skeleton))
	if not _target:
		push_warning("SkeletonSync: target_skeleton not found at path: " + str(target_skeleton))

func _process(_delta: float) -> void:
	if not _source or not _target:
		return
	for i in _source.get_bone_count():
		var bone_name := _source.get_bone_name(i)
		var target_idx := _target.find_bone(bone_name)
		if target_idx >= 0:
			_target.set_bone_pose_position(target_idx, _source.get_bone_pose_position(i))
			_target.set_bone_pose_rotation(target_idx, _source.get_bone_pose_rotation(i))
			_target.set_bone_pose_scale(target_idx, _source.get_bone_pose_scale(i))
