"""Blender 4.5.3: build the licensed vehicle, mesh-local reveal, and exports.
Run via Blender MCP execute_blender_code or Blender --background --python.
Input is pinned in assets/source/provenance.json. Does not touch other modules.
"""
import bpy, math, json, sys
from pathlib import Path
from mathutils import Vector, Matrix

ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/'assets'
sys.path.insert(0,str(ROOT/'tools'))
from surface_field import surface_distances
if bpy.app.background:
 bpy.ops.wm.read_factory_settings(use_empty=True)
else:
 # This is the isolated MCP authoring session started for this task.
 for obj in list(bpy.data.objects):bpy.data.objects.remove(obj,do_unlink=True)
 for collection in (bpy.data.meshes,bpy.data.materials,bpy.data.cameras,bpy.data.lights):
  for data in list(collection):
   if data.users==0:collection.remove(data)
bpy.ops.import_scene.gltf(filepath=str(ASSETS/'source/crown-ccby.glb'))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
# Flatten source hierarchy while preserving coordinates. The import is in metres,
# with front = -Y, vehicle left = +X, up = +Z in Blender.
for o in meshes:
    m=o.matrix_world.copy();o.parent=None;o.data=o.data.copy()
    o.data.transform(m);o.matrix_world=Matrix.Identity(4)
for o in list(bpy.context.scene.objects):
    if o.type!='MESH': bpy.data.objects.remove(o,do_unlink=True)
root=bpy.data.objects.new('NextMove_Crown',None);bpy.context.collection.objects.link(root)
root['assetRevision']='crown-reveal-2.0';root['attribution']='Toyota Crown athlete s210 — Black Snow — CC BY 4.0'
root['source']='https://sketchfab.com/3d-models/138a753d04dd4d8f8982d8f5583d212d'
root['license']='https://creativecommons.org/licenses/by/4.0/'
for o in meshes: o.parent=root

# Studio lit graphite neutral, deep-blue clearcoat, real trim/glass differentiation.
def simple(name,color,metal=.0,rough=.35,coat=.0):
 m=bpy.data.materials.new(name);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough;p.inputs['Coat Weight'].default_value=coat
 return m
blue=(.018,.075,.34,1);neutral=(.14,.16,.19,1)
bodymat=simple('Body | evidence-controlled deep blue',blue[:3],.50,.27,.38)
n=bodymat.node_tree.nodes;l=bodymat.node_tree.links;p=n.get('Principled BSDF')
uv=n.new('ShaderNodeUVMap');uv.uv_map='InspectionReveal'
sep=n.new('ShaderNodeSeparateXYZ');l.new(uv.outputs['UV'],sep.inputs[0])
radius=n.new('ShaderNodeValue');radius.name='Evidence growth';radius.outputs[0].default_value=0
# Feathered edge in surface-distance space, not a sphere or screen-space mask.
sub=n.new('ShaderNodeMath');sub.operation='SUBTRACT';l.new(radius.outputs[0],sub.inputs[0]);l.new(sep.outputs['X'],sub.inputs[1])
noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=65;noise.inputs['Detail'].default_value=2;noise.inputs['Roughness'].default_value=.68
tex=n.new('ShaderNodeTexCoord');l.new(tex.outputs['Object'],noise.inputs['Vector']);tex.object=root
warp=n.new('ShaderNodeMath');warp.operation='MULTIPLY_ADD';l.new(noise.outputs['Fac'],warp.inputs[0]);warp.inputs[1].default_value=.055;warp.inputs[2].default_value=-.0275
add=n.new('ShaderNodeMath');add.operation='ADD';l.new(sub.outputs[0],add.inputs[0]);l.new(warp.outputs[0],add.inputs[1])
ramp=n.new('ShaderNodeMapRange');ramp.interpolation_type='SMOOTHERSTEP';ramp.clamp=True;ramp.inputs['From Min'].default_value=-.06;ramp.inputs['From Max'].default_value=.09;l.new(add.outputs[0],ramp.inputs['Value'])
mask=n.new('ShaderNodeMath');mask.operation='MULTIPLY';l.new(ramp.outputs['Result'],mask.inputs[0]);l.new(sep.outputs['Y'],mask.inputs[1])
beauty=n.new('ShaderNodeValue');beauty.name='Asset beauty only';beauty.outputs[0].default_value=0
maxmask=n.new('ShaderNodeMath');maxmask.operation='MAXIMUM';l.new(mask.outputs[0],maxmask.inputs[0]);l.new(beauty.outputs[0],maxmask.inputs[1])
mix=n.new('ShaderNodeMixRGB');mix.blend_type='MIX';mix.inputs[1].default_value=neutral;mix.inputs[2].default_value=blue;l.new(maxmask.outputs[0],mix.inputs[0]);l.new(mix.outputs[0],p.inputs['Base Color'])
# The mask also restores clearcoat and metallic response, so pigment feels embedded.
metal=n.new('ShaderNodeMapRange');metal.inputs['To Min'].default_value=.10;metal.inputs['To Max'].default_value=.50;l.new(maxmask.outputs[0],metal.inputs['Value']);l.new(metal.outputs['Result'],p.inputs['Metallic'])
rough=n.new('ShaderNodeMapRange');rough.inputs['To Min'].default_value=.43;rough.inputs['To Max'].default_value=.27;l.new(maxmask.outputs[0],rough.inputs['Value']);l.new(rough.outputs['Result'],p.inputs['Roughness'])

