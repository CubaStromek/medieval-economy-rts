#!/usr/bin/env python3
"""Read-only GLB import audit and four studio views, run inside Blender.

Blender --background --python qa_lumberjack_static.py -- /path/model.glb
Outputs default to qa/run-<UTC timestamp>; the source file is never saved over.
Only imported data are audited. Cameras/lights/world are separate QA staging.
No mesh editing, remeshing, UV changes, material replacement, or re-export occurs.
"""

import argparse
import hashlib
import json
import math
import struct
import sys
from datetime import datetime, timezone
from pathlib import Path

import bpy
from mathutils import Vector


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def glb_inventory(path):
    """Read the original GLB JSON/BIN layout without extracting or altering maps."""
    with path.open("rb") as handle:
        header = handle.read(12)
        if len(header) != 12:
            raise ValueError("Truncated GLB header")
        magic, version, declared_length = struct.unpack("<4sII", header)
        if magic != b"glTF" or version != 2:
            raise ValueError("Expected a glTF 2 binary GLB")
        if declared_length != path.stat().st_size:
            raise ValueError("GLB declared length differs from actual file length")
        document = None
        chunks = []
        while handle.tell() < declared_length:
            length, kind = struct.unpack("<I4s", handle.read(8))
            offset = handle.tell()
            if offset + length > declared_length:
                raise ValueError("GLB chunk exceeds file length")
            chunks.append({"type": kind.decode("ascii", errors="replace"), "bytes": length})
            if kind == b"JSON":
                document = json.loads(handle.read(length).rstrip(b" \x00"))
            else:
                handle.seek(length, 1)
    if document is None:
        raise ValueError("GLB has no JSON chunk")

    images = []
    for index, entry in enumerate(document.get("images", [])):
        uri = entry.get("uri", "")
        embedded = "bufferView" in entry or uri.startswith("data:")
        item = {"index": index, "name": entry.get("name"), "mime_type": entry.get("mimeType"),
                "storage": "bufferView" if "bufferView" in entry else "data URI" if uri.startswith("data:") else "external URI",
                "embedded": embedded}
        if "bufferView" in entry:
            view = document.get("bufferViews", [])[entry["bufferView"]]
            item.update(buffer_view=entry["bufferView"], compressed_image_bytes=view.get("byteLength"))
        elif uri and not uri.startswith("data:"):
            item.update(uri=uri, external_file_exists=(path.parent / uri).is_file())
        images.append(item)

    textures = []
    for index, entry in enumerate(document.get("textures", [])):
        sources = []
        if "source" in entry:
            sources.append({"image": entry["source"], "route": "source"})
        for extension, settings in entry.get("extensions", {}).items():
            if isinstance(settings, dict) and "source" in settings:
                sources.append({"image": settings["source"], "route": extension})
        textures.append({"index": index, "name": entry.get("name"), "sources": sources,
                         "sampler": entry.get("sampler")})

    def texture_maps(value, trail=""):
        found = []
        if not isinstance(value, dict):
            return found
        for key, item in value.items():
            location = f"{trail}.{key}".strip(".")
            if isinstance(item, dict):
                if key.lower().endswith("texture") and "index" in item:
                    texture_index = item["index"]
                    found.append({"map": location, "texture": texture_index,
                                  "images": textures[texture_index]["sources"] if texture_index < len(textures) else [],
                                  "texcoord": item.get("texCoord", 0), "scale": item.get("scale"),
                                  "strength": item.get("strength")})
                found.extend(texture_maps(item, location))
        return found

    materials = []
    for index, entry in enumerate(document.get("materials", [])):
        pbr = entry.get("pbrMetallicRoughness", {})
        materials.append({"index": index, "name": entry.get("name"), "maps": texture_maps(entry),
                          "base_color_factor": pbr.get("baseColorFactor", [1, 1, 1, 1]),
                          "roughness_factor": pbr.get("roughnessFactor", 1),
                          "metallic_factor": pbr.get("metallicFactor", 1),
                          "alpha_mode": entry.get("alphaMode", "OPAQUE"),
                          "double_sided": entry.get("doubleSided", False),
                          "extensions": list(entry.get("extensions", {}))})
    accessors = document.get("accessors", [])
    meshes = []
    for index, entry in enumerate(document.get("meshes", [])):
        primitives = []
        for primitive in entry.get("primitives", []):
            attributes = primitive.get("attributes", {})
            primitives.append({"mode": primitive.get("mode", 4), "material": primitive.get("material"),
                               "attributes": list(attributes),
                               "vertices": accessors[attributes["POSITION"]].get("count") if "POSITION" in attributes else None,
                               "indices": accessors[primitive["indices"]].get("count") if "indices" in primitive else None,
                               "morph_targets": len(primitive.get("targets", []))})
        meshes.append({"index": index, "name": entry.get("name"), "primitives": primitives})
    skins = [{"name": entry.get("name"), "joint_count": len(entry.get("joints", [])),
              "skeleton_node": entry.get("skeleton")} for entry in document.get("skins", [])]
    animations = [{"name": entry.get("name"), "channel_count": len(entry.get("channels", []))}
                  for entry in document.get("animations", [])]
    return {"version": version, "file_bytes": declared_length, "chunks": chunks,
            "generator": document.get("asset", {}).get("generator"),
            "extensions_used": document.get("extensionsUsed", []),
            "extensions_required": document.get("extensionsRequired", []),
            "images": images, "textures": textures, "materials": materials, "meshes": meshes,
            "skins": skins, "animations": animations, "node_count": len(document.get("nodes", []))}


