extends RefCounted
## Shared access to the imported third-party models. Scenes are loaded once and
## their meshes are handed to MultiMesh batches, so thousands of trees, lamps and
## benches stay a handful of draw calls. Models are CC0; see
## assets/thirdparty/SOURCES.md.

const TREES := ["res://assets/thirdparty/nature/mega_tree1.glb",
	"res://assets/thirdparty/nature/mega_tree2.glb",
	"res://assets/thirdparty/nature/mega_tree3.glb"]
const BUSHES := ["res://assets/thirdparty/nature/mega_bush1.glb",
	"res://assets/thirdparty/nature/mega_bush_with_flowers1.glb",
	"res://assets/thirdparty/nature/mega_fern1.glb"]
const GRASS := ["res://assets/thirdparty/nature/mega_grass1.glb",
	"res://assets/thirdparty/nature/mega_tall_grass1.glb",
	"res://assets/thirdparty/nature/mega_grass_wispy1.glb"]
const STREET_LIGHT := "res://assets/thirdparty/city/streetlight.glb"
const TRAFFIC_LIGHT := "res://assets/thirdparty/city/traffic_light.glb"
const BENCH := "res://assets/thirdparty/city/bench.glb"
const BIN := "res://assets/thirdparty/city/dumpster.glb"
const HYDRANT := "res://assets/thirdparty/city/fire_hydrant.glb"

static var _scenes: Dictionary = {}
static var _parts: Dictionary = {}
static var _sizes: Dictionary = {}


static func scene(path: String) -> PackedScene:
	if not _scenes.has(path): _scenes[path] = load(path)
	return _scenes[path]


## Every mesh in a model with its transform inside the model, so a prop made of
## several pieces still batches correctly.
static func parts(path: String) -> Array:
	if _parts.has(path): return _parts[path]
	var found: Array = []
	var packed: PackedScene = scene(path)
	if packed != null:
		var node: Node3D = packed.instantiate()
		var box := AABB()
		var first := true
		for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			var local := node.global_transform.affine_inverse() * mesh.global_transform if node.is_inside_tree() else _relative(node, mesh)
			found.append([mesh.mesh, local])
			var item: AABB = local * mesh.mesh.get_aabb()
			box = item if first else box.merge(item)
			first = false
		_sizes[path] = box.size
		node.free()
	_parts[path] = found
	return found


static func size(path: String) -> Vector3:
	if not _sizes.has(path): parts(path)
	return _sizes.get(path, Vector3.ONE)


## Transform of a child relative to the model root, without needing the tree.
static func _relative(root: Node3D, node: Node3D) -> Transform3D:
	var chain := Transform3D.IDENTITY
	var walk: Node = node
	while walk is Node3D and walk != root:
		chain = (walk as Node3D).transform * chain
		walk = walk.get_parent()
	return chain
