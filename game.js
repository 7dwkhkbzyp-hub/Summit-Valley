import * as pc from "https://cdn.jsdelivr.net/npm/playcanvas@2.5.0/build/playcanvas.mjs";

const canvas=document.getElementById("application-canvas");
const app=new pc.Application(canvas,{graphicsDeviceOptions:{alpha:false,antialias:true,preserveDrawingBuffer:false}});
app.setCanvasFillMode(pc.FILLMODE_FILL_WINDOW);app.setCanvasResolution(pc.RESOLUTION_AUTO);
app.scene.ambientLight=new pc.Color(.30,.39,.52);app.scene.fog.type=pc.FOG_LINEAR;app.scene.fog.start=95;app.scene.fog.end=250;app.scene.fog.color=new pc.Color(.63,.76,.87);
const sun=new pc.Entity("Alpine Sun");sun.addComponent("light",{type:"directional",color:new pc.Color(1,.94,.82),intensity:3,castShadows:true,shadowDistance:220,shadowResolution:2048});sun.setEulerAngles(43,-34,0);app.root.addChild(sun);app.scene.exposure=1.12;app.start();

const mats={};function mat(n,c,r=.8,m=0,em=0){const x=new pc.StandardMaterial();x.diffuse=new pc.Color(c[0],c[1],c[2]);x.roughness=r;x.metalness=m;x.useMetalness=true;x.name=n;if(em){x.emissive=new pc.Color(c[0]*em,c[1]*em,c[2]*em);x.emissiveIntensity=em}x.update();mats[n]=x;return x}
const snow=mat("Powder snow",[.82,.89,.96],.98),snowBright=mat("Sunlit snow",[.98,.995,1],.92),snowBlue=mat("Blue shadow snow",[.58,.70,.84],1),snowGrey=mat("Packed snow",[.70,.79,.88],.98),rock=mat("Dark granite",[.18,.20,.22],.96),rockLight=mat("Sunlit granite",[.36,.38,.39],.9),rockDark=mat("Deep rock",[.105,.12,.13],1),pine=mat("Fir forest",[.018,.095,.058],.98),pine2=mat("Snowy fir",[.10,.23,.16],.94),pineSnow=mat("Heavy snow fir",[.63,.72,.77],.96),trunk=mat("Timber",[.18,.09,.045],.9),timber=mat("Chalet timber",[.30,.15,.07],.82),roof=mat("Dark roof",[.055,.045,.043],.7),roofSnow=mat("Roof snow",[.88,.93,.97],.96),glass=mat("Warm glass",[.045,.18,.24],.10,.25,.35),warm=mat("Interior light",[1,.45,.08],.16,0,.9),steel=mat("Lift steel",[.29,.33,.37],.32,.85),cable=mat("Lift cable",[.025,.03,.035],.52,.8),chair=mat("Chair red",[.70,.045,.035],.4,.3),gondola=mat("Gondola blue",[.055,.23,.31],.15,.55),green=mat("Green piste",[.08,.52,.16],.78),blue=mat("Blue piste",[.045,.27,.76],.78),red=mat("Red piste",[.70,.055,.035],.72),black=mat("Black piste",[.035,.038,.045],.65),yellow=mat("Piste marker",[1,.65,.05],.45),jacket=mat("Skier blue",[.06,.22,.72],.66),jacket2=mat("Skier red",[.72,.06,.045],.66),jacket3=mat("Skier green",[.04,.38,.20],.66),jacket4=mat("Skier orange",[.90,.34,.04],.66),pants=mat("Skier dark",[.025,.035,.05],.72),skin=mat("Skin",[.70,.43,.27],.82),board=mat("Snowboard",[.07,.08,.10],.45,.4),goggle=mat("Goggles",[.03,.12,.18],.08,.55,.22),boot=mat("Boots",[.035,.045,.055],.48,.25),pack=mat("Backpack",[.035,.055,.075],.7),glove=mat("Gloves",[.055,.065,.075],.72),terrainTint=mat("Terrain detail",[.92,.96,1],.98);

