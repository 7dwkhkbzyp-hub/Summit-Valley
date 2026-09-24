import * as pc from "https://cdn.jsdelivr.net/npm/playcanvas@2.5.0/build/playcanvas.mjs";

const canvas=document.getElementById("application-canvas");
const app=new pc.Application(canvas,{graphicsDeviceOptions:{alpha:false,antialias:true,preserveDrawingBuffer:false}});
app.setCanvasFillMode(pc.FILLMODE_FILL_WINDOW);
app.setCanvasResolution(pc.RESOLUTION_AUTO);
app.scene.ambientLight=new pc.Color(.34,.42,.54);
app.scene.fog="linear";
app.scene.fogStart=85;
app.scene.fogEnd=190;
app.scene.fogColor=new pc.Color(.60,.74,.86);

const sun=new pc.Entity("Alpine Sun");
sun.addComponent("light",{type:"directional",color:new pc.Color(1,.95,.86),intensity:2.7,castShadows:true,shadowDistance:180,shadowResolution:2048});
sun.setEulerAngles(42,-35,0);
app.root.addChild(sun);
app.scene.exposure=1.08;
app.start();

const mats={};
function mat(n,c,r=.8,m=0,em=0){
  const x=new pc.StandardMaterial();
  x.diffuse=new pc.Color(c[0],c[1],c[2]);
  x.roughness=r;x.metalness=m;x.useMetalness=true;x.name=n;
  if(em){x.emissive=new pc.Color(c[0]*em,c[1]*em,c[2]*em);x.emissiveIntensity=em}
  x.update();mats[n]=x;return x;
}
const snow=mat("Mountain snow",[.78,.86,.94],.98);
const snowBright=mat("Fresh snow",[.97,.99,1],.94);
const snowShade=mat("Snow shadow",[.62,.72,.82],1);
const rock=mat("Exposed alpine rock",[.20,.23,.25],.94);
const rockLight=mat("Rock highlights",[.34,.36,.37],.9);
const pine=mat("Deep fir",[.025,.12,.075],.98);
const pine2=mat("Fir snow",[.16,.30,.24],.92);
const trunk=mat("Timber",[.20,.105,.055],.9);
const timber=mat("Chalet timber",[.30,.16,.075],.82);
const roof=mat("Dark roof",[.075,.055,.05],.72);
const roofSnow=mat("Roof snow",[.86,.92,.96],.95);
const glass=mat("Warm windows",[.05,.22,.29],.12,.25,.35);
const warm=mat("Window glow",[1,.48,.10],.18,0,.8);
const steel=mat("Lift steel",[.30,.34,.38],.34,.82);
const cable=mat("Lift cable",[.035,.04,.045],.55,.75);
const chair=mat("Chair seats",[.72,.055,.045],.42,.25);
const gondola=mat("Gondola cabins",[.08,.25,.32],.18,.5);
const green=mat("Green piste",[.10,.54,.20],.78);
const blue=mat("Blue piste",[.055,.30,.78],.78);
const red=mat("Red piste",[.72,.075,.045],.72);
const black=mat("Black piste",[.045,.05,.06],.65);
const pisteEdge=mat("Piste edge",[.92,.96,.99],.95);
const yellow=mat("Mountain signs",[1,.67,.08],.45);
const jacket=mat("Skier jacket",[.08,.25,.72],.68);
const jacket2=mat("Skier red jacket",[.72,.08,.055],.68);
const jacket3=mat("Skier green jacket",[.05,.40,.22],.68);
const pants=mat("Skier pants",[.035,.045,.06],.72);
const skin=mat("Skin",[.70,.43,.27],.82);
const board=mat("Snowboard",[.10,.11,.13],.45,.35);