def inspect_node_tree(tree, prefix="", ancestors=()):
    if tree is None or tree.as_pointer() in ancestors:
        return [], []
    ancestors = (*ancestors, tree.as_pointer())
    image_nodes, links = [], []
    for link in tree.links:
        links.append({"from": f"{prefix}{link.from_node.name}.{link.from_socket.name}",
                      "to": f"{prefix}{link.to_node.name}.{link.to_socket.name}"})
    for node in tree.nodes:
        if node.type == "TEX_IMAGE":
            image_nodes.append({"node": f"{prefix}{node.name}",
                                "image": node.image.name if node.image else None,
                                "interpolation": node.interpolation, "projection": node.projection,
                                "extension": node.extension,
                                "linked_outputs": [socket.name for socket in node.outputs if socket.is_linked]})
        if node.type == "GROUP" and node.node_tree:
            nested_images, nested_links = inspect_node_tree(node.node_tree, f"{prefix}{node.name}/", ancestors)
            image_nodes.extend(nested_images)
            links.extend(nested_links)
    return image_nodes, links


def blender_inventory(imported_objects):
    meshes, armatures = [], []
    material_set = set()
    for obj in imported_objects:
        if obj.type == "MESH":
            mesh = obj.data
            material_set.update(slot.material for slot in obj.material_slots if slot.material)
            meshes.append({"object": obj.name, "data": mesh.name, "vertices": len(mesh.vertices),
                           "polygons": len(mesh.polygons),
                           "triangles": sum(max(0, polygon.loop_total - 2) for polygon in mesh.polygons),
                           "uv_layers": [{"name": uv.name, "loops": len(uv.data)} for uv in mesh.uv_layers],
                           "materials": [slot.material.name if slot.material else None for slot in obj.material_slots],
                           "vertex_groups": [group.name for group in obj.vertex_groups],
                           "shape_keys": [key.name for key in mesh.shape_keys.key_blocks] if mesh.shape_keys else [],
                           "modifiers": [{"name": modifier.name, "type": modifier.type,
                                          "armature": modifier.object.name if modifier.type == "ARMATURE" and modifier.object else None}
                                         for modifier in obj.modifiers],
                           "matrix_world": [list(row) for row in obj.matrix_world]})
        elif obj.type == "ARMATURE":
            armatures.append({"object": obj.name, "bone_count": len(obj.data.bones),
                              "bones": [{"name": bone.name, "parent": bone.parent.name if bone.parent else None,
                                         "deform": bone.use_deform} for bone in obj.data.bones]})
    materials = []
    for material in sorted(material_set, key=lambda item: item.name):
        image_nodes, links = inspect_node_tree(material.node_tree)
        materials.append({"name": material.name, "use_nodes": material.use_nodes,
                          "image_nodes": image_nodes, "node_links": links})
    images = []
    for image in bpy.data.images:
        if image.type in {"RENDER_RESULT", "COMPOSITING"}:
            continue
        packed = bool(image.packed_file) or bool(image.packed_files)
        path = bpy.path.abspath(image.filepath) if image.filepath else None
        images.append({"name": image.name, "source": image.source, "size": list(image.size),
                       "channels": image.channels, "depth": image.depth, "has_data": image.has_data,
                       "colorspace": image.colorspace_settings.name, "alpha_mode": image.alpha_mode,
                       "packed": packed, "packed_files": len(image.packed_files),
                       "filepath": image.filepath, "external_file_exists": Path(path).is_file() if path else None})
    return {"blender_version": bpy.app.version_string, "object_count": len(imported_objects),
            "meshes": meshes, "materials": materials, "images": images, "armatures": armatures,
            "actions": [{"name": action.name, "frame_range": list(action.frame_range)} for action in bpy.data.actions]}