function entity(n,p,s,pos,m,parent=app.root){const e=new pc.Entity(n);e.addComponent("render",{type:p});e.setLocalScale(s[0],s[1],s[2]);e.setLocalPosition(pos[0],pos[1],pos[2]);e.render.material=m;parent.addChild(e);return e}
const box=(n,s,p,m,q)=>entity(n,"box",s,p,m,q),sphere=(n,s,p,m,q)=>entity(n,"sphere",s,p,m,q),cyl=(n,s,p,m,q)=>entity(n,"cylinder",s,p,m,q),cone=(n,s,p,m,q)=>entity(n,"cone",s,p,m,q),capsule=(n,s,p,m,q)=>entity(n,"capsule",s,p,m,q);

const paths=[
{name:"Meadow Run",color:green,width:5.2,pts:[[-43,37],[-40,31],[-36,25],[-31,18],[-27,12],[-22,6],[-17,0],[-11,-7],[-4,-14],[4,-22],[12,-27]]},
{name:"Ridge Runner",color:red,width:4.9,pts:[[30,34],[27,28],[24,23],[21,17],[17,11],[14,5],[11,-2],[9,-10],[9,-18],[13,-26]]},
{name:"Glacier Way",color:blue,width:5.2,pts:[[-2,41],[0,35],[3,29],[6,23],[9,17],[13,11],[17,5],[20,-2],[23,-9],[25,-17],[25,-23]]},
{name:"Black Couloir",color:black,width:4,pts:[[44,31],[40,25],[36,20],[33,14],[30,8],[28,2],[26,-5],[24,-12],[22,-18]]},
{name:"Village Link",color:blue,width:4.2,pts:[[-34,-3],[-28,-7],[-22,-11],[-16,-15],[-10,-19],[-3,-22],[4,-25],[12,-26],[19,-25]]}];

function rawHeight(x,z){const main=34*Math.exp(-((x+31)**2/3100+(z-1)**2/3900)),west=21*Math.exp(-((x-20)**2/1900+(z+3)**2/2500)),summit=29*Math.exp(-((x-4)**2/1200+(z-38)**2/760)),north=15*Math.exp(-((x+57)**2/1700+(z-26)**2/1900)),shoulder=12*Math.exp(-((x+61)**2/1900+(z+12)**2/2800)),valley=-12*Math.exp(-((x+1)**2/500+(z+20)**2/1800)),ridge=4*Math.sin(x*.09+z*.045)+2.2*Math.cos(z*.14-x*.05);return Math.max(.5,3+main+west+summit+north+shoulder+valley+ridge)}
function segmentDistance(x,z,a,b){const vx=b[0]-a[0],vz=b[1]-a[1],wx=x-a[0],wz=z-a[1],c=Math.max(0,Math.min(1,(wx*vx+wz*vz)/(vx*vx+vz*vz||1))),dx=x-(a[0]+c*vx),dz=z-(a[1]+c*vz);return Math.hypot(dx,dz)}
function pisteCut(x,z){let cut=0;paths.forEach(p=>{for(let i=0;i<p.pts.length-1;i++){const d=segmentDistance(x,z,p.pts[i],p.pts[i+1]);if(d<p.width*1.15)cut=Math.max(cut,(1-d/(p.width*1.15))*1.65)}});return cut}
function height(x,z){return Math.max(.5,rawHeight(x,z)-pisteCut(x,z))}

function meshEntity(name,positions,indices,material,normals,colors){const mesh=new pc.Mesh(app.graphicsDevice);mesh.setPositions(positions);if(normals)mesh.setNormals(normals);if(colors)mesh.setColors(colors,4);mesh.setIndices(indices);mesh.update(pc.PRIMITIVE_TRIANGLES);const e=new pc.Entity(name);e.addComponent("render",{type:"asset",castShadows:true,receiveShadows:true});e.render.meshInstances=[new pc.MeshInstance(mesh,material)];app.root.addChild(e);return e}