# Compute shortest paths over welded surface edges, avoiding UV-seam discontinuities.
# Disconnected components receive NO reveal. Only author-selected exterior surfaces
# have permission. This illustrative scenario grants front + left-side evidence;
# roof, far side, rear and interiors remain neutral, regardless of growth radius.
def distance_field(obj,seed,eligible):
 vs=[tuple(v.co) for v in obj.data.vertices]
 return surface_distances(vs,[tuple(e.vertices) for e in obj.data.edges],seed,[eligible(Vector(v)) for v in vs])

fields=[]
for o in meshes:
 names=[m.name for m in o.data.materials if m]
 if 's210_body' in names:
  o.data.materials.clear();o.data.materials.append(bodymat)
  # Per-surface permission is authored for this demonstration, never inferred.
  nm=o.name
  if 'hood' in nm: seed=(.45,-1.55,.89);eligible=lambda v:True;region='front'
  elif 'door_FL_' in nm:seed=(.89,-.35,.72);eligible=lambda v:True;region='left'
  elif 'door_RL_' in nm:seed=(.89,.68,.72);eligible=lambda v:True;region='left'
  elif 'fender' in nm and '_L' in nm:seed=(.85,-1.4,.8);eligible=lambda v:True;region='front-left'
  elif 'bumper_F' in nm:seed=(.60,-2.12,.60);eligible=lambda v:v.x>-.20;region='front'
  elif 'body_s210_body' in nm:seed=(.85,-1.05,.75);eligible=lambda v:v.x>.55 and v.z<1.08 and v.y<1.45;region='left'
  else:seed=(0,0,0);eligible=lambda v:False;region=None
  dist=distance_field(o,seed,eligible)
  layer=o.data.uv_layers.new(name='InspectionReveal')
  for loop in o.data.loops:
   d=dist[loop.vertex_index]; layer.data[loop.index].uv=(min(d/2.8,1) if math.isfinite(d) else 1,1 if math.isfinite(d) else 0)
  o['revealUV']='InspectionReveal';o['revealUVChannel']=len(o.data.uv_layers)-1;o['revealDomain']='mesh-edge-geodesic';o['coverageRegion']=region or 'unseen';o['evidenceGate']='permission mask must be replaced by live accepted evidence'
  fields.append({'mesh':o.name,'regionId':region,'reachableVertices':sum(math.isfinite(d) for d in dist),'vertices':len(dist),'uvChannel':len(o.data.uv_layers)-1})
 else:
  # retain fine original texture maps but improve the principal exterior materials
  for m in o.data.materials:
   if not m or not m.use_nodes:continue
   bs=m.node_tree.nodes.get('Principled BSDF')
   if not bs:continue
   if m.name in ['s210_glass','s210_glass_int','s210_lights_glass']:
    bs.inputs['Base Color'].default_value=(.018,.023,.029,1);bs.inputs['Metallic'].default_value=.32;bs.inputs['Roughness'].default_value=.15;bs.inputs['Transmission Weight'].default_value=0;bs.inputs['Alpha'].default_value=1
   if 'wheel_42a' in m.name or m.name=='etk_wheel_03a':bs.inputs['Metallic'].default_value=.88;bs.inputs['Roughness'].default_value=.25
   if 'Scene_-_Root' in m.name:bs.inputs['Base Color'].default_value=(.018,.020,.022,1);bs.inputs['Roughness'].default_value=.72;bs.inputs['Metallic'].default_value=0
   if m.name=='s210_headlight':bs.inputs['Base Color'].default_value=(.30,.34,.38,1);bs.inputs['Metallic'].default_value=.8;bs.inputs['Roughness'].default_value=.17