def add_area(collection, name, target, span, offset, energy, size):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.shape = "DISK"
    data.size = span * size
    obj = bpy.data.objects.new(name, data)
    collection.objects.link(obj)
    obj.location = target + Vector(offset) * span
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()
    return obj


def render_views(mesh_objects, outdir, args):
    scene = bpy.context.scene
    bpy.context.view_layer.update()
    corners = [obj.matrix_world @ Vector(point) for obj in mesh_objects for point in obj.bound_box]
    minimum = Vector(tuple(min(point[axis] for point in corners) for axis in range(3)))
    maximum = Vector(tuple(max(point[axis] for point in corners) for axis in range(3)))
    center = (minimum + maximum) / 2
    dimensions = maximum - minimum
    span = max(dimensions)
    if not math.isfinite(span) or span <= 0:
        raise ValueError("Imported mesh has invalid bounds")
    collection = bpy.data.collections.new("QA staging — cameras and lights only")
    scene.collection.children.link(collection)
    world = bpy.data.worlds.new("QA neutral studio")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.32, 0.32, 0.32, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
    scene.world = world
    # Energy scales with area; the original mesh's size and transforms remain intact.
    power = (span / 2) ** 2
    add_area(collection, "QA large key", center, span, (-1.2, -1.5, 1.6), 900 * power, 1.7)
    add_area(collection, "QA fill", center, span, (1.4, -0.4, 0.7), 450 * power, 1.9)
    add_area(collection, "QA rear fill", center, span, (0.0, 1.4, 1.0), 700 * power, 1.7)
    camera_data = bpy.data.cameras.new("QA orthographic camera")
    camera_data.type = "ORTHO"
    camera_data.clip_start = max(span / 10000, 0.00001)
    camera_data.clip_end = span * 100
    camera = bpy.data.objects.new("QA orthographic camera", camera_data)
    collection.objects.link(camera)
    scene.camera = camera
    angles = {"-Y": 0, "+X": 90, "+Y": 180, "-X": 270}
    yaw = math.radians(angles[args.front_axis])
    elevation = math.radians(args.elevation)
    views = [("front", 0), ("threequarter", 45), ("back", 180), ("side", 90)]
    settings = []
    largest_extent = 0.0
    for label, offset in views:
        angle = yaw + math.radians(offset)
        direction = Vector((math.sin(angle) * math.cos(elevation),
                            -math.cos(angle) * math.cos(elevation), math.sin(elevation)))
        location = center + direction * span * 4
        rotation = (center - location).to_track_quat("-Z", "Y")
        inverse = rotation.inverted()
        projected = [inverse @ (point - center) for point in corners]
        extent = max(max(point[axis] for point in projected) - min(point[axis] for point in projected) for axis in (0, 1))
        largest_extent = max(largest_extent, extent)
        settings.append((label, location, rotation))
    camera_data.ortho_scale = largest_extent * 1.18
    if args.cycles:
        scene.render.engine = "CYCLES"
    else:
        try:
            scene.render.engine = "BLENDER_EEVEE_NEXT"
        except TypeError:
            scene.render.engine = "CYCLES"
    if scene.render.engine == "CYCLES":
        scene.cycles.samples = 32
        scene.cycles.use_denoising = True
    scene.render.resolution_x = args.resolution
    scene.render.resolution_y = args.resolution
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.exposure = 0
    scene.view_settings.gamma = 1
    rendered = []
    for label, location, rotation in settings:
        camera.location = location
        camera.rotation_euler = rotation.to_euler()
        scene.render.filepath = str(outdir / f"{label}.png")
        bpy.ops.render.render(write_still=True)
        rendered.append({"view": label, "file": f"{label}.png", "camera_location": list(location),
                         "camera_rotation": list(camera.rotation_euler), "ortho_scale": camera_data.ortho_scale})
    if args.save_scene:
        bpy.ops.wm.save_as_mainfile(filepath=str(outdir / "qa-scene.blend"))
    return {"minimum": list(minimum), "maximum": list(maximum), "dimensions": list(dimensions),
            "front_axis_assumption": args.front_axis, "elevation_degrees": args.elevation,
            "axis_note": "Front is a declared camera assumption, not automatic semantic front detection. Inspect face/apron and rerun with --front-axis if needed.",
            "engine": scene.render.engine, "views": rendered}