function buildTerrain(){
 const terrainMats=[snow,snowBlue,snowGrey,snowBright];
 terrainMats.forEach(m=>{m.diffuseVertexColor=true;m.update()});
 for(let cz=0;cz<5;cz++)for(let cx=0;cx<8;cx++){
  const verts=[],inds=[],normals=[],colors=[],x0=-80+cx*20,x1=x0+20,z0=-62.5+cz*25,z1=z0+25,gx=8,gz=8;
  for(let j=0;j<=gz;j++)for(let i=0;i<=gx;i++){
   const x=x0+(x1-x0)*i/gx,z=z0+(z1-z0)*j/gz,y=height(x,z);
   verts.push(x,y,z);
   const e=.22,dx=height(x+e,z)-height(x-e,z),dz=height(x,z+e)-height(x,z-e),nx=-dx,ny=2,nz=-dz,len=Math.hypot(nx,ny,nz);
   normals.push(nx/len,ny/len,nz/len);
   const localNoise=.94+.055*Math.sin(x*.37+z*.19)+.035*Math.cos(z*.51-x*.13);
   const shade=Math.max(.72,Math.min(1.06,localNoise-(Math.hypot(dx,dz)*.012)));
   colors.push(shade,Math.min(1,shade+.035),Math.min(1,shade+.07),1);
  }
  for(let j=0;j<gz;j++)for(let i=0;i<gx;i++){const q=j*(gx+1)+i;inds.push(q,q+1,q+gx+1,q+1,q+gx+2,q+gx+1)}
  const cxm=(x0+x1)/2,czm=(z0+z1)/2,slope=Math.hypot(height(cxm+.8,czm)-height(cxm-.8,czm),height(cxm,czm+.8)-height(cxm,czm-.8));
  let material=snow;
  if(slope>11)material=rock;
  else if(slope>7)material=snowBlue;
  else if(czm>30&&height(cxm,czm)>35)material=snowBright;
  else if(czm<-20)material=snowGrey;
  meshEntity("Mountain terrain chunk",verts,inds,material,normals,colors);
 }
 // Layered rock shelves and avalanche gullies make the mountain read as a shaped alpine landform instead of a flat mesh.
 const faces=[
  [-9,40,14,9,3],[-38,28,13,8,2.1],[21,30,12,8,2.5],[42,20,10,10,2],
  [-56,17,10,7,1.7],[4,33,9,7,3],[55,7,8,12,1.3],[-20,19,8,6,1.4],[32,7,7,9,1.8]
 ];
 faces.forEach((p,k)=>{
  const[cx,cz,sx,sz,drop]=p,verts=[],inds=[],n=9;
  for(let j=0;j<=n;j++)for(let i=0;i<=n;i++){
   const u=i/n*2-1,v=j/n*2-1,x=cx+u*sx,z=cz+v*sz;
   const shelf=Math.max(0,1-Math.hypot(u*.92,v)*.9);
   const y=height(x,z)-drop*(.28+.72*Math.abs(v))-shelf*.35;
   verts.push(x,y,z);
  }
  for(let j=0;j<n;j++)for(let i=0;i<n;i++){const q=j*(n+1)+i;inds.push(q,q+1,q+n+1,q+1,q+n+2,q+n+1)}
  meshEntity("Granite cliff "+k,verts,inds,k%3===0?rockDark:rockLight);
 });
 // Snow pillows/ribs across the upper mountain create visible contouring and wind-loaded faces.
 const ribs=[
  [[-55,34],[-38,38],[-20,43],[-3,47]],[[6,43],[22,39],[39,35]],[[35,28],[49,25],[63,19]],
  [[-60,23],[-45,27],[-29,31]], [[-18,34],[-2,37],[16,34]]
 ];
 ribs.forEach((rib,ri)=>{
  for(let k=0;k<rib.length-1;k++){
   const a=rib[k],b=rib[k+1],dx=b[0]-a[0],dz=b[1]-a[1],l=Math.hypot(dx,dz)||1,nx=-dz/l,nz=dx/l,w=1.1;
   const x0=a[0],z0=a[1],x1=b[0],z1=b[1],y0=height(x0,z0)+.16,y1=height(x1,z1)+.16;
   meshEntity("Wind carved snow rib",[
    x0+nx*w,y0+.12,z0+nz*w,x0-nx*w,y0,z0-nz*w,
    x1+nx*w,y1+.12,z1+nz*w,x1-nx*w,y1,z1-nz*w
   ],[0,1,2,1,3,2],ri%2?snowBright:snowBlue, [0,1,0,0,1,0,0,1,0,0,1,0]);
  }
 });
}