function entity(n,p,s,pos,m,parent=app.root){
  const e=new pc.Entity(n);
  e.addComponent("render",{type:p});
  e.setLocalScale(s[0],s[1],s[2]);
  e.setLocalPosition(pos[0],pos[1],pos[2]);
  e.render.material=m;
  parent.addChild(e);
  return e;
}
const box=(n,s,p,m,q)=>entity(n,"box",s,p,m,q);
const sphere=(n,s,p,m,q)=>entity(n,"sphere",s,p,m,q);
const cyl=(n,s,p,m,q)=>entity(n,"cylinder",s,p,m,q);
const cone=(n,s,p,m,q)=>entity(n,"cone",s,p,m,q);

const W=160,D=125;
function height(x,z){
  const main=31*Math.exp(-((x+30)**2/3000+(z-2)**2/3700));
  const west=18*Math.exp(-((x-25)**2/1900+(z+1)**2/2400));
  const peak=24*Math.exp(-((x-4)**2/1250+(z-34)**2/720));
  const shoulder=11*Math.exp(-((x+57)**2/1600+(z-22)**2/1800));
  const valley=-10*Math.exp(-((x+2)**2/520+(z+18)**2/1900));
  const gullies=-4*Math.sin(x*.075+z*.045)**2-2.2*Math.cos(z*.16-x*.06);
  return Math.max(0.5,3+main+west+peak+shoulder+valley+gullies);
}

function meshEntity(name,positions,indices,material){
  const mesh=new pc.Mesh(app.graphicsDevice);
  mesh.setPositions(positions);
  mesh.setIndices(indices);
  mesh.update(pc.PRIMITIVE_TRIANGLES);
  const e=new pc.Entity(name);
  e.addComponent("render",{type:"asset"});
  e.render.meshInstances=[new pc.MeshInstance(mesh,material)];
  app.root.addChild(e);
  return e;
}

function buildTerrain(){
  const N=82,v=[],ix=[];
  for(let z=0;z<=N;z++) for(let x=0;x<=N;x++){
    const X=-W/2+W*x/N,Z=-D/2+D*z/N;
    v.push(X,height(X,Z),Z);
  }
  for(let z=0;z<N;z++) for(let x=0;x<N;x++){
    const i=z*(N+1)+x;
    ix.push(i,i+1,i+N+1,i+1,i+N+2,i+N+1);
  }
  meshEntity("Sculpted Alpine Mountain",v,ix,snow);

  // Exposed rock faces and summit bands.
  const patches=[
    [-7,39,9,8,2.0],[-42,23,11,7,1.4],[22,26,10,7,1.7],[42,17,8,9,1.0],
    [-54,9,7,6,1.0],[5,31,7,6,2.2]
  ];
  patches.forEach((p,k)=>{
    const [cx,cz,sx,sz,drop]=p;
    const verts=[],inds=[];
    const n=8;
    for(let j=0;j<=n;j++)for(let i=0;i<=n;i++){
      const u=i/n*2-1,w=j/n*2-1;
      const X=cx+u*sx,Z=cz+w*sz;
      verts.push(X,height(X,Z)-drop-.15*Math.sin(i*1.7+j),Z);
    }
    for(let j=0;j<n;j++)for(let i=0;i<n;i++){
      const q=j*(n+1)+i;inds.push(q,q+1,q+n+1,q+1,q+n+2,q+n+1);
    }
    meshEntity("Rock face "+k,verts,inds,k%2?rock:rockLight);
  });
}
buildTerrain();

function tree(x,z,s=1){
  const y=height(x,z);
  const e=new pc.Entity("Alpine fir");
  e.setLocalPosition(x,y-.05,z);
  app.root.addChild(e);
  cyl("trunk",[.22*s,.9*s,.22*s],[0,.45*s,0],trunk,e);
  cone("lower boughs",[1.25*s,2.1*s,1.25*s],[0,1.35*s,0],pine,e);
  cone("middle boughs",[1.0*s,1.85*s,1.0*s],[0,2.35*s,0],pine,e);
  cone("top boughs",[.68*s,1.65*s,.68*s],[0,3.05*s,0],pine2,e);
}
for(let i=0;i<135;i++){
  const x=-76+Math.random()*152,z=-58+Math.random()*112,y=height(x,z);
  if(y>4&&y<30&&Math.random()>.12) tree(x,z,.45+Math.random()*.8);
}

