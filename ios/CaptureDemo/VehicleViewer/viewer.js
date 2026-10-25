import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';

const renderer=new THREE.WebGLRenderer({antialias:true,alpha:true,preserveDrawingBuffer:true});
renderer.setPixelRatio(Math.min(devicePixelRatio,1.75));
renderer.setSize(innerWidth,innerHeight);
renderer.setClearColor(0x141517,0);
renderer.toneMapping=THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure=1.1;
document.body.prepend(renderer.domElement);
const scene=new THREE.Scene();
const pmrem=new THREE.PMREMGenerator(renderer);
const environment=new RoomEnvironment();
scene.environment=pmrem.fromScene(environment,.04).texture;
environment.dispose();
const camera=new THREE.PerspectiveCamera(35,innerWidth/innerHeight,.05,70);
const heroCamera=new THREE.Vector3(6,3.05,7);
camera.position.copy(heroCamera);
const controls=new OrbitControls(camera,renderer.domElement);
controls.target.set(0,.72,-.10);
controls.enableDamping=true;controls.dampingFactor=.08;controls.enablePan=false;
controls.minDistance=5.7;controls.maxDistance=13;
controls.minPolarAngle=.50;controls.maxPolarAngle=1.48;
const uniforms={radius:{value:1.2},beauty:{value:1},inspectionState:{value:0},pigment:{value:new THREE.Color(.018,.075,.34)},amber:{value:new THREE.Color(.72,.38,.08)}};
const reduced=matchMedia('(prefers-reduced-motion: reduce)');
let started=null,mode='beauty',model,ready=false,shaderMaterials=0;
const state=document.querySelector('#state');
function setMode(next){
 mode=next;uniforms.beauty.value=next==='beauty'?1:0;uniforms.inspectionState.value=next==='uncertain'?1:(next==='reveal'?2:0);
 document.querySelector('#beauty').setAttribute('aria-pressed',String(next==='beauty'));
 document.querySelector('#reveal').setAttribute('aria-pressed',String(next==='reveal'));
 if(next==='reveal'){started=performance.now();uniforms.radius.value=reduced.matches?1.2:-.12;state.textContent='Accepted evidence study · only permitted surfaces resolve';}
 else if(next==='uncertain'){started=performance.now();uniforms.radius.value=reduced.matches?1.2:-.12;state.textContent='Partial evidence · amber uncertainty stays visible';}
 else{started=null;state.textContent='Asset beauty view · no inspection assessment';}
}
document.querySelector('#beauty').onclick=()=>setMode('beauty');
document.querySelector('#uncertain').onclick=()=>setMode('uncertain');
document.querySelector('#reveal').onclick=()=>setMode('reveal');
document.querySelector('#reset').onclick=()=>{camera.position.copy(heroCamera);controls.target.set(0,.72,-.10);controls.update();};
const loader=new GLTFLoader();
try{
 const asset=await loader.loadAsync('./nextmove-crown.glb');
 model=asset.scene;scene.add(model);
 model.traverse(mesh=>{
  if(!mesh.isMesh||mesh.userData.revealDomain!=='mesh-edge-geodesic')return;
  const channel=mesh.userData.revealUVChannel;
  const uv=mesh.geometry.getAttribute(channel===0?'uv':`uv${channel}`);
  if(!uv)throw new Error(`Missing reveal UV channel on ${mesh.name}`);
  mesh.geometry.setAttribute('inspectionReveal',uv);
  const material=mesh.material.clone();mesh.material=material;shaderMaterials++;
  material.onBeforeCompile=shader=>{
   shader.uniforms.revealRadius=uniforms.radius;shader.uniforms.assetBeauty=uniforms.beauty;shader.uniforms.inspectionState=uniforms.inspectionState;shader.uniforms.pigment=uniforms.pigment;shader.uniforms.amber=uniforms.amber;
   shader.vertexShader='attribute vec2 inspectionReveal; varying vec2 vInspectionReveal; varying vec3 vRevealLocal;\n'+shader.vertexShader;
   shader.vertexShader=shader.vertexShader.replace('#include <begin_vertex>','#include <begin_vertex>\nvInspectionReveal=inspectionReveal;vRevealLocal=position;');
   shader.fragmentShader='uniform float revealRadius; uniform float assetBeauty; uniform float inspectionState; uniform vec3 pigment; uniform vec3 amber; varying vec2 vInspectionReveal; varying vec3 vRevealLocal;\n'+shader.fragmentShader;
   shader.fragmentShader=shader.fragmentShader.replace('#include <color_fragment>',`#include <color_fragment>
     float fiber=sin(dot(vRevealLocal,vec3(41.3,79.1,57.7)))*sin(dot(vRevealLocal,vec3(91.7,23.1,45.7)))*0.014;
     float emergence=smoothstep(-0.06,0.09,revealRadius-vInspectionReveal.x+fiber)*vInspectionReveal.y;
     float accepted=emergence*step(1.5,inspectionState);
     float uncertain=emergence*(1.0-step(1.5,inspectionState));
     float surfaceReveal=max(accepted,assetBeauty);
     vec3 neutral=vec3(0.14,0.16,0.19);
     vec3 authoredPaint=vec3(0.008,0.035,0.16);
     vec3 baseColor=mix(neutral,authoredPaint,assetBeauty);
     diffuseColor.rgb=mix(baseColor,pigment,accepted);
     diffuseColor.rgb=mix(diffuseColor.rgb,mix(neutral,amber,uncertain),uncertain);`);
   shader.fragmentShader=shader.fragmentShader.replace('#include <roughnessmap_fragment>','#include <roughnessmap_fragment>\nroughnessFactor=mix(0.43,0.27,surfaceReveal);roughnessFactor=mix(roughnessFactor,0.39,uncertain);');
   shader.fragmentShader=shader.fragmentShader.replace('#include <metalnessmap_fragment>','#include <metalnessmap_fragment>\nmetalnessFactor=mix(0.10,0.50,surfaceReveal);metalnessFactor=mix(metalnessFactor,0.16,uncertain);');
  };
  material.customProgramCacheKey=()=> 'nextmove-geodesic-reveal-2';
 });
 document.querySelector('#loading').remove();ready=true;
 window.vehicleStudy={get ready(){return ready},get materialCount(){return shaderMaterials},get mode(){return mode},setProgress(progress){if(!Number.isFinite(progress)||progress<0||progress>1)throw new Error('Progress must be 0...1');setMode('reveal');started=null;uniforms.radius.value=-.12+1.32*progress;},reset:()=>setMode('beauty')};
}catch(error){document.querySelector('#loading').remove();document.querySelector('#error').textContent=`Vehicle load failed: ${error.message}`;console.error(error);}
function resize(){camera.aspect=innerWidth/innerHeight;camera.updateProjectionMatrix();renderer.setSize(innerWidth,innerHeight);}
addEventListener('resize',resize);
function draw(now){
 requestAnimationFrame(draw);
 if(started!==null&&!reduced.matches){const t=THREE.MathUtils.clamp((now-started-300)/2200,0,1);const eased=t*t*(3-2*t);uniforms.radius.value=-.12+1.32*eased;if(t===1){started=null;state.textContent=mode==='uncertain'?'Partial evidence remains amber · unresolved surfaces stay neutral':'Accepted surfaces resolved · roof, rear and far side stay neutral';}}
 controls.update();renderer.render(scene,camera);
}
requestAnimationFrame(draw);