function distantRange(baseZ,scale,seed){const verts=[],inds=[],n=18;for(let i=0;i<=n;i++){const x=-130+i*(260/n),peak=18+10*Math.sin(i*1.7+seed)+7*Math.cos(i*.73+seed),z=baseZ+4*Math.sin(i*.8+seed);verts.push(x,peak,z,x+7,4,z+8,x-7,4,z+8)}for(let i=0;i<n;i++){const q=i*3;inds.push(q,q+1,q+3,q+3,q+1,q+4,q+2,q+5,q+3,q+2,q+3,q)}meshEntity("Distant alpine range",verts,inds,rockLight);for(let i=0;i<n;i+=3){const x=-130+i*(260/n),peak=18+10*Math.sin(i*1.7+seed)+7*Math.cos(i*.73+seed),c=new pc.Entity("Distant snow peak");c.setLocalPosition(x,peak+.15,baseZ-.5);app.root.addChild(c);cone("snow peak",[5*scale,Math.max(7,12*scale),5*scale],[0,0,0],snowBright,c)}}
distantRange(-82,1.15,.4);distantRange(-112,.95,1.9);distantRange(-142,.78,3.2);buildTerrain();

function tree(x,z,s=1,snowLoad=.45){const y=height(x,z),e=new pc.Entity("Alpine fir");e.setLocalPosition(x,y-.05,z);app.root.addChild(e);cyl("trunk",[.22*s,.9*s,.22*s],[0,.45*s,0],trunk,e);cone("lower boughs",[1.3*s,2.25*s,1.3*s],[0,1.35*s,0],pine,e);cone("middle boughs",[1.05*s,1.9*s,1.05*s],[0,2.35*s,0],pine,e);cone("top boughs",[.72*s,1.6*s,.72*s],[0,3.05*s,0],pine2,e);if(snowLoad>.65)cone("snow crown",[.48*s,.7*s,.48*s],[0,3.55*s,0],pineSnow,e)}
for(let i=0;i<78;i++){const x=-77+Math.random()*154,z=-58+Math.random()*108,y=height(x,z);if(y>5&&y<32&&Math.random()>.08)tree(x,z,.45+Math.random()*.9,.45+Math.random()*.6)}
paths.forEach(path=>{path.pts.forEach(([x,z],i)=>{const prev=path.pts[Math.max(0,i-1)],next=path.pts[Math.min(path.pts.length-1,i+1)],dx=next[0]-prev[0],dz=next[1]-prev[1],l=Math.hypot(dx,dz)||1,nx=-dz/l,nz=dx/l;for(const side of[-1,1]){const px=x+nx*(path.width*.55)*side,pz=z+nz*(path.width*.55)*side;cone(path.name+" snowbank",[.34,.65,.34],[px,height(px,pz)+.32,pz],snowBright)}})});