const paths=[
  {name:"Meadow Run",color:green,width:4.8,pts:[[-42,34],[-39,29],[-34,23],[-30,16],[-24,9],[-18,3],[-12,-4],[-6,-11],[0,-19],[8,-24]]},
  {name:"Ridge Runner",color:red,width:4.6,pts:[[27,31],[25,26],[22,21],[18,15],[15,9],[12,2],[9,-6],[7,-14],[8,-22],[13,-27]]},
  {name:"Glacier Way",color:blue,width:5.0,pts:[[-1,38],[1,33],[4,28],[7,22],[10,16],[14,10],[18,4],[21,-3],[23,-10],[24,-18]]},
  {name:"Black Couloir",color:black,width:3.8,pts:[[42,29],[38,24],[35,18],[32,12],[29,6],[27,0],[25,-7],[23,-14]]},
  {name:"Village Link",color:blue,width:4.0,pts:[[-31,-4],[-26,-8],[-20,-12],[-14,-16],[-7,-20],[1,-23],[9,-25],[17,-25]]}
];

function ribbon(path){
  const verts=[],inds=[],side=[];
  for(let i=0;i<path.pts.length;i++){
    const [x,z]=path.pts[i],prev=path.pts[Math.max(0,i-1)],next=path.pts[Math.min(path.pts.length-1,i+1)];
    const dx=next[0]-prev[0],dz=next[1]-prev[1],len=Math.hypot(dx,dz)||1;
    const nx=-dz/len,nz=dx/len,w=path.width/2;
    const left=[x+nx*w,z+nz*w],right=[x-nx*w,z-nz*w];
    verts.push(left[0],height(left[0],left[1])+.28,left[1],right[0],height(right[0],right[1])+.28,right[1]);
    side.push([left,right]);
  }
  for(let i=0;i<path.pts.length-1;i++){const q=i*2;inds.push(q,q+1,q+2,q+1,q+3,q+2);}
  const e=meshEntity(path.name+" 3D piste",verts,inds,path.color);
  // Raised snow berms make the run read as a real cut into the mountain.
  side.forEach((s,i)=>{
    if(i%2!==0)return;
    s.forEach(([x,z])=>{const y=height(x,z)+.38; cone(path.name+" piste berm",[.24,.45,.24],[x,y,z],snowBright);});
  });
  // Boundary poles and piste markers.
  path.pts.forEach(([x,z],i)=>{
    if(i%2===0){
      const dx=(path.pts[Math.min(path.pts.length-1,i+1)][0]-path.pts[Math.max(0,i-1)][0]);
      const dz=(path.pts[Math.min(path.pts.length-1,i+1)][1]-path.pts[Math.max(0,i-1)][1]);
      const l=Math.hypot(dx,dz)||1,nx=-dz/l,nz=dx/l;
      for(const sign of[-1,1]){
        const px=x+nx*(path.width*.58)*sign,pz=z+nz*(path.width*.58)*sign;
        cyl(path.name+" snow pole",[.045,1.25,.045],[px,height(px,pz)+.62,pz],yellow);
      }
    }
  });
  return e;
}
paths.forEach(ribbon);

function signAt(text,x,z,color){
  const y=height(x,z)+1.25,e=new pc.Entity(text);
  e.setLocalPosition(x,y,z);app.root.addChild(e);
  cyl("sign post",[.06,1.3,.06],[0,-.65,0],steel,e);
  box("sign board",[1.35,.58,.10],[0,.05,0],color,e);
  return e;
}
signAt("MEADOW",-18,3,green);
signAt("RIDGE",12,2,red);
signAt("GLACIER",18,4,blue);
signAt("COULOIR",29,5,black);