# Exact surface anchors placed on triangles, with normals and barycentric weights.
# A runtime callout can therefore reproject to the same triangle after camera motion
# and reject an anchor when that mesh/triangle is absent or occluded.
def closest_point_barycentric(a,b,c,p):
 # Real-Time Collision Detection's bounded closest-point test. Blender's
 # helper can return a projected point whose reconstructed weights drift
 # outside the triangle; anchors need weights that reproject exactly.
 ab=b-a; ac=c-a; ap=p-a
 d1=ab.dot(ap); d2=ac.dot(ap)
 if d1 <= 0 and d2 <= 0: return a,(1.0,0.0,0.0)
 bp=p-b; d3=ab.dot(bp); d4=ac.dot(bp)
 if d3 >= 0 and d4 <= d3: return b,(0.0,1.0,0.0)
 vc=d1*d4-d3*d2
 if vc <= 0 and d1 >= 0 and d3 <= 0:
  v=d1/(d1-d3); return a+v*ab,(1-v,v,0.0)
 cp=p-c; d5=ab.dot(cp); d6=ac.dot(cp)
 if d6 >= 0 and d5 <= d6: return c,(0.0,0.0,1.0)
 vb=d5*d2-d1*d6
 if vb <= 0 and d2 >= 0 and d6 <= 0:
  w=d2/(d2-d6); return a+w*ac,(1-w,0.0,w)
 va=d3*d6-d5*d4
 if va <= 0 and (d4-d3) >= 0 and (d5-d6) >= 0:
  w=(d4-d3)/((d4-d3)+(d5-d6)); return b+w*(c-b),(0.0,1-w,w)
 denom=1.0/(va+vb+vc); v=vb*denom; w=vc*denom
 return a+ab*v+ac*w,(1-v-w,v,w)

anchor_specs=[
 ('front-panel','front','body_panel',(.30,-1.64,.89),('hood','bumper_F','body_s210_body')),
 ('left-front-door','left','body_panel',(.91,-.34,.72),('door_FL',)),
 ('rear-left-panel','rear-left','body_panel',(.85,1.80,.90),('door_RL','bumper_R_g','body_s210_body')),
 ('right-side-panel','right','body_panel',(-.91,-.20,.70),('door_FR',)),
 ('front-windshield','front','windshield',(0,-.58,1.20),('windshield',)),
 ('left-front-tire','front-left','tire',(.91,-1.40,.38),('wheel_18x8','Object_4.')),
 ('left-headlight','front-left','light',(.70,-2.08,.76),('headlight',)),
 ('rear-panel','rear','body_panel',(0,2.59,.60),('bumper_R_g','tailgate'))]

def triangle_attachment(target, tokens):
 best=None
 for obj in meshes:
  if not any(token.lower() in obj.name.lower() for token in tokens): continue
  verts=[obj.matrix_world @ v.co for v in obj.data.vertices]
  for poly in obj.data.polygons:
   ids=list(poly.vertices)
   if len(ids)<3: continue
   for tri in range(1,len(ids)-1):
    ia,ib,ic=ids[0],ids[tri],ids[tri+1]; a,b,c=verts[ia],verts[ib],verts[ic]
    point,weights=closest_point_barycentric(a,b,c,Vector(target)); distance=(point-Vector(target)).length_squared
    if best is None or distance<best[0]:
     normal=(b-a).cross(c-a)
     if normal.length <= 1e-8: continue
     best=(distance,obj,poly.index,(ia,ib,ic),point,weights,normal.normalized())
 if best is None: raise RuntimeError(f'No anchor triangle matched {tokens}')
 _,obj,poly_index,tri,point,weights,normal=best
 return obj,poly_index,tri,point,weights,normal

anchorrows=[]
for name,region,surface,pos,tokens in anchor_specs:
    mesh,poly_index,tri,point,weights,normal=triangle_attachment(pos,tokens)
    o=bpy.data.objects.new('anchor-'+name,None);bpy.context.collection.objects.link(o);o.parent=root;o.location=point;o.empty_display_size=.04;o.hide_render=True
    o['regionId']=region;o['surface']=surface;o['evidenceRequired']=True;o['meshId']=mesh.name;o['primitiveIndex']=0;o['triangleIndex']=poly_index;o['triangleVertexIndices']=list(tri);o['barycentric']=list(weights);o['surfaceNormal']=list(normal);o['assetRevision']='crown-reveal-2.0'
    anchorrows.append({'id':name,'regionId':region,'surface':surface,'meshId':mesh.name,'primitiveIndex':0,'triangleIndex':poly_index,'triangleVertexIndices':list(tri),'barycentric':list(weights),'surfaceNormal':list(normal),'blenderMetres':list(point),'gltfMetres':[point[0],point[2],-point[1]]})