function ribbon(path){const verts=[],inds=[],normals=[];for(let i=0;i<path.pts.length;i++){const[x,z]=path.pts[i],prev=path.pts[Math.max(0,i-1)],next=path.pts[Math.min(path.pts.length-1,i+1)],dx=next[0]-prev[0],dz=next[1]-prev[1],l=Math.hypot(dx,dz)||1,nx=-dz/l,nz=dx/l,w=path.width/2,left=[x+nx*w,z+nz*w],right=[x-nx*w,z-nz*w];verts.push(left[0],height(left[0],left[1])+.18,left[1],right[0],height(right[0],right[1])+.18,right[1]);normals.push(0,1,0,0,1,0)}for(let i=0;i<path.pts.length-1;i++){const q=i*2;inds.push(q,q+1,q+2,q+1,q+3,q+2)}meshEntity(path.name+" groomed piste",verts,inds,path.color,normals);path.pts.forEach(([x,z],i)=>{if(i%2===0){const dx=path.pts[Math.min(path.pts.length-1,i+1)][0]-path.pts[Math.max(0,i-1)][0],dz=path.pts[Math.min(path.pts.length-1,i+1)][1]-path.pts[Math.max(0,i-1)][1],l=Math.hypot(dx,dz)||1,nx=-dz/l,nz=dx/l;for(const s of[-1,1]){const px=x+nx*(path.width*.64)*s,pz=z+nz*(path.width*.64)*s;cyl(path.name+" marker pole",[.045,1.25,.045],[px,height(px,pz)+.62,pz],yellow)}}})}
paths.forEach(ribbon);

function signAt(text,x,z,color){const y=height(x,z)+1.2,e=new pc.Entity(text);e.setLocalPosition(x,y,z);app.root.addChild(e);cyl("sign post",[.06,1.3,.06],[0,-.65,0],steel,e);box("sign board",[1.55,.62,.1],[0,.05,0],color,e)}
signAt("MEADOW",-18,1,green);signAt("RIDGE",12,1,red);signAt("GLACIER",18,4,blue);signAt("COULOIR",29,4,black);

function chalet(n,x,z,s=1){const y=height(x,z),e=new pc.Entity(n);e.setLocalPosition(x,y,z);e.setLocalScale(s,s,s);app.root.addChild(e);box("chalet walls",[8,3.9,6],[0,2,0],timber,e);const r1=box("pitched roof",[4.9,.55,7.2],[-2.05,4.35,0],roof,e);r1.setLocalEulerAngles(0,0,-29);const r2=box("pitched roof",[4.9,.55,7.2],[2.05,4.35,0],roof,e);r2.setLocalEulerAngles(0,0,29);const rs1=box("roof snow",[4.7,.18,7],[-2,4.72,0],roofSnow,e);rs1.setLocalEulerAngles(0,0,-29);const rs2=box("roof snow",[4.7,.18,7],[2,4.72,0],roofSnow,e);rs2.setLocalEulerAngles(0,0,29);for(const sx of[-2.7,0,2.7]){box("window",[1.45,1.1,.12],[sx,2.35,3.04],glass,e);box("window glow",[1.15,.12,.13],[sx,2.35,3.11],warm,e)}box("door",[1.15,2.1,.16],[0,1.05,3.08],roof,e);box("balcony",[3.4,.16,1],[0,2.75,3.48],trunk,e);for(const sx of[-1.45,1.45])cyl("balcony rail",[.08,1,.08],[sx,3.25,3.48],steel,e);cyl("chimney",[.55,1.25,.55],[2.3,5,1],roof,e)}
chalet("Summit Lodge",-5,-24,1.35);chalet("Piste House",18,-16,.9);chalet("Mountain Hotel",-27,-14,1.25);

