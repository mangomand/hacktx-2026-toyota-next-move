"""Start official mcp-for-blender 2.2.4 addon in a NEW isolated Blender GUI.
Blender --python vision/tools/start_blender_bridge.py -- /path/to/bundled/addon.py
This session does not install an addon or change global application preferences.
"""
import bpy
import importlib.util
import sys
from pathlib import Path

args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
if len(args)!=1 or not Path(args[0]).is_file():
    raise RuntimeError('Pass the pinned mcp-for-blender bundled/addon.py after --')
spec=importlib.util.spec_from_file_location('nextmove_blender_bridge',args[0])
bridge=importlib.util.module_from_spec(spec)
sys.modules[spec.name]=bridge
spec.loader.exec_module(bridge)
bridge.register()
bpy.context.scene.blendermcp_auto_start_server=False
server=bridge.BlenderMCPServer(host='127.0.0.1',port=9876)
bpy.types.blendermcp_server=server
server.start()
if not server.running:
    raise RuntimeError('Blender MCP port unavailable; existing session was not replaced')