function chalet(n,x,z,s=1){
  const y=height(x,z),e=new pc.Entity(n);e.setLocalPosition(x,y,z);e.setLocalScale(s,s,s);app.root.addChild(e);
  box("chalet walls",[8,3.9,6],[0,2,0],timber,e);
  // Pitched roof: two long rotated roof planes.
  const r1=box("pitched roof",[4.9,.55,7.2],[-2.05,4.35,0],roof,e);r1.setLocalEulerAngles(0,0,-29);
  const r2=box("pitched roof",[4.9,.55,7.2],[2.05,4.35,0],roof,e);r2.setLocalEulerAngles(0,0,29);
  const rs1=box("roof snow",[4.7,.18,7.0],[-2.0,4.72,0],roofSnow,e);rs1.setLocalEulerAngles(0,0,-29);
  const rs2=box("roof snow",[4.7,.18,7.0],[2.0,4.72,0],roofSnow,e);rs2.setLocalEulerAngles(0,0,29);
  for(const sx of[-2.7,0,2.7]){
    box("window",[1.45,1.1,.12],[sx,2.35,3.04],glass,e);
    box("window light",[1.15,.12,.13],[sx,2.35,3.11],warm,e);
  }
  box("door",[1.15,2.1,.16],[0,1.05,3.08],roof,e);
  box("balcony",[3.4,.16,1.0],[0,2.75,3.48],trunk,e);
  for(const sx of[-1.45,1.45])cyl("balcony rail",[.08,1.0,.08],[sx,3.25,3.48],steel,e);
  cyl("chimney",[.55,1.25,.55],[2.3,5.0,1.0],roof,e);
}
chalet("Summit Lodge",-5,-24,1.35);
chalet("Piste House",18,-16,.9);
chalet("Mountain Hotel",-27,-14,1.25);

function station(n,x,z,type="chair"){
  const y=height(x,z),e=new pc.Entity(n);e.setLocalPosition(x,y,z);app.root.addChild(e);
  box("station body",[6,2.8,4.5],[0,1.4,0],steel,e);
  const r1=box("station roof",[3.6,.5,5.6],[-1.5,3.05,0],roof,e);r1.setLocalEulerAngles(0,0,-22);
  const r2=box("station roof",[3.6,.5,5.6],[1.5,3.05,0],roof,e);r2.setLocalEulerAngles(0,0,22);
  box("station glass",[4.4,1.25,.12],[0,1.55,2.28],glass,e);
  box("station platform",[7,.25,1.3],[0,.25,0],snowBright,e);
  if(type==="gondola")box("gondola sign",[2.3,.55,.12],[0,2.35,2.4],gondola,e);
  return e;
}

function makeLift(n,a,b,count,type="chair"){
  const root=new pc.Entity(n);app.root.addChild(root);
  const [ax,az]=a,[bx,bz]=b,dx=bx-ax,dz=bz-az,len=Math.hypot(dx,dz)||1;
  const ay=height(ax,az)+3.1,by=height(bx,bz)+3.1;
  const ang=Math.atan2(dx,dz)*180/Math.PI;
  station(n+" base",ax,az,type);station(n+" summit",bx,bz,type);
  for(let i=1;i<8;i++){
    const t=i/8,x=ax+dx*t,z=az+dz*t,y=height(x,z)+2.6;
    const tower=new pc.Entity(n+" tower");tower.setLocalPosition(x,y,z);root.addChild(tower);
    cyl("tower leg",[.24,5,.24],[0,-2.5,0],steel,tower);
    const cross=box("tower crossarm",[3.2,.2,.35],[0,0,0],steel,tower);cross.setLocalEulerAngles(0,ang,0);
    for(const sx of[-1,1])sphere("sheave",[.28,.28,.28],[sx*1.35,-.18,0],cable,tower);
  }
  const rope=box("cable",[.065,.065,len],[(ax+bx)/2,(ay+by)/2,(az+bz)/2],cable,root);
  rope.setLocalEulerAngles(0,ang,Math.atan2(by-ay,len)*180/Math.PI);
  const carriers=[];
  for(let i=0;i<count;i++){
    const e=new pc.Entity(n+" carrier "+i);root.addChild(e);
    e._phase=i/count;e._a=[ax,ay,az];e._b=[bx,by,bz];e._type=type;
    if(type==="gondola"){
      box("cab",[1.25,1.05,.9],[0,-.2,0],gondola,e);
      box("cab glass",[1.0,.65,.08],[0,-.15,.47],glass,e);
      box("hanger",[.07,1.35,.07],[0,.82,0],steel,e);
    }else{
      box("seat",[1.3,.16,.48],[0,-.58,0],chair,e);
      box("back",[1.3,.7,.11],[0,-.18,0],chair,e);
      box("hanger",[.07,1.5,.07],[0,.6,0],steel,e);
    }
    carriers.push(e);
  }
  return carriers;
}
const lift1=makeLift("Eagle Express",[-5,-22],[-38,31],11,"chair");
const lift2=makeLift("Glacier Chair",[18,-15],[1,38],10,"chair");
const lift3=makeLift("Ridge Gondola",[28,-8],[44,29],8,"gondola");