function station(n,x,z,type="chair"){const y=height(x,z),e=new pc.Entity(n);e.setLocalPosition(x,y,z);app.root.addChild(e);box("station body",[6,2.8,4.5],[0,1.4,0],steel,e);const r1=box("station roof",[3.6,.5,5.6],[-1.5,3.05,0],roof,e);r1.setLocalEulerAngles(0,0,-22);const r2=box("station roof",[3.6,.5,5.6],[1.5,3.05,0],roof,e);r2.setLocalEulerAngles(0,0,22);box("station glass",[4.4,1.25,.12],[0,1.55,2.28],glass,e);box("station platform",[7,.25,1.3],[0,.25,0],snowBright,e);if(type==="gondola")box("gondola sign",[2.3,.55,.12],[0,2.35,2.4],gondola,e)}
function makeLift(n,a,b,count,type="chair"){const root=new pc.Entity(n);app.root.addChild(root);const[ax,az]=a,[bx,bz]=b,dx=bx-ax,dz=bz-az,len=Math.hypot(dx,dz)||1,ay=height(ax,az)+3.1,by=height(bx,bz)+3.1,ang=Math.atan2(dx,dz)*180/Math.PI;station(n+" base",ax,az,type);station(n+" summit",bx,bz,type);for(let i=1;i<9;i++){const t=i/9,x=ax+dx*t,z=az+dz*t,y=height(x,z)+2.7,tower=new pc.Entity(n+" tower");tower.setLocalPosition(x,y,z);root.addChild(tower);cyl("tower leg",[.24,5,.24],[0,-2.5,0],steel,tower);box("crossarm",[3.2,.2,.35],[0,0,0],steel,tower);for(const sx of[-1,1])sphere("sheave",[.28,.28,.28],[sx*1.35,-.18,0],cable,tower)}const rope=box("haul cable",[.065,.065,len],[(ax+bx)/2,(ay+by)/2,(az+bz)/2],cable,root);rope.setLocalEulerAngles(0,ang,Math.atan2(by-ay,len)*180/Math.PI);const carriers=[];for(let i=0;i<count;i++){const e=new pc.Entity(n+" carrier "+i);root.addChild(e);e._phase=i/count;e._a=[ax,ay,az];e._b=[bx,by,bz];if(type==="gondola"){box("cabin",[1.25,1.05,.9],[0,-.2,0],gondola,e);box("cabin glass",[1,.65,.08],[0,-.15,.47],glass,e);box("hanger",[.07,1.35,.07],[0,.82,0],steel,e)}else{box("seat",[1.3,.16,.48],[0,-.58,0],chair,e);box("back",[1.3,.7,.11],[0,-.18,0],chair,e);box("hanger",[.07,1.5,.07],[0,.6,0],steel,e)}carriers.push(e)}return carriers}
const lift1=makeLift("Eagle Express",[-5,-22],[-39,33],12,"chair"),lift2=makeLift("Glacier Chair",[18,-15],[0,40],11,"chair"),lift3=makeLift("Ridge Gondola",[29,-8],[45,30],9,"gondola");

