const {test}=require('node:test'),assert=require('node:assert/strict');
const vm=require('node:vm'),fs=require('node:fs'),path=require('node:path');
test('Modifier heartbeats retain desktop geometry without reprocessing or reconfiguring windows',()=>{
 const source=fs.readFileSync(path.join(__dirname,'../app/main.cjs'),'utf8');
 let line,conversions=0,applies=0;
 const context={process:{platform:'win32',pid:1,env:{}},path,__dirname,fs:{readFileSync:()=>''},
 spawn:()=>({on(){},stderr:{on(){}},stdout:{}}),createInterface:()=>({on(_event,fn){line=fn;}}),
 screen:{screenToDipRect(_window,rect){conversions++;return rect;}},applyWindows(){applies++;},broadcast(){},Date};
 vm.createContext(context);
 vm.runInContext('let helper,quitting=false,cloudModifier=false,modifierAt=0,windows=[],foreground=null,windowStatus="Края окон доступны.";'+source.slice(source.indexOf('function startHelper()'),source.indexOf('function authorized('))+';startHelper()',context);
 line(JSON.stringify({ctrl:false,windows:[{id:'one',x:0,y:0,width:100,height:100}],foreground:'one'}));
 line('{"ctrl":true}');
 for(let i=0;i<100;i++)line('{"ctrl":true}');
 assert.equal(conversions,1);assert.equal(applies,2);
 assert.equal(vm.runInContext('windows.length',context),1);assert.equal(vm.runInContext('foreground',context),'one');
 line('{"ctrl":false}');assert.equal(applies,3);assert.equal(vm.runInContext('cloudModifier',context),false);
 vm.runInContext('quitting=true',context);line('{"ctrl":true,"windows":[]}');assert.equal(applies,3);assert.equal(conversions,1);
});