# Environment is separate, NEVER exported in the runtime GLB.
floor=simple('Review floor only',(.018,.019,.021),.0,.58)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.006));bpy.context.view_layer.objects.active.name='REVIEW_ONLY_Floor';bpy.context.view_layer.objects.active.data.materials.append(floor)
world=bpy.data.worlds.new('Neutral reflection studio');bpy.context.scene.world=world;world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.28,.30,.34,1);world.node_tree.nodes['Background'].inputs[1].default_value=.3

def aim(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
def area(name,loc,power,size,color=(1,1,1),sizey=None):
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.view_layer.objects.active;o.name=name;o.data.energy=power;o.data.color=color;o.data.shape='RECTANGLE';o.data.size=size;o.data.size_y=sizey or size;aim(o,(0,0,.6))
area('Key | long automotive softbox',(2,-2,5),700,5,(1,.94,.86),2)
area('Rim | long white line',(-3,1,3),900,5,(.86,.91,1),1)
area('Front | broad reflection',(1,-5,2.7),450,4,(1,1,1),2)
area('Roof highlight',(0,1,5),400,3,(1,1,1),1)
area('Side sculpt',(4,2,2),250,4,(1,1,1),2)
bpy.ops.object.empty_add(location=(0,.1,.72));target=bpy.context.view_layer.objects.active;target.name='REVIEW_ONLY_Orbit'
bpy.ops.object.camera_add(location=(6,-7,3.05));cam=bpy.context.view_layer.objects.active;cam.name='REVIEW_ONLY_Camera';cam.data.lens=56;aim(cam,(0,.1,.68));bpy.context.scene.camera=cam
scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE_NEXT';scene.render.resolution_x=1600;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast';scene.render.film_transparent=False
# Commit the aimed rotation before preserving world space. Blender otherwise
# may copy a stale identity matrix and point the authored render away from the car.
bpy.context.view_layer.update()
world_matrix=cam.matrix_world.copy();cam.parent=target;cam.matrix_world=world_matrix
for f,v in [(1,0),(96,-.16)]:target.rotation_euler.z=v;target.keyframe_insert('rotation_euler',frame=f)
scene.render.fps=24;scene.frame_start=1;scene.frame_end=96
for f,v in [(1,-.12),(10,-.12),(58,1.2),(96,1.2)]:radius.outputs[0].default_value=v;radius.outputs[0].keyframe_insert('default_value',frame=f)
scene.frame_set(1)
# Open the actual asset in camera perspective with rendered materials when loaded.
for screen in bpy.data.screens:
 for a in screen.areas:
  if a.type=='VIEW_3D':a.spaces.active.region_3d.view_perspective='CAMERA';a.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(ASSETS/'nextmove-crown.blend'))
# Runtime GLB = asset only, neutral base material; shader recipe lives in .blend
# and TEXCOORD_n. glTF does not port custom animated shader nodes.
bpy.ops.object.select_all(action='DESELECT')
for o in meshes+[root]+[o for o in scene.objects if o.name.startswith('anchor-')]:o.select_set(True)
bpy.context.view_layer.objects.active=root
# Use a neutral standard PBR material in exported mesh. Preserve reveal fields.
neutralmat=simple('Inspection neutral | bind runtime reveal shader',neutral[:3],.1,.43)
for o in meshes:
 if o.data.materials and o.data.materials[0]==bodymat:o.data.materials[0]=neutralmat
bpy.ops.export_scene.gltf(filepath=str(ASSETS/'nextmove-crown.glb'),export_format='GLB',use_selection=True,export_extras=True,export_texcoords=True,export_animations=False,export_cameras=False,export_lights=False)