const guests=[];function samplePath(path,t){const f=t*(path.pts.length-1),i=Math.min(path.pts.length-2,Math.floor(f)),q=f-i;return[path.pts[i][0]+(path.pts[i+1][0]-path.pts[i][0])*q,path.pts[i][1]+(path.pts[i+1][1]-path.pts[i][1])*q]}
function makeSkier(i,route,t,type){
 const p=samplePath(paths[route],t),y=height(p[0],p[1])+.04,e=new pc.Entity((type==="snowboarder"?"Snowboarder ":"Skier ")+i);
 e.setLocalPosition(p[0],y,p[1]);e.setLocalScale(1.18,1.18,1.18);app.root.addChild(e);
 const jm=[jacket,jacket2,jacket3,jacket4][i%4], visor=i%3===0?goggle:cable;
 // A crouched silhouette: helmet, goggles, hood, padded jacket, backpack, bent arms, gloves, legs and boots.
 capsule("body", [.42,.62,.32],[0,1.02,0], jm,e);
 sphere("head",[.38,.38,.38],[0,1.53,.01],skin,e);
 sphere("helmet",[.43,.24,.43],[0,1.72,.01],i%2?cable:yellow,e);
 box("goggles",[.29,.095,.055],[0,1.57,.20],visor,e);
 box("jacket collar",[.34,.18,.34],[0,1.36,.02],jm,e);
 box("backpack",[.28,.42,.16],[0,1.10,-.19],pack,e);
 // Arms are angled forward like a real skier rather than hanging straight down.
 const a1=capsule("arm",[.12,.42,.12],[-.33,1.18,.08],jm,e);a1.setLocalEulerAngles(0,0,-30);
 const a2=capsule("arm",[.12,.42,.12],[.33,1.18,.08],jm,e);a2.setLocalEulerAngles(0,0,30);
 const pole1=cyl("pole",[.028,.82,.028],[-.38,.68,.20],steel,e);pole1.setLocalEulerAngles(12,0,-18);
 const pole2=cyl("pole",[.028,.82,.028],[.38,.68,.20],steel,e);pole2.setLocalEulerAngles(12,0,18);
 sphere("glove",[.14,.14,.14],[-.48,1.36,.18],glove,e);sphere("glove",[.14,.14,.14],[.48,1.36,.18],glove,e);
 const l1=capsule("leg",[.14,.48,.14],[-.14,.52,.03],pants,e);l1.setLocalEulerAngles(0,0,-9);
 const l2=capsule("leg",[.14,.48,.14],[.14,.52,.03],pants,e);l2.setLocalEulerAngles(0,0,9);
 box("boot", [.20,.20,.36],[-.14,.26,.12],boot,e);box("boot", [.20,.20,.36],[.14,.26,.12],boot,e);
 if(type==="snowboarder"){
   box("snowboard",[1.12,.075,.20],[0,.12,.02],board,e);
   sphere("binding",[.13,.09,.16],[-.25,.17,.02],steel,e);sphere("binding",[.13,.09,.16],[.25,.17,.02],steel,e);
 }else{
   box("ski",[.055,.045,1.45],[-.18,.13,.12],snowBright,e);box("ski",[.055,.045,1.45],[.18,.13,.12],snowBright,e);
 }
 e._route=route;e._path=t;e._speed=.022+Math.random()*.04;e._phase=Math.random()*6;e._type=type;e._anim={body:e.children[0],head:e.children[1],helmet:e.children[2],goggles:e.children[3],collar:e.children[4],pack:e.children[5],armL:a1,armR:a2,gloveL:e.children[8],gloveR:e.children[9],legL:l1,legR:l2,poleL:pole1,poleR:pole2};guests.push(e)
}
for(let i=0;i<44;i++)makeSkier(i,i%paths.length,(i*.173+Math.random()*.22)%1,i%7===0?"snowboarder":"skier");
function chooseRoute(g){const choices=[0,1,2,3,4].filter(x=>x!==g._route);g._route=choices[Math.floor(Math.random()*choices.length)];g._path=Math.random()*.12;g._speed=.022+Math.random()*.04}
let cash=250000,paused=false,weather=0;
app.on("update",dt=>{if(paused)return;const now=performance.now()/1000;guests.forEach(g=>{g._path+=dt*g._speed;if(g._path>=1)chooseRoute(g);const p=samplePath(paths[g._route],g._path),p2=samplePath(paths[g._route],Math.min(.999,g._path+.012)),turn=Math.atan2(p2[0]-p[0],p2[1]-p[1])*180/Math.PI;const phase=now*(5.2+g._speed*22)+g._phase, carve=Math.sin(phase), sway=Math.sin(phase*.5);g.setLocalPosition(p[0],height(p[0],p[1])+.04,p[1]);g.setLocalEulerAngles(0,turn,Math.sin(phase*.7)*3.5);if(g._anim){const a=g._anim;const tuck=20+Math.abs(carve)*7;a.body.setLocalEulerAngles(tuck*.32,0,-12+carve*5);a.head.setLocalEulerAngles(tuck*.16,0,-carve*3);a.helmet.setLocalEulerAngles(tuck*.16,0,-carve*3);a.armL.setLocalEulerAngles(0,0,-30+carve*10);a.armR.setLocalEulerAngles(0,0,30+carve*10);a.legL.setLocalEulerAngles(0,0,-9-carve*7);a.legR.setLocalEulerAngles(0,0,9+carve*7);a.poleL.setLocalEulerAngles(12+carve*8,0,-18-carve*6);a.poleR.setLocalEulerAngles(12-carve*8,0,18-carve*6);a.pack.setLocalPosition(0,1.10,-.19+Math.abs(carve)*.015)}});[...lift1,...lift2,...lift3].forEach(c=>{const cycle=(c._phase+now*.055)%2,t=cycle<=1?cycle:2-cycle;c.setPosition(pc.math.lerp(c._a[0],c._b[0],t),pc.math.lerp(c._a[1],c._b[1],t),pc.math.lerp(c._a[2],c._b[2],t))});document.getElementById("guests").textContent=String(90+Math.floor((now*2)%120));document.getElementById("cash").textContent=Math.floor(cash).toLocaleString()});

