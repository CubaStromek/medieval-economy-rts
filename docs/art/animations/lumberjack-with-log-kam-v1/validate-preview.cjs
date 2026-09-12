const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const html=fs.readFileSync(process.argv[2],'utf8');
const script=html.match(/<script>([\s\S]*?)<\/script>/)[1];
const data=html.match(/<script type="application\/json" data-images>([\s\S]*?)<\/script>/)[1];
const parsed=JSON.parse(data),directions=['N','NE','E','SE','S','SW','W','NW'];
assert.deepEqual(Object.keys(parsed),directions);assert(Buffer.byteLength(html)<1_000_000);
const nodes=new Map(),draws={original:[],own:[]};
function el(key){const e={value:'0',disabled:true,hidden:true,textContent:'',attrs:{},events:{},setAttribute(k,v){this.attrs[k]=v;},addEventListener(k,f){this.events[k]=f;},emit(k){this.events[k]();}};nodes.set(key,e);return e;}
for(const kind of ['original','own'])el('[data-'+kind+']').getContext=()=>({clearRect(){},drawImage:(...a)=>draws[kind].push(a)});
for(const name of ['[data-direction]','[data-tempo]','[data-frame]','[data-phase]','[data-action="play"]','[data-action="back"]','[data-action="next"]','[data-error]'])el(name);
el('[data-images]').textContent=data;nodes.get('[data-direction]').value='SE';nodes.get('[data-tempo]').value='2';
const root={querySelector(k){assert(nodes.has(k),k);return nodes.get(k);}};
const document={hidden:false,events:{},getElementById(id){assert.equal(id,'lj-carry-eight-directions');return root;},addEventListener(k,f){this.events[k]=f;}};
class ImageStub{constructor(){this.complete=false;this.naturalWidth=0;this.naturalHeight=0;}set src(v){this.url=v;this.complete=true;this.naturalWidth=v.startsWith('data:image/png')?1792:1120;this.naturalHeight=v.startsWith('data:image/png')?1088:680;this.onload();}}
let id=0;const timers=new Map();
vm.runInNewContext(script,{document,Image:ImageStub,setInterval(fn,delay){timers.set(++id,{fn,delay});return id;},clearInterval(k){timers.delete(k);}});
const e=k=>nodes.get(k),last=k=>draws[k].at(-1);
assert.equal(timers.size,0);assert.equal(e('[data-action="play"]').disabled,false);
assert.equal(e('[data-frame]').value,'5');assert.equal(e('[data-phase]').textContent,'Fáze 6 / 8');
assert.equal(last('own')[0].url,parsed.SE.own);
assert.match(html,/<option value="2" selected>/);assert.match(html,/data-frame[^>]*value="5"/);
for(const direction of directions){
 e('[data-direction]').value=direction;e('[data-direction]').emit('change');
 for(let i=0;i<8;i++){
  e('[data-frame]').value=String(i);e('[data-frame]').emit('input');
  for(const kind of ['original','own']){
   const a=last(kind),w=kind==='original'?448:280,h=kind==='original'?544:340;
   assert.equal(a[0].url,parsed[direction][kind]);
   assert.deepEqual(a.slice(1),[(i%4)*w,Math.floor(i/4)*h,w,h,0,0,448,544]);
  }
  assert.equal(e('[data-phase]').textContent,'Fáze '+(i+1)+' / 8');
 }
}
e('[data-action="next"]').emit('click');assert.equal(e('[data-frame]').value,'0');
e('[data-action="back"]').emit('click');assert.equal(e('[data-frame]').value,'7');
e('[data-action="play"]').emit('click');assert.equal(timers.size,1);assert.equal([...timers.values()][0].delay,500);
[...timers.values()][0].fn();assert.equal(e('[data-frame]').value,'0');
e('[data-tempo]').value='5';e('[data-tempo]').emit('change');assert.equal([...timers.values()][0].delay,200);
e('[data-tempo]').value='10';e('[data-tempo]').emit('change');assert.equal([...timers.values()][0].delay,100);
e('[data-direction]').value='SE';e('[data-direction]').emit('change');assert.equal(timers.size,0);
e('[data-action="play"]').emit('click');document.hidden=true;document.events.visibilitychange();assert.equal(timers.size,0);
console.log(JSON.stringify({method:'Node vm, explicit DOM/Image/timer test doubles; no browser',directionCount:8,phasePairsVerified:64,correctAtlases:true,synchronizedRects:true,wraparound:true,temposVerified:[2,5,10],initialDirection:'SE',initialFrameIndex:5,pauseOnDirectionChange:true,pauseWhenHidden:true}));