# Blender's glTF exporter may reindex and triangulate a primitive. Remap the
# authored source triangle IDs against the exported POSITION/indices so the
# checked-in manifest and node extras reproject on the runtime GLB itself.
def remap_exported_anchors(path, rows):
 import struct
 raw=Path(path).read_bytes(); pos=12; chunks={}
 while pos < len(raw):
  length,kind=struct.unpack_from('<II',raw,pos);pos+=8;chunks[kind]=raw[pos:pos+length];pos+=length
 doc=json.loads(chunks[0x4e4f534A].decode('utf-8')); blob=chunks[0x004E4942]
 def accessor(index):
  a=doc['accessors'][index];bv=doc['bufferViews'][a['bufferView']]
  comp={5121:('B',1),5123:('H',2),5125:('I',4),5126:('f',4)}[a['componentType']]
  count=a['count']; ncomp={'SCALAR':1,'VEC3':3}[a['type']]; start=bv.get('byteOffset',0)+a.get('byteOffset',0)
  vals=struct.unpack_from('<'+comp[0]*(count*ncomp),blob,start)
  return [vals[i*ncomp:(i+1)*ncomp] for i in range(count)]
 nodes=doc['nodes']
 for row in rows:
  node=next((n for n in nodes if n.get('name','').startswith(row['meshId'])),None)
  if node is None: raise RuntimeError(f"Exported anchor mesh missing: {row['meshId']}")
  prim=doc['meshes'][node['mesh']]['primitives'][row['primitiveIndex']]
  positions=accessor(prim['attributes']['POSITION']); indices=accessor(prim['indices'])
  target=Vector(row['gltfMetres']); best=None
  for tri in range(0,len(indices),3):
   ids=tuple(int(indices[tri+i][0]) for i in range(3)); a,b,c=(Vector(positions[i]) for i in ids)
   point,weights=closest_point_barycentric(a,b,c,target); dist=(point-target).length_squared
   if best is None or dist<best[0]:
    normal=(b-a).cross(c-a)
    if normal.length>1e-8: best=(dist,tri//3,ids,weights,normal.normalized(),point)
  if best is None: raise RuntimeError(f"No exported triangle for {row['id']}")
  _,tri,ids,weights,normal,point=best
  row['triangleIndex']=tri;row['triangleVertexIndices']=list(ids);row['barycentric']=list(weights);row['surfaceNormal']=list(normal);row['gltfMetres']=list(point)
  obj=bpy.data.objects.get('anchor-'+row['id'])
  if obj:
   obj['triangleIndex']=tri;obj['triangleVertexIndices']=list(ids);obj['barycentric']=list(weights);obj['surfaceNormal']=list(normal)

remap_exported_anchors(ASSETS/'nextmove-crown.glb',anchorrows)
# Re-export once with corrected attachment extras on the anchor nodes.
bpy.ops.object.select_all(action='DESELECT')
for o in meshes+[root]+[o for o in scene.objects if o.name.startswith('anchor-')]:o.select_set(True)
bpy.context.view_layer.objects.active=root
bpy.ops.export_scene.gltf(filepath=str(ASSETS/'nextmove-crown.glb'),export_format='GLB',use_selection=True,export_extras=True,export_texcoords=True,export_animations=False,export_cameras=False,export_lights=False)
for o in meshes:
 if o.data.materials and o.data.materials[0]==neutralmat:o.data.materials[0]=bodymat
(ASSETS/'reveal-surfaces.json').write_text(json.dumps({'revision':'crown-reveal-2.0','fields':fields,'anchors':anchorrows,'coordinates':'Blender +X vehicle left, -Y front, +Z up; glTF +X vehicle left, +Y up, +Z front; do not reuse normalized heroDefaults coordinates','note':'Presentation metadata only, not a canonical scan schema. Source parts are illustrative, not observed geometry.'},indent=2)+'\n')
# Static beauty = explicit asset inspection, separate from evidence states.
beauty.outputs[0].default_value=1
scene.render.filepath=str(ASSETS/'review/vehicle-beauty.png');bpy.ops.render.render(write_still=True)
beauty.outputs[0].default_value=0
scene.frame_set(1);scene.render.filepath=str(ASSETS/'review/vehicle-neutral.png');bpy.ops.render.render(write_still=True)
scene.frame_set(25);scene.render.filepath=str(ASSETS/'review/vehicle-reveal.png');bpy.ops.render.render(write_still=True)
scene.frame_set(80);scene.render.filepath=str(ASSETS/'review/vehicle-observed.png');bpy.ops.render.render(write_still=True)
scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(ASSETS/'nextmove-crown.blend'))
scene.render.resolution_percentage=60
scene.render.image_settings.file_format='FFMPEG';scene.render.ffmpeg.format='MPEG4';scene.render.ffmpeg.codec='H264';scene.render.ffmpeg.constant_rate_factor='HIGH'
scene.render.filepath=str(ASSETS/'review/material-reveal.mp4')
bpy.ops.render.render(animation=True)
scene.frame_set(1)
print('BUILD_COMPLETE',len(meshes),'meshes',len(fields),'geodesic fields',len(anchorrows),'anchors')