let tool="select";document.querySelectorAll(".tool").forEach(b=>b.addEventListener("click",()=>{document.querySelectorAll(".tool").forEach(x=>x.classList.remove("active"));b.classList.add("active");tool=b.dataset.tool;toast(tool==="select"?"Select and inspect your resort":"Build mode: "+b.textContent.trim())}));
function toast(t){const e=document.getElementById("toast");e.textContent=t;e.classList.add("show");clearTimeout(window.__toast);window.__toast=setTimeout(()=>e.classList.remove("show"),1600)}
document.getElementById("pauseBtn").onclick=()=>{paused=!paused;document.getElementById("pauseBtn").textContent=paused?"▶":"Ⅱ";toast(paused?"Game paused":"Game resumed")};
document.getElementById("weatherBtn").onclick=()=>{weather=(weather+1)%3;const n=["Clear","Snowfall","Storm"];document.getElementById("weather").textContent=n[weather];toast(n[weather]+" conditions")};
document.getElementById("resetBtn").onclick=()=>{cash=250000;toast("New season started")};

const camera=new pc.Entity("Camera");camera.addComponent("camera",{clearColor:new pc.Color(.63,.77,.88),fov:46});app.root.addChild(camera);
let yaw=-31,pitch=32,distance=112,target=new pc.Vec3(0,19,4);
function updateCamera(){const yr=yaw*Math.PI/180,pr=pitch*Math.PI/180;camera.setPosition(target.x+Math.sin(yr)*Math.cos(pr)*distance,target.y+Math.sin(pr)*distance,target.z+Math.cos(yr)*Math.cos(pr)*distance);camera.lookAt(target)}
updateCamera();
const pointers=new Map();let lastDist=0;
canvas.addEventListener("pointerdown",e=>{canvas.setPointerCapture(e.pointerId);pointers.set(e.pointerId,[e.clientX,e.clientY])});
canvas.addEventListener("pointermove",e=>{if(!pointers.has(e.pointerId))return;const old=pointers.get(e.pointerId);pointers.set(e.pointerId,[e.clientX,e.clientY]);if(pointers.size===1){yaw-=(e.clientX-old[0])*.22;pitch=Math.max(14,Math.min(72,pitch+(e.clientY-old[1])*.18));updateCamera()}else if(pointers.size===2){const a=[...pointers.values()],d=Math.hypot(a[0][0]-a[1][0],a[0][1]-a[1][1]);if(lastDist)distance=Math.max(48,Math.min(160,distance-(d-lastDist)*.35));lastDist=d;updateCamera()}});
canvas.addEventListener("pointerup",e=>{pointers.delete(e.pointerId);lastDist=0});
canvas.addEventListener("wheel",e=>{distance=Math.max(48,Math.min(160,distance+e.deltaY*.06));updateCamera()},{passive:true});
window.addEventListener("resize",()=>app.resizeCanvas(canvas.clientWidth,canvas.clientHeight));
setTimeout(()=>{document.getElementById("loading").style.opacity="0";setTimeout(()=>document.getElementById("loading").remove(),600);toast("Summit Valley — Alpine terrain rebuilt")},1400);