const guests=[];
function samplePath(path,t){
  const f=t*(path.pts.length-1),i=Math.min(path.pts.length-2,Math.floor(f)),q=f-i;
  return [path.pts[i][0]+(path.pts[i+1][0]-path.pts[i][0])*q,path.pts[i][1]+(path.pts[i+1][1]-path.pts[i][1])*q];
}
function makeSkier(i,pathIndex,t,type){
  const path=paths[pathIndex],p=samplePath(path,t),y=height(p[0],p[1])+.62;
  const e=new pc.Entity((type==="snowboarder"?"Snowboarder ":"Skier ")+i);
  e.setLocalPosition(p[0],y,p[1]);app.root.addChild(e);
  const jm=i%3===0?jacket2:i%3===1?jacket:jacket3;
  sphere("helmet",[.27,.27,.27],[0,1.58,0],i%2?cable:yellow,e);
  sphere("head",[.22,.22,.22],[0,1.38,0],skin,e);
  box("torso",[.42,.68,.30],[0,.95,0],jm,e);
  const armL=box("arm",[.13,.55,.13],[-.30,1.02,0],jm,e);
  const armR=box("arm",[.13,.55,.13],[.30,1.02,0],jm,e);
  box("leg",[.14,.55,.14],[-.13,.42,0],pants,e);box("leg",[.14,.55,.14],[.13,.42,0],pants,e);
  if(type==="snowboarder"){
    box("board",[.95,.07,.20],[0,.13,0],board,e);
  }else{
    box("ski",[.055,.045,1.12],[-.18,.12,0],snowBright,e);
    box("ski",[.055,.045,1.12],[.18,.12,0],snowBright,e);
    cyl("pole",[.025,.7,.025],[-.34,.62,0],steel,e);cyl("pole",[.025,.7,.025],[.34,.62,0],steel,e);
  }
  e._route=pathIndex;e._path=t;e._speed=.025+Math.random()*.035;e._phase=Math.random()*6;
  e._turn=0;guests.push(e);
}
for(let i=0;i<42;i++){
  const route=i%paths.length;
  makeSkier(i,route,(i*0.173+Math.random()*.22)%1,i%7===0?"snowboarder":"skier");
}

function chooseRoute(g){
  const candidates=[0,1,2,3,4].filter(x=>x!==g._route);
  g._route=candidates[Math.floor(Math.random()*candidates.length)];
  g._path=Math.random()*.10;
  g._speed=.022+Math.random()*.04;
}
let cash=250000,paused=false,weather=0;

