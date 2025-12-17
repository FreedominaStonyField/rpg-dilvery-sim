extends SceneTree

func _init():
    run()
    quit()

func run():
    var models_dir = "res://assets/models/retro-urban-kit/GLB format"
    var materials_dir = "res://assets/materials/retro-urban-kit"
    var output_scene_dir = "res://scenes/world/generated_models"
    
    var texture_map = {
        "asphalt": "res://assets/textures/retro-urban-kit/asphalt.png",
        "bars": "res://assets/textures/retro-urban-kit/bars.png",
        "concrete": "res://assets/textures/retro-urban-kit/concrete.png",
        "dirt": "res://assets/textures/retro-urban-kit/dirt.png",
        "door": "res://assets/textures/retro-urban-kit/doors.png",
        "grass": "res://assets/textures/retro-urban-kit/grass.png",
        "metal_wall": "res://assets/textures/retro-urban-kit/metal_wall.png",
        "metal": "res://assets/textures/retro-urban-kit/metal.png",
        "planks": "res://assets/textures/retro-urban-kit/planks.png",
        "rock": "res://assets/textures/retro-urban-kit/rock.png",
        "roof_plates": "res://assets/textures/retro-urban-kit/roof_plates.png",
        "roof": "res://assets/textures/retro-urban-kit/roof.png",
        "signs": "res://assets/textures/retro-urban-kit/signs.png",
        "tiles": "res://assets/textures/retro-urban-kit/tiles.png",
        "treeA": "res://assets/textures/retro-urban-kit/treeA.png",
        "treeB": "res://assets/textures/retro-urban-kit/treeB.png",
        "truck_alien": "res://assets/textures/retro-urban-kit/truck_alien.png",
        "truck": "res://assets/textures/retro-urban-kit/truck.png",
        "wall_garage": "res://assets/textures/retro-urban-kit/wall_garage.png",
        "wall_lines": "res://assets/textures/retro-urban-kit/wall_lines.png",
        "wall": "res://assets/textures/retro-urban-kit/wall.png",
        "windows": "res://assets/textures/retro-urban-kit/windows.png"
    }

    # Ensure output directories exist
    DirAccess.make_dir_recursive_absolute(output_scene_dir)

    var dir = DirAccess.open(models_dir)
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if file_name.ends_with(".glb"):
                var model_path = models_dir.path_join(file_name)
                var model_name = file_name.get_basename()
                var material = null

                # Find material from mapping
                for key in texture_map.keys():
                    if model_name.contains(key):
                        var texture_path = texture_map[key]
                        var material_path = materials_dir.path_join(key + ".tres")

                        # Reuse material if it exists
                        if ResourceLoader.exists(material_path):
                            material = ResourceLoader.load(material_path)
                        else:
                            # Create and save new material
                            var new_material = StandardMaterial3D.new()
                            var texture = ResourceLoader.load(texture_path)
                            if texture:
                                new_material.albedo_texture = texture
                                print("creating material: " + material_path)
                                ResourceSaver.save(new_material, material_path)
                                material = new_material
                            else:
                                print("Error loading texture: " + texture_path)
                        break
                
                if material:
                    var imported_scene = ResourceLoader.load(model_path, "PackedScene")
                    if imported_scene:
                        var instance = imported_scene.instantiate()
                        
                        apply_material_to_meshes(instance, material)
                        
                        var packed_scene = PackedScene.new()
                        var result = packed_scene.pack(instance)
                        if result == OK:
                            var scene_path = output_scene_dir.path_join(model_name + ".tscn")
                            ResourceSaver.save(packed_scene, scene_path)
                            print("Processed " + model_name + " and saved to " + scene_path)
                        else:
                            print("Error packing scene for " + model_name)
                    else:
                        print("Error loading scene: " + model_path)
                else:
                    print("No material found for: " + model_name)


            file_name = dir.get_next()
    else:
        print("An error occurred when trying to access the path: " + models_dir)


func apply_material_to_meshes(node, material):
    if node is MeshInstance3D and node.mesh:
        for i in range(node.mesh.get_surface_count()):
             node.set_surface_override_material(i, material)

    for child in node.get_children():
        apply_material_to_meshes(child, material)
