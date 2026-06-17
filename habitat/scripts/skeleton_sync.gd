## skeleton_sync.gd
## Copies bone poses from a source Skeleton3D to a target Skeleton3D every frame.
## Attach to any node, then set the two skeleton paths in the Inspector.
## Use this to make an outfit's skeleton follow the main character skeleton.
extends Node

@export var source_skeleton: NodePath
@export var target_skeleton: NodePath

var _source: Skeleton3D
var _target: Skeleton3D
# Pre-built map: source bone index → target bone index (-1 = no match)
var _bone_map: PackedInt32Array

func _ready() -> void:
	_source = get_node_or_null(source_skeleton) as Skeleton3D
	_target = get_node_or_null(target_skeleton) as Skeleton3D
	if not _source:
		push_warning("SkeletonSync: source_skeleton not found at path: " + str(source_skeleton))
		return
	if not _target:
		push_warning("SkeletonSync: target_skeleton not found at path: " + str(target_skeleton))
		return
	# Build index map once — O(n) instead of O(n²) per frame
	_bone_map.resize(_source.get_bone_count())
	for i in _source.get_bone_count():
		_bone_map[i] = _target.find_bone(_source.get_bone_name(i))

func _process(_delta: float) -> void:
	if not _source or not _target or _bone_map.is_empty():
		return
	for i in _source.get_bone_count():
		var ti: int = _bone_map[i]
		if ti >= 0:
			_target.set_bone_pose_position(ti, _source.get_bone_pose_position(i))
			_target.set_bone_pose_rotation(ti, _source.get_bone_pose_rotation(i))
			_target.set_bone_pose_scale(ti, _source.get_bone_pose_scale(i))