def write_summary(report, outdir):
    imported = report.get("blender", {})
    lines = ["# Static lumberjack — Blender QA", "", f"Source: `{report['source']['path']}`",
             f"SHA256: `{report['source']['sha256']}`", "",
             "This is a static model audit. No rig, walk cycle, engine integration, or approval is claimed.", "",
             f"- Mesh objects: {len(imported.get('meshes', []))}",
             f"- Vertices: {sum(mesh['vertices'] for mesh in imported.get('meshes', [])):,}",
             f"- Triangles: {sum(mesh['triangles'] for mesh in imported.get('meshes', [])):,}",
             f"- Materials: {len(imported.get('materials', []))}",
             f"- Imported images: {len(imported.get('images', []))}",
             f"- Armatures: {len(imported.get('armatures', []))}",
             f"- Source skins: {len(report['glb']['skins'])}",
             f"- Source animations: {len(report['glb']['animations'])}", "", "## Texture maps", ""]
    for material in report["glb"]["materials"]:
        lines.append(f"- {material['name'] or material['index']}: " + (", ".join(item["map"] for item in material["maps"]) or "no texture maps"))
    lines += ["", "## Observations requiring visual review", "",
              "Check identity, face, fingertips, separate legs, front-only apron, rear tunic, cap silhouette, empty hands, and texture seams.",
              "Imported material nodes and image color spaces are listed in audit.json; no material maps were replaced or discarded.", ""]
    lines += [f"- {warning}" for warning in report.get("warnings", [])]
    if report.get("renders"):
        lines += ["", f"Camera front assumption: {report['renders']['front_axis_assumption']}; elevation {report['renders']['elevation_degrees']}°.", ""]
        for view in report["renders"]["views"]:
            lines += [f"### {view['view']}", "", f"![{view['view']}]({view['file']})", ""]
    lines += ["", f"Source unchanged: {report.get('source_unchanged', 'not yet verified')}",
              f"Status: {report['status']}", ""]
    (outdir / "README.md").write_text("\n".join(lines), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("--outdir", type=Path)
    parser.add_argument("--front-axis", choices=("-Y", "+Y", "-X", "+X"), default="-Y")
    parser.add_argument("--elevation", type=float, default=6.0)
    parser.add_argument("--resolution", type=int, default=1024)
    parser.add_argument("--cycles", action="store_true", help="Use Cycles instead of Eevee")
    parser.add_argument("--audit-only", action="store_true")
    parser.add_argument("--save-scene", action="store_true", help="Save a separate staged QA Blend, never the GLB")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    source = args.input.expanduser().resolve(strict=True)
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    outdir = (args.outdir or Path(__file__).resolve().parent / "qa" / f"run-{timestamp}").resolve()
    outdir.mkdir(parents=True, exist_ok=True)
    if any((outdir / name).exists() for name in ("audit.json", "front.png", "threequarter.png", "back.png", "side.png")):
        raise FileExistsError(f"QA output already exists; choose a fresh --outdir: {outdir}")
    report = {"date_utc": datetime.now(timezone.utc).isoformat(), "status": "importing",
              "source": {"path": str(source), "sha256": sha256(source)},
              "scope": "Static source inspection only; source geometry, UVs, original textures and materials are not edited.",
              "glb": glb_inventory(source), "warnings": []}
    report_path = outdir / "audit.json"
    try:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(source))
        imported_objects = list(bpy.context.scene.objects)
        report["blender"] = blender_inventory(imported_objects)
        mesh_objects = [obj for obj in imported_objects if obj.type == "MESH"]
        if not mesh_objects:
            raise ValueError("No mesh objects imported")
        for image in report["blender"]["images"]:
            if not image["has_data"] or 0 in image["size"]:
                report["warnings"].append(f"Image has no loaded pixel data: {image['name']}")
        for material in report["blender"]["materials"]:
            if not material["image_nodes"]:
                report["warnings"].append(f"Material has no image texture nodes: {material['name']}")
        for image in report["glb"]["images"]:
            if not image["embedded"] and not image.get("external_file_exists", False):
                report["warnings"].append(f"Source image {image['index']} is external and missing")
        for mesh in report["blender"]["meshes"]:
            if not mesh["uv_layers"]:
                report["warnings"].append(f"Mesh has no UV layer: {mesh['object']}")
        if not report["blender"]["armatures"]:
            report["warnings"].append("No armature: expected for this requested static T-pose; this model is not yet rigged.")
        report["status"] = "audit complete; rendering pending"
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
        if not args.audit_only:
            report["renders"] = render_views(mesh_objects, outdir, args)
        report["source_unchanged"] = sha256(source) == report["source"]["sha256"]
        report["status"] = "audit complete; visual review required"
        if not report["source_unchanged"]:
            raise RuntimeError("Source hash changed during QA")
    except Exception as error:
        report["status"] = "QA failed"
        report["error"] = f"{type(error).__name__}: {error}"
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
        write_summary(report, outdir)
        raise
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    write_summary(report, outdir)
    print(f"LUMBERJACK_QA_READY {outdir}")


if __name__ == "__main__":
    main()