app.on("update",dt=>{
  if(paused)return;
  const now=performance.now()/1000;
  guests.forEach(g=>{
    g._path+=dt*g._speed;
    if(g._path>=1)chooseRoute(g);
    const path=paths[g._route],p=samplePath(path,g._path),p2=samplePath(path,Math.min(.999,g._path+.012));
    const turn=Math.atan2(p2[0]-p[0],p2[1]-p[1])*180/Math.PI;
    g.setLocalPosition(p[0],height(p[0],p[1])+.62,p[1]);
    g.setLocalEulerAngles(0,turn,Math.sin(now*4+g._phase)*4);
  });
  [...lift1,...lift2,...lift3].forEach(c=>{
    const cycle=(c._phase+now*.055)%2;
    const t=cycle<=1?cycle:2-cycle;
    c.setPosition(
      pc.math.lerp(c._a[0],c._b[0],t),
      pc.math.lerp(c._a[1],c._b[1],t),
      pc.math.lerp(c._a[2],c._b[2],t)
    );
  });
  document.getElementById("guests").textContent=String(80+Math.floor((now*2)%90));
  document.getElementById("cash").textContent=Math.floor(cash).toLocaleString();
});

let tool="select";
document.querySelectorAll(".tool").forEach(b=>b.addEventListener("click",()=>{
  document.querySelectorAll(".tool").forEach(x=>x.classList.remove("active"));
  b.classList.add("active");tool=b.dataset.tool;
  toast(tool==="select"?"Select and inspect your resort":"Build mode: "+b.textContent.trim());
}));
function toast(t){
  const e=document.getElementById("toast");e.textContent=t;e.classList.add("show");
  clearTimeout(window.__toast);window.__toast=setTimeout(()=>e.classList.remove("show"),1600);
}
document.getElementById("pauseBtn").onclick=()=>{paused=!paused;document.getElementById("pauseBtn").textContent=paused?"▶":"Ⅱ";toast(paused?"Game paused":"Game resumed")};
document.getElementById("weatherBtn").onclick=()=>{
  weather=(weather+1)%3;const n=["Clear","Snowfall","Storm"];
  document.getElementById("weather").textContent=n[weather];toast(n[weather]+" conditions");
};
document.getElementById("resetBtn").onclick=()=>{cash=250000;toast("New season started")};

const camera=new pc.Entity("Camera");
camera.addComponent("camera",{clearColor:new pc.Color(.60,.76,.88),fov:48});
app.root.addChild(camera);
let yaw=-31,pitch=34,distance=126,target=new pc.Vec3(0,15,3);
function updateCamera(){
  const yr=yaw*Math.PI/180,pr=pitch*Math.PI/180;
  camera.setPosition(target.x+Math.sin(yr)*Math.cos(pr)*distance,target.y+Math.sin(pr)*distance,target.z+Math.cos(yr)*Math.cos(pr)*distance);
  camera.lookAt(target);
}
updateCamera();

const pointers=new Map();let lastDist=0;
canvas.addEventListener("pointerdown",e=>{canvas.setPointerCapture(e.pointerId);pointers.set(e.pointerId,[e.clientX,e.clientY])});
canvas.addEventListener("pointermove",e=>{
  if(!pointers.has(e.pointerId))return;
  const old=pointers.get(e.pointerId);pointers.set(e.pointerId,[e.clientX,e.clientY]);
  if(pointers.size===1){yaw-=(e.clientX-old[0])*.22;pitch=Math.max(15,Math.min(75,pitch+(e.clientY-old[1])*.18));updateCamera()}
  else if(pointers.size===2){
    const a=[...pointers.values()],d=Math.hypot(a[0][0]-a[1][0],a[0][1]-a[1][1]);
    if(lastDist)distance=Math.max(48,Math.min(150,distance-(d-lastDist)*.35));
    lastDist=d;updateCamera();
  }
});
canvas.addEventListener("pointerup",e=>{pointers.delete(e.pointerId);lastDist=0});
canvas.addEventListener("wheel",e=>{distance=Math.max(48,Math.min(150,distance+e.deltaY*.06));updateCamera()},{passive:true});
window.addEventListener("resize",()=>app.resizeCanvas(canvas.clientWidth,canvas.clientHeight));

setTimeout(()=>{
  document.getElementById("loading").style.opacity="0";
  setTimeout(()=>document.getElementById("loading").remove(),600);
  toast("Summit Valley — 3D vertical slice");
},1400);
